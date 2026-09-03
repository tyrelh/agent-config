{
  const app = window.DevPrefs

  /**
   * escapeHtml converts user-controlled text into safe HTML text.
   */
  app.escapeHtml = (value) =>
    String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")

  /**
   * renderMarkdown renders the small markdown subset used in rule text.
   */
  app.renderMarkdown = (value) =>
    app.escapeHtml(value)
      .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
      .replace(/`([^`]+?)`/g, "<code>$1</code>")

  /**
   * localHrefFor returns a safe relative href for dashboard-local files.
   */
  app.localHrefFor = (value) => {
    const raw = String(value || "").trim()
    if (!raw) return ""

    let decoded = raw
    try {
      decoded = decodeURIComponent(raw)
    } catch {
      return ""
    }

    const path = decoded.split(/[?#]/)[0]
    const pathParts = path.split(/[\\/]+/)
    if (
      !path ||
      path.startsWith("/") ||
      path.startsWith("\\") ||
      path.includes("://") ||
      /^[a-z][a-z0-9+.-]*:/i.test(path) ||
      pathParts.includes("..")
    ) {
      return ""
    }
    return path
  }

  /**
   * formatDate renders ISO timestamps in the user's local browser locale.
   */
  app.formatDate = (iso) => {
    if (!iso) return "Never"

    const date = new Date(iso)
    return Number.isNaN(date.getTime()) ? String(iso) : date.toLocaleString()
  }

  /**
   * formatInteger renders integer metrics with locale separators.
   */
  app.formatInteger = (value) => new Intl.NumberFormat().format(Number(value) || 0)

  /**
   * activeRangeConfig returns the Range control config for the current selection.
   */
  app.activeRangeConfig = () =>
    app.analyticsRanges[app.state.analyticsRange] || app.analyticsRanges.all

  /**
   * activeBucketHours returns the plot-point interval in hours for the active range.
   */
  app.activeBucketHours = () => Number(app.activeRangeConfig().bucketHours) || 24

  /**
   * alignBucketStart floors a Date to the start of its active-range bucket in local time.
   */
  app.alignBucketStart = (value) => {
    const date = new Date(value)
    if (Number.isNaN(date.getTime())) return null

    const bucketHours = app.activeBucketHours()
    date.setMinutes(0, 0, 0)

    if (bucketHours >= 24) {
      const dayBucket = Math.max(1, Math.round(bucketHours / 24))
      const localMidnight = new Date(date.getFullYear(), date.getMonth(), date.getDate())
      if (dayBucket === 1) return localMidnight

      const epoch = new Date(1970, 0, 1)
      const dayIndex = Math.round((localMidnight - epoch) / 86400000)
      const aligned = new Date(1970, 0, 1)
      aligned.setDate(1 + dayIndex - (dayIndex % dayBucket))
      return aligned
    }

    const bucketHour = date.getHours() - (date.getHours() % bucketHours)
    date.setHours(bucketHour, 0, 0, 0)
    return date
  }

  /**
   * advanceBucketStart returns the next bucket start after date.
   */
  app.advanceBucketStart = (value) => {
    const date = new Date(value)
    const bucketHours = app.activeBucketHours()
    if (bucketHours >= 24) {
      date.setDate(date.getDate() + Math.max(1, Math.round(bucketHours / 24)))
      date.setHours(0, 0, 0, 0)
      return date
    }

    const nextHour = date.getHours() + bucketHours
    if (nextHour >= 24) {
      date.setDate(date.getDate() + 1)
      date.setHours(nextHour - 24, 0, 0, 0)
    } else {
      date.setHours(nextHour, 0, 0, 0)
    }
    return date
  }

  /**
   * parseBucketKey parses a local bucket key into a Date without UTC shifting.
   */
  app.parseBucketKey = (key) => {
    const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(String(key || ""))
    if (!match) {
      const fallback = new Date(key)
      return Number.isNaN(fallback.getTime()) ? null : fallback
    }

    return new Date(
      Number(match[1]),
      Number(match[2]) - 1,
      Number(match[3]),
      Number(match[4]),
      Number(match[5]),
    )
  }

  /**
   * bucketKeyFromDate formats a local Date as a bucket key.
   */
  app.bucketKeyFromDate = (date) => {
    if (!date || Number.isNaN(date.getTime())) return null

    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, "0")
    const day = String(date.getDate()).padStart(2, "0")
    const hour = String(date.getHours()).padStart(2, "0")
    return `${year}-${month}-${day}T${hour}:00`
  }

  /**
   * hourKey returns a local bucket key for an ISO timestamp using the active range interval.
   */
  app.hourKey = (iso) => {
    if (!iso) return null
    return app.bucketKeyFromDate(app.alignBucketStart(iso))
  }

  /**
   * formatHourKey renders a bucket key for compact chart labels.
   */
  app.formatHourKey = (key) => {
    const date = app.parseBucketKey(key)
    if (!date) return String(key)

    if (app.activeBucketHours() >= 24) {
      return date.toLocaleDateString(undefined, { day: "numeric", month: "short" })
    }

    return date.toLocaleString(undefined, { day: "numeric", hour: "numeric", month: "short" })
  }

  /**
   * bucketLabel describes the active plot-point interval for chart notes.
   */
  app.bucketLabel = () => {
    const hours = app.activeBucketHours()
    if (hours >= 24) {
      const days = Math.round(hours / 24)
      return days === 1 ? "1-day" : `${days}-day`
    }
    return hours === 1 ? "1-hour" : `${hours}-hour`
  }

  /**
   * bucketRangeFor returns every local bucket row in the active range window.
   * Fixed ranges use now-anchored windows; All uses the span of the supplied events.
   */
  app.bucketRangeFor = (events) => {
    const config = app.activeRangeConfig()
    let first
    let last = app.alignBucketStart(new Date())

    if (config.windowMs != null) {
      first = app.alignBucketStart(Date.now() - config.windowMs)
    } else {
      const timestamps = events
        .map((event) => new Date(event.usedAt).getTime())
        .filter((timestamp) => !Number.isNaN(timestamp))
      if (!timestamps.length) return []
      first = app.alignBucketStart(Math.min(...timestamps))
      last = app.alignBucketStart(Math.max(...timestamps))
    }

    if (!first || !last || first > last) return []

    const rows = []
    for (let cursor = new Date(first); cursor <= last; cursor = app.advanceBucketStart(cursor)) {
      const key = app.bucketKeyFromDate(cursor)
      rows.push({
        date: new Date(cursor),
        label: app.formatHourKey(key),
        sortKey: key,
      })
    }
    return rows
  }

  /**
   * agentNameFor returns the recorded agent name for an event.
   */
  app.agentNameFor = (event) => {
    const agent = event.agent || {}
    return agent.agent || "UNKNOWN"
  }

  /**
   * modelNameFor returns the recorded model name for an event.
   */
  app.modelNameFor = (event) => {
    const agent = event.agent || {}
    return agent.model || "UNKNOWN"
  }

  /**
   * projectNameFor returns the recorded repository or project label for an event.
   */
  app.projectNameFor = (event) => event.project || "UNKNOWN"

  /**
   * projectLabelStyleFor returns a stable, distinct hue for any project label.
   */
  app.projectLabelStyleFor = (project) => {
    if (!project || project === "UNKNOWN") return ""
    const hash = [...project].reduce(
      (value, character) => ((value * 31) + character.codePointAt(0)) >>> 0,
      0,
    )
    const hue = Math.round((hash * 137.508) % 360)
    return `--project-hue:${hue}`
  }

  /**
   * agentModelLabelFor returns display text for the agent/model pair on an event.
   */
  app.agentModelLabelFor = (event) => {
    const agentName = app.agentNameFor(event)
    const model = app.modelNameFor(event)

    if (agentName && model) return `${agentName} / ${model}`
    return agentName && model ? `${agentName} / ${model}` : "UNKNOWN"
  }

  /**
   * plainRuleText returns rule text with markdown formatting stripped.
   */
  app.plainRuleText = (ruleText) =>
    String(ruleText)
      .replace(/\*\*(.+?)\*\*/g, "$1")
      .replace(/`([^`]+?)`/g, "$1")
}
