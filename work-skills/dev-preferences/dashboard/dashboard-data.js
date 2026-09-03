{
  const app = window.DevPrefs

  /**
   * usageCountFor returns the recorded use count for a rule.
   */
  app.usageCountFor = (ruleText) => {
    const ruleId = app.data.ruleIds && app.data.ruleIds[ruleText]
    return (ruleId && app.data.usageByRuleID && app.data.usageByRuleID[ruleId]) || 0
  }

  /**
   * ruleHistoryFor returns timestamped usage details for a rule.
   */
  app.ruleHistoryFor = (ruleText) => {
    const ruleId = app.data.ruleIds && app.data.ruleIds[ruleText]
    if (ruleId && app.data.usageHistoryByRuleID && app.data.usageHistoryByRuleID[ruleId]) {
      return app.data.usageHistoryByRuleID[ruleId]
    }
    return []
  }

  /**
   * ruleTextForId returns the active rule text for a stable rule ID.
   */
  app.ruleTextForId = (ruleId) => {
    for (const section of app.data.sections) {
      const ruleText = section.rules.find((text) => app.data.ruleIds[text] === ruleId)
      if (ruleText) return ruleText
    }
    return null
  }

  /**
   * historyContextFor returns the rule text, usage history, and total for a rule ID.
   *
   * Removed rules carry their own archived history, kept separate from the active
   * counters so a merge does not erase what the retired rule earned.
   */
  app.historyContextFor = (ruleId) => {
    const ruleText = app.ruleTextForId(ruleId)
    if (ruleText) {
      return {
        ruleText,
        history: app.ruleHistoryFor(ruleText),
        total: app.usageCountFor(ruleText),
      }
    }

    const removed = (app.data.removed || []).find((entry) => entry.ruleID === ruleId)
    if (!removed) return null

    return {
      ruleText: removed.text || "",
      history: removed.history || [],
      total: removed.usageCount || 0,
    }
  }

  /**
   * ruleMetadataFor returns stored metadata for a rule.
   */
  app.ruleMetadataFor = (ruleText) => {
    const ruleId = app.data.ruleIds && app.data.ruleIds[ruleText]
    return (ruleId && app.data.ruleMetadata && app.data.ruleMetadata[ruleId]) || {}
  }

  /**
   * addedAtFor returns the recorded added-at timestamp for a rule.
   */
  app.addedAtFor = (ruleText) => app.ruleMetadataFor(ruleText).addedAt || null

  /**
   * timestampValue returns a sortable epoch ms value, or 0 when missing/invalid.
   */
  app.timestampValue = (iso) => {
    const timestamp = new Date(iso).getTime()
    return Number.isNaN(timestamp) ? 0 : timestamp
  }

  /**
   * lastUsedAtFor returns the newest timestamp for a rule usage history.
   */
  app.lastUsedAtFor = (ruleText) => {
    const timestamps = app.ruleHistoryFor(ruleText)
      .map((event) => new Date(event.usedAt).getTime())
      .filter((timestamp) => !Number.isNaN(timestamp))

    return timestamps.length ? new Date(Math.max(...timestamps)).toISOString() : null
  }

  /**
   * addedDateNoteFor returns a compact note for backfilled added dates.
   */
  app.addedDateNoteFor = (source) => {
    if (source === "firstUsage") return "from first use"
    if (source === "firstSeen") return "first tracked"
    return ""
  }

  /**
   * ruleUsageEvents returns timestamped rule usage events from the current data.
   */
  app.ruleUsageEvents = () => {
    const removedTextById = new Map(
      (app.data.removed || []).map((entry) => [entry.ruleID, entry.text || "Removed rule"]),
    )

    return Object.entries(app.data.usageHistoryByRuleID || {}).flatMap(([storedRuleId, history]) => {
      return history.map((event) => {
        const recordedRuleId = /^r-[0-9a-f]{8}$/.test(event.query || "")
          ? event.query
          : storedRuleId
        const ruleText =
          app.ruleTextForId(recordedRuleId) ||
          removedTextById.get(recordedRuleId) ||
          app.ruleTextForId(storedRuleId) ||
          "Legacy rule"
        return { ...event, kind: "rule", ruleId: recordedRuleId, ruleText }
      })
    })
  }

  /**
   * trackingEvents returns one event per skill usage tracking record.
   */
  app.trackingEvents = () => app.data.skillUsage || []

  /**
   * metadataOptions returns metadata filter options present in usage data.
   */
  app.metadataOptions = (allLabel, valueFor) => {
    const labels = new Set()

    app.trackingEvents().forEach((event) => {
      const label = valueFor(event)
      if (label) labels.add(label)
    })

    return [
      { value: "all", label: allLabel },
      ...Array.from(labels)
        .sort()
        .map((label) => ({ value: label, label })),
    ]
  }

  /**
   * analyticsEventMatches returns whether an event is in the selected analytics filters.
   */
  app.analyticsEventMatches = (event) => {
    const windowMs = app.activeRangeConfig().windowMs
    const timestamp = new Date(event.usedAt).getTime()
    if (windowMs != null && !Number.isNaN(timestamp) && timestamp < Date.now() - windowMs) {
      return false
    }

    if (app.state.analyticsAgent !== "all" && app.agentNameFor(event) !== app.state.analyticsAgent) {
      return false
    }

    if (app.state.analyticsModel !== "all" && app.modelNameFor(event) !== app.state.analyticsModel) {
      return false
    }

    if (
      app.state.analyticsProject !== "all" &&
      app.projectNameFor(event) !== app.state.analyticsProject
    ) {
      return false
    }

    if (
      app.state.analyticsAgentModel !== "all" &&
      app.agentModelLabelFor(event) !== app.state.analyticsAgentModel
    ) {
      return false
    }

    return true
  }

  /**
   * filteredTrackingEvents returns tracked usage events in the active filters.
   */
  app.filteredTrackingEvents = () => app.trackingEvents().filter(app.analyticsEventMatches)

  /**
   * filteredRuleApplicationEvents returns per-rule application events in active filters.
   */
  app.filteredRuleApplicationEvents = () => app.ruleUsageEvents().filter(app.analyticsEventMatches)

  /**
   * usageSummarySeriesByHour compares the same totals shown in the header:
   * skill-use tracking records and per-rule usage events.
   */
  app.usageSummarySeriesByHour = () =>
    app.aggregateSeriesByHour(
      [
        ...app.filteredTrackingEvents().map((event) => ({
          ...event,
          usageSeries: "Skill Usage (Skill uses)",
        })),
        ...app.filteredRuleApplicationEvents().map((event) => ({
          ...event,
          usageSeries: "Rule Usage (Usage events)",
        })),
      ],
      (event) => event.usageSeries,
    )

  /**
   * aggregateSeriesByHour buckets events by the active Range interval.
   *
   * Every bucket in the selected window is included so point spacing stays even.
   * Events without a label are skipped; series with no activity are dropped.
   */
  app.aggregateSeriesByHour = (events, labelFor) => {
    const labels = new Set()
    const hours = new Map()

    events.forEach((event) => {
      const key = app.hourKey(event.usedAt)
      const label = labelFor(event)
      if (!key || !label) return

      labels.add(label)
      const totals = hours.get(key) || {}
      totals[label] = (totals[label] || 0) + 1
      hours.set(key, totals)
    })

    const rows = app.bucketRangeFor(events)

    return Array.from(labels)
      .sort()
      .map((label) => ({
        label,
        rows: rows.map((row) => ({
          key: row.sortKey,
          label: row.label,
          date: row.date || app.parseBucketKey(row.sortKey),
          value: (hours.get(row.sortKey) || {})[label] || 0,
        })),
      }))
      .filter((series) => series.rows.some((row) => row.value > 0))
  }

  /**
   * ruleUsageSeriesByHour returns range-bucketed series for the most-applied rules,
   * capped at ruleSeriesLimit series and ordered by total applications.
   * Series are labeled by rule id and carry the rule text as description.
   */
  app.ruleUsageSeriesByHour = () => {
    const events = app.filteredRuleApplicationEvents()
    const ruleIdFor = (event) => event.ruleId || ""
    const totalsById = new Map()
    const textById = new Map()

    events.forEach((event) => {
      const ruleId = ruleIdFor(event)
      if (!ruleId) return
      totalsById.set(ruleId, (totalsById.get(ruleId) || 0) + 1)
      textById.set(ruleId, app.plainRuleText(event.ruleText))
    })

    const topIds = new Set(
      [...totalsById.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, app.ruleSeriesLimit)
        .map(([ruleId]) => ruleId),
    )

    return app
      .aggregateSeriesByHour(events.filter((event) => topIds.has(ruleIdFor(event))), ruleIdFor)
      .map((series) => ({ ...series, description: textById.get(series.label) }))
      .sort((a, b) => (totalsById.get(b.label) || 0) - (totalsById.get(a.label) || 0))
  }
}
