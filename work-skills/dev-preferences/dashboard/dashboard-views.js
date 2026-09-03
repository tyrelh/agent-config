{
  const app = window.DevPrefs

  /**
   * renderCards renders the summary metrics at the top of the dashboard.
   */
  app.renderCards = () => {
    const appliedRuleCount = Object.values(app.data.usageByRuleID || {}).reduce(
      (sum, count) => sum + (Number(count) || 0),
      0,
    )
    const prMiningRuns = app.data.prMining || []
    const evidencePrCount = app.data.sections.reduce(
      (sum, section) => sum + (Number(section.evidencePRs) || 0),
      0,
    )
    const skillUses = app.data.skillUsage || []
    const latestRecorded = (valueFor) => {
      for (let index = skillUses.length - 1; index >= 0; index -= 1) {
        const value = valueFor(skillUses[index])
        if (value) return value
      }
      return ""
    }
    const latestAgent = latestRecorded(app.agentNameFor)
    const latestModel = latestRecorded(app.modelNameFor)
    const latestAgentModel = latestRecorded(app.agentModelLabelFor)
    const latestProject = latestRecorded(app.projectNameFor)
    const distinctAgentModels = new Set(skillUses.map(app.agentModelLabelFor).filter(Boolean)).size
    const distinctProjects = new Set(skillUses.map(app.projectNameFor).filter(Boolean)).size
    const developer = app.data.developer || {}
    const developerLabel = developer.githubUsername
      ? `${developer.devName || "Developer"} (@${developer.githubUsername})`
      : developer.devName || "Developer"
    const latestSkillUse = skillUses.length ? skillUses[skillUses.length - 1].usedAt : null
    const latestPrMining = prMiningRuns.length ? prMiningRuns[prMiningRuns.length - 1].minedAt : null

    app.elements.heading.textContent = `Developer preferences: ${developerLabel}`
    app.elements.subtitle.textContent =
      `${app.data.activeRuleCount} active rules across ${app.data.sectionCount} sections - ` +
      `source: ${app.data.source} - rules updated ${app.formatDate(app.data.rulesUpdatedAt)} - ` +
      `dashboard generated ${app.formatDate(app.data.generatedAt)}`

    app.elements.cards.innerHTML = [
      ["Active rules", app.data.activeRuleCount],
      ["Removed", (app.data.removed || []).length],
      ["Usage events", appliedRuleCount],
      ["Skill uses", skillUses.length],
      ["Last agent", latestAgent || "unknown"],
      ["Last model", latestModel || "unknown"],
      ["Last pair", latestAgentModel || "unknown"],
      ["Model pairs", distinctAgentModels || "none"],
      ["Last project", latestProject || "unknown"],
      ["Projects", distinctProjects || "none"],
      ["Evidence PRs", evidencePrCount],
      ["PR mining runs", prMiningRuns.length],
      ["Last PR mining", app.formatDate(latestPrMining)],
      ["Last skill use", app.formatDate(latestSkillUse)],
    ]
      .map(
        ([label, value]) =>
          `<div class="card"><div class="label">${app.escapeHtml(label)}</div>` +
          `<div class="num ${String(value).length > 8 ? "long" : ""}">${app.escapeHtml(value)}</div></div>`,
      )
      .join("")
  }

  /**
   * formatJsonPreview renders JSON or text for inline file/report panels.
   */
  app.formatJsonPreview = (value) => {
    if (value == null) return ""
    if (typeof value === "string") return value
    try {
      return JSON.stringify(value, null, 2)
    } catch {
      return String(value)
    }
  }

  /**
   * languageForPath picks a highlighter language from a local file path.
   */
  app.languageForPath = (path) => {
    const name = String(path || "").toLowerCase()
    if (name.endsWith(".md")) return "markdown"
    return "json"
  }

  /**
   * tokenHtml wraps escaped text in a syntax-highlight token span.
   */
  app.tokenHtml = (type, text) =>
    `<span class="tok tok-${type}">${app.escapeHtml(text)}</span>`

  /**
   * highlightJson colors JSON keys, strings, numbers, and literals.
   */
  app.highlightJson = (source) => {
    const pattern =
      /("(?:\\.|[^"\\])*")\s*:|("(?:\\.|[^"\\])*")|\b(true|false|null)\b|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|([{}[\],:])|(\s+)|([\s\S])/g
    let html = ""
    let match
    while ((match = pattern.exec(source))) {
      if (match[1]) {
        const key = match[1]
        const trailing = match[0].slice(key.length)
        html += app.tokenHtml("key", key) + app.escapeHtml(trailing)
      } else if (match[2]) html += app.tokenHtml("string", match[2])
      else if (match[3]) html += app.tokenHtml(match[3] === "null" ? "null" : "bool", match[3])
      else if (match[4]) html += app.tokenHtml("number", match[4])
      else if (match[5]) html += app.tokenHtml("punct", match[5])
      else if (match[6]) html += app.escapeHtml(match[6])
      else html += app.escapeHtml(match[7] || "")
    }
    return html
  }

  /**
   * highlightMarkdown colors headings, code, emphasis, links, and lists.
   */
  app.highlightMarkdown = (source) =>
    String(source)
      .split("\n")
      .map((line) => {
        if (/^#{1,6}\s/.test(line)) return app.tokenHtml("heading", line)
        if (/^```/.test(line)) return app.tokenHtml("code", line)
        if (/^\s*([-*+]|\d+\.)\s+/.test(line)) {
          return line.replace(/^(\s*(?:[-*+]|\d+\.)\s+)(.*)$/, (_, marker, rest) =>
            app.tokenHtml("list", marker) + app.highlightMarkdownInline(rest),
          )
        }
        if (/^\s*>/.test(line)) return app.tokenHtml("quote", line)
        return app.highlightMarkdownInline(line)
      })
      .join("\n")

  /**
   * highlightMarkdownInline colors inline markdown markers inside a line.
   */
  app.highlightMarkdownInline = (line) => {
    const pattern =
      /(`[^`]+`)|(\*\*[^*]+\*\*|__[^_]+__)|(\*[^*]+\*|_[^_]+_)|(\[[^\]]+\]\([^)]+\))|([^*`_\[]+|.)/g
    let html = ""
    let match
    while ((match = pattern.exec(line))) {
      if (match[1]) html += app.tokenHtml("code", match[1])
      else if (match[2]) html += app.tokenHtml("strong", match[2])
      else if (match[3]) html += app.tokenHtml("em", match[3])
      else if (match[4]) html += app.tokenHtml("link", match[4])
      else html += app.escapeHtml(match[5] || "")
    }
    return html
  }

  /**
   * highlightSource returns colored HTML for a preview language.
   */
  app.highlightSource = (language, source) => {
    const text = String(source || "")
    if (language === "markdown") return app.highlightMarkdown(text)
    return app.highlightJson(text)
  }

  /**
   * renderDataPanels renders collapsible labeled JSON/text panels with context.
   */
  app.renderDataPanels = (container, items) => {
    container.innerHTML = items
      .map((item, index) => {
        const language = app.languageForPath(item.path)
        return (
          `<details class="data-panel">` +
          `<summary><span class="data-panel-title">${app.escapeHtml(item.label)}</span>` +
          (item.path ? `<code class="data-panel-path">${app.escapeHtml(item.path)}</code>` : "") +
          `</summary>` +
          (item.about ? `<p class="data-panel-about">${app.escapeHtml(item.about)}</p>` : "") +
          `<pre class="data-panel-body" data-lang="${language}">` +
          `<code data-panel-index="${index}"></code></pre>` +
          `</details>`
        )
      })
      .join("")

    container.querySelectorAll("code[data-panel-index]").forEach((block) => {
      const item = items[Number(block.dataset.panelIndex)]
      const language = app.languageForPath(item.path)
      const source = item.error || app.formatJsonPreview(item.content)
      block.innerHTML = item.error
        ? app.escapeHtml(source)
        : app.highlightSource(language, source)
    })
  }

  /**
   * renderFiles renders ignored local data files inline with context.
   */
  app.renderFiles = () => {
    const files = app.data.localFiles || []
    app.elements.filesView.innerHTML =
      "<h2>Local files</h2>" +
      "<p class=\"view-lead\">Generated and ignored state under <code>.local/</code>. Expand a file to inspect its contents.</p>" +
      (files.length ? "<div class=\"data-panels\"></div>" : "<p class=\"empty\">No local file previews yet. Run <code>python3 generate.py</code>.</p>")

    const panels = app.elements.filesView.querySelector(".data-panels")
    if (panels) app.renderDataPanels(panels, files)
  }

  /**
   * renderMining renders PR mining runs with inline report JSON previews.
   */
  app.renderMining = () => {
    const runs = app.data.prMining || []
    const panels = [
      {
        about: "Index of PR-mining runs recorded under .local/pr-analysis/.",
        content: runs.map(({ report, reportError, ...meta }) => meta),
        label: "PR mining index",
        path: "pr-analysis/index.json",
      },
      ...runs.map((run) => ({
        about:
          `${run.repo || "unknown repo"} by ${run.author || "unknown"} — ` +
          `${run.authorComments != null ? `${run.authorComments} author comments across ` : ""}` +
          `${run.mergedPrs || 0} PRs` +
          `${run.mode ? ` (${run.mode})` : ""}, mined ${app.formatDate(run.minedAt)}. ` +
          "Large PR lists are summarized to a count plus a small sample.",
        content: run.report,
        error: run.report ? "" : run.reportError || "Report JSON not found.",
        label: `${run.repo || "PR mining"} — ${app.formatDate(run.minedAt)}`,
        path: String(run.json || "").replace(/^\.local\//, ""),
      })),
    ]

    app.elements.miningView.innerHTML =
      "<h2>PR mining</h2>" +
      "<p class=\"view-lead\">Evidence reports from <code>analyze_prs.py</code>. Expand a run to inspect its JSON.</p>" +
      (runs.length
        ? "<div class=\"data-panels\"></div>"
        : "<p class=\"empty\">No PR mining runs yet.</p>")

    const root = app.elements.miningView.querySelector(".data-panels")
    if (root) app.renderDataPanels(root, panels)
  }

  /**
   * renderAnalyticsControl renders one button group for plot filters.
   */
  app.renderAnalyticsControl = (key, label, options) =>
    `<div class="control-group control-${app.escapeHtml(key)}"><span class="slabel">${app.escapeHtml(label)}</span>` +
    options
      .map((option) => {
        const selected = app.state[key] === option.value
        return (
          `<button data-a="${app.escapeHtml(key)}" data-v="${app.escapeHtml(option.value)}" ` +
          `class="${selected ? "on" : ""}">${app.escapeHtml(option.label)}</button>`
        )
      })
      .join("") +
    "</div>"

  /**
   * renderAnalyticsFilters renders shared controls for all analytics plots.
   */
  app.renderAnalyticsFilters = () =>
    "<div class=\"controls analytics-controls\">" +
    app.renderAnalyticsControl(
      "analyticsRange",
      "Range",
      Object.entries(app.analyticsRanges).map(([value, config]) => ({
        value,
        label: config.label,
      })),
    ) +
    app.renderAnalyticsControl(
      "analyticsProject",
      "Project",
      app.metadataOptions("All projects", app.projectNameFor),
    ) +
    app.renderAnalyticsControl(
      "analyticsAgent",
      "Agent",
      app.metadataOptions("All agents", app.agentNameFor),
    ) +
    app.renderAnalyticsControl(
      "analyticsModel",
      "Model",
      app.metadataOptions("All models", app.modelNameFor),
    ) +
    app.renderAnalyticsControl(
      "analyticsAgentModel",
      "Agent / Model Pair",
      app.metadataOptions("All pairs", app.agentModelLabelFor),
    ) +
    "</div>"

  /**
   * analyticsPanels defines each analytics chart: its copy plus a series supplier.
   * Notes may be functions when the copy depends on the active filters.
   */
  /**
   * analyticsBucketNote returns shared copy for the active Range plot interval.
   */
  app.analyticsBucketNote = () =>
    `${app.activeRangeConfig().label} at ${app.bucketLabel()} points; lines and circles show every original value`

  app.analyticsPanels = [
    {
      key: "activity",
      title: "Activity over time",
      note: () =>
        `Rule usage is Usage events; skill usage is Skill uses. ${app.analyticsBucketNote()}. ` +
        `Click legend items to toggle series.`,
      options: {
        emptyText: "No activity matches the active filters.",
        label: "Activity over time",
        valueSuffix: " uses",
      },
      series: app.usageSummarySeriesByHour,
    },
    {
      key: "ruleUsage",
      title: "Rule usage over time",
      note: () =>
        `Usage events for the ${app.ruleSeriesLimit} most-used rules within the active filters. ` +
        `${app.analyticsBucketNote()}. Hover a rule id to read the rule; click it to toggle the series.`,
      options: {
        emptyText: "No rule applications match the active filters.",
        label: "Rule usage over time",
        valueSuffix: " uses",
      },
      series: app.ruleUsageSeriesByHour,
    },
    {
      key: "project",
      title: "Usage events by project",
      note: () =>
        `All active and removed rule applications grouped by repository or project. ${app.analyticsBucketNote()}. ` +
        "Legacy applications recorded before detailed history are UNKNOWN at the first tracked point.",
      options: {
        emptyText: "No project metadata has been recorded yet.",
        label: "Usage events by project",
        showTotal: true,
        valueSuffix: " uses",
      },
      series: () =>
        app.aggregateSeriesByHour(app.filteredRuleApplicationEvents(), app.projectNameFor),
    },
    {
      key: "agent",
      title: "Usage events by agent",
      note: () =>
        `All active and removed rule applications grouped by recorded agent family. ${app.analyticsBucketNote()}. Click legend items to toggle series.`,
      options: {
        emptyText: "No agent metadata has been recorded yet.",
        label: "Usage events by agent over time",
        showTotal: true,
        valueSuffix: " uses",
      },
      series: () =>
        app.aggregateSeriesByHour(app.filteredRuleApplicationEvents(), app.agentNameFor),
    },
    {
      key: "model",
      title: "Usage events by model",
      note: () =>
        `All active and removed rule applications grouped by recorded model/version. ${app.analyticsBucketNote()}. Click legend items to toggle series.`,
      options: {
        emptyText: "No model metadata has been recorded yet.",
        label: "Usage events by model over time",
        showTotal: true,
        valueSuffix: " uses",
      },
      series: () =>
        app.aggregateSeriesByHour(app.filteredRuleApplicationEvents(), app.modelNameFor),
    },
    {
      key: "agentModel",
      title: "Usage events by agent/model pair",
      note: () =>
        `All active and removed rule applications grouped by combined agent/model metadata. ${app.analyticsBucketNote()}. Click legend items to toggle series.`,
      options: {
        emptyText: "No agent/model metadata has been recorded yet.",
        label: "Usage events by agent/model pair over time",
        showTotal: true,
        valueSuffix: " uses",
      },
      series: () =>
        app.aggregateSeriesByHour(app.filteredRuleApplicationEvents(), app.agentModelLabelFor),
    },
  ]

  /**
   * renderAnalytics builds the analytics skeleton and its charts exactly once.
   * Filter changes go through updateAnalytics, which only re-joins chart data.
   */
  app.renderAnalytics = () => {
    app.elements.analyticsView.innerHTML =
      app.renderAnalyticsFilters() +
      "<div class=\"chart-grid\">" +
      app.analyticsPanels
        .map(
          (panel) =>
            `<article class="panel" data-panel="${app.escapeHtml(panel.key)}">` +
            `<h2>${app.escapeHtml(panel.title)}</h2>` +
            `<p class="chart-note" data-note="${app.escapeHtml(panel.key)}"></p>` +
            `<div class="d3-chart" data-chart="${app.escapeHtml(panel.key)}"></div></article>`,
        )
        .join("") +
      "</div>"

    app.analyticsPanels.forEach((panel) => {
      panel.chart = app.createLineChart(
        app.elements.analyticsView.querySelector(`[data-chart="${panel.key}"]`),
        panel.options,
      )
    })
    app.updateAnalytics()
  }

  /**
   * updateAnalytics refreshes chart data and notes for the active filters.
   */
  app.updateAnalytics = () => {
    app.analyticsPanels.forEach((panel) => {
      const note = app.elements.analyticsView.querySelector(`[data-note="${panel.key}"]`)
      note.textContent = typeof panel.note === "function" ? panel.note() : panel.note
      panel.chart.update(panel.series())
    })
  }

  /**
   * renderUsageHistory renders timestamped usage details for an active or removed rule.
   */
  app.renderUsageHistory = (ruleId) => {
    const context = app.historyContextFor(ruleId)
    if (!context) return "<p>No recorded uses yet.</p>"

    const { ruleText, history: usageHistory, total } = context
    const legacyCount = Math.max(0, total - usageHistory.length)
    const newestUsageFirst = [...usageHistory].sort(
      (a, b) => new Date(b.usedAt).getTime() - new Date(a.usedAt).getTime(),
    )
    const pageCount = Math.max(1, Math.ceil(newestUsageFirst.length / app.historyPageSize))
    const requestedPage = app.state.historyPageByRuleID[ruleId] || 1
    const page = Math.min(Math.max(requestedPage, 1), pageCount)
    app.state.historyPageByRuleID[ruleId] = page
    const pageStart = (page - 1) * app.historyPageSize
    const pageEvents = newestUsageFirst.slice(pageStart, pageStart + app.historyPageSize)
    const historyItems = pageEvents
      .map((event) => {
        const showMatchedQuery = event.query && event.query !== ruleId && event.query !== ruleText
        const matchedQuery = showMatchedQuery
          ? `<span class="history-meta-item">matched ${app.escapeHtml(event.query)}</span>`
          : ""
        const agentLabel = app.agentModelLabelFor(event)
        const agent = agentLabel
          ? `<span class="history-meta-item">${app.escapeHtml(agentLabel)}</span>`
          : ""
        const projectName = app.projectNameFor(event)
        const projectStyle = app.projectLabelStyleFor(projectName)
        const project =
          `<span class="history-meta-item history-project${projectStyle ? "" : " project-unknown"}"` +
          `${projectStyle ? ` style="${projectStyle}"` : ""}>` +
          `Project: ${app.escapeHtml(projectName)}</span>`
        const reason = event.reason
          ? app.escapeHtml(event.reason)
          : "No reason recorded."
        const metadata = [agent, project, matchedQuery].filter(Boolean).join("")

        return (
          "<article class=\"history-event\">" +
          `<div class="history-time">${app.escapeHtml(app.formatDate(event.usedAt))}</div>` +
          `<div class="history-reason">${reason}</div>` +
          (metadata ? `<div class="history-meta">${metadata}</div>` : "") +
          "</article>"
        )
      })
      .join("")
    const legacyItem = legacyCount
      ? (
        "<article class=\"history-event history-legacy\">" +
        `${legacyCount} earlier use${legacyCount === 1 ? "" : "s"} recorded before timestamps existed` +
        "</article>"
      )
      : ""
    const pagination = newestUsageFirst.length
      ? (
        "<nav class=\"history-pagination\" aria-label=\"Usage history pages\">" +
        `<button type="button" data-history-direction="previous" data-history-page="${page - 1}"${page === 1 ? " disabled" : ""}>Previous</button>` +
        `<span aria-live="polite">Page ${app.formatInteger(page)} of ${app.formatInteger(pageCount)}</span>` +
        `<button type="button" data-history-direction="next" data-history-page="${page + 1}"${page === pageCount ? " disabled" : ""}>Next</button>` +
        "</nav>"
      )
      : ""

    return total
      ? `<div class="history-list">${historyItems}${legacyItem}</div>${pagination}`
      : "<p>No recorded uses yet.</p>"
  }

  /**
   * renderRuleChip renders a labeled pill used in rule card headers.
   */
  app.renderRuleChip = (label, value, chipClass) =>
    `<span class="rule-chip ${chipClass}"><span class="chip-label">${app.escapeHtml(label)}</span>` +
    `<span class="chip-value">${app.escapeHtml(value)}</span></span>`

  /**
   * renderRule renders a clickable rule row with optional section context.
   */
  app.renderRule = (ruleText, sectionName) => {
    const usageCount = app.usageCountFor(ruleText)
    const ruleId = app.data.ruleIds && app.data.ruleIds[ruleText]
    const ruleMetadata = app.ruleMetadataFor(ruleText)
    const addedNote = app.addedDateNoteFor(ruleMetadata.addedAtSource)
    const addedSourceNote = addedNote ? `<span class="meta-note">${app.escapeHtml(addedNote)}</span>` : ""
    const addedAt = ruleMetadata.addedAt ? app.escapeHtml(app.formatDate(ruleMetadata.addedAt)) : "Unknown"
    const lastUsedAt = app.lastUsedAtFor(ruleText)
    const lastUsedLabel = lastUsedAt ? app.escapeHtml(app.formatDate(lastUsedAt)) : "Never"
    const usageBadge = usageCount
      ? `<div class="used-count"><span>Used</span><strong>x${app.formatInteger(usageCount)}</strong></div>`
      : ""
    const idBadge = ruleId ? app.renderRuleChip("ID", ruleId, "chip-id") : ""
    const sectionBadge = sectionName
      ? app.renderRuleChip("Section", sectionName, "chip-section")
      : ""
    const ruleBadges = `<div class="rule-badges">${idBadge}${sectionBadge}</div>`
    const ruleMeta =
      "<div class=\"rule-meta\">" +
      `<span class="rule-meta-item meta-added"><span class="meta-label">Added</span><span class="meta-value">${addedAt}${addedSourceNote}</span></span>` +
      `<span class="rule-meta-item meta-used"><span class="meta-label">Last used</span><span class="meta-value">${lastUsedLabel}</span></span>` +
      "</div>"

    return (
      `<div class="rule" data-rule-id="${app.escapeHtml(ruleId || "")}" tabindex="0" role="button" aria-expanded="false">` +
      "<div class=\"rule-main\">" +
      "<div class=\"rule-content\">" +
      ruleBadges +
      `<div class="rule-text">${app.renderMarkdown(ruleText)}</div>` +
      ruleMeta +
      "</div>" +
      usageBadge +
      "</div>" +
      "<div class=\"history\"><strong>Usage history</strong>" +
      "<div class=\"history-content\"></div></div></div>"
    )
  }

  /**
   * renderRemovedRule renders a retired rule with the usage history it earned before removal.
   */
  app.renderRemovedRule = (entry) => {
    const ruleId = entry.ruleID || ""
    const usageCount = entry.usageCount || 0
    const history = entry.history || []
    const lastEvent = history[history.length - 1]
    const lastUsedLabel = lastEvent ? app.escapeHtml(app.formatDate(lastEvent.usedAt)) : "Never"
    const idBadge = ruleId ? app.renderRuleChip("ID", ruleId, "chip-id") : ""
    const sectionBadge = entry.section
      ? app.renderRuleChip("Section", entry.section, "chip-section")
      : ""
    const mergedBadge = entry.mergedInto
      ? app.renderRuleChip("Merged into", entry.mergedInto, "chip-merged")
      : ""
    const usageBadge = usageCount
      ? "<div class=\"used-count used-archived\"><span>Used before</span>" +
        `<strong>x${app.formatInteger(usageCount)}</strong></div>`
      : ""
    const reason = entry.reason ? `<span class="why">${app.escapeHtml(entry.reason)}</span>` : ""

    return (
      `<div class="rule removed" data-rule-id="${app.escapeHtml(ruleId)}" tabindex="0" role="button" aria-expanded="false">` +
      "<div class=\"rule-main\">" +
      "<div class=\"rule-content\">" +
      `<div class="rule-badges">${idBadge}${sectionBadge}${mergedBadge}</div>` +
      `<div class="rule-text">${app.renderMarkdown(entry.text || "")}</div>` +
      "<div class=\"rule-meta\">" +
      `<span class="rule-meta-item meta-added"><span class="meta-label">Removed</span><span class="meta-value">${app.escapeHtml(entry.dateRemoved || "Unknown")}</span></span>` +
      `<span class="rule-meta-item meta-used"><span class="meta-label">Last used</span><span class="meta-value">${lastUsedLabel}</span></span>` +
      "</div>" +
      reason +
      "</div>" +
      usageBadge +
      "</div>" +
      "<div class=\"history\"><strong>Archived usage history</strong>" +
      "<div class=\"history-content\"></div></div></div>"
    )
  }

  /**
   * renderSectionNotes renders section context that applies to rules in every sort.
   */
  app.renderSectionNotes = () =>
    app.data.sections
      .flatMap((section) => (section.notes || []).map((note) => ({ name: section.name, note })))
      .map(
        ({ name, note }) =>
          `<p class="section-note"><span class="section-note-label">${app.escapeHtml(name)}</span>` +
          `${app.renderMarkdown(note)}</p>`,
      )
      .join("")

  /**
   * renderRules renders active or removed rules using the selected filter and sort.
   */
  app.renderRules = () => {
    if (app.state.ruleFilter === "removed") {
      app.elements.rulesList.innerHTML = (app.data.removed || []).length
        ? "<div class=\"group\">" +
          (app.data.removed || []).map(app.renderRemovedRule).join("") +
          "</div>"
        : "<p class=\"empty\">No rules removed yet.</p>"
      return
    }

    const sectionGroups = app.data.sections
      .map((section) => ({
        section,
        rules: section.rules.filter(
          (ruleText) => app.state.ruleFilter !== "used" || app.usageCountFor(ruleText) > 0,
        ),
      }))
      .filter(({ rules }) => rules.length)

    if (!sectionGroups.length) {
      app.elements.rulesList.innerHTML = "<p class=\"empty\">Nothing in this view.</p>"
      return
    }

    if (app.state.ruleSort === "usage" || app.state.ruleSort === "added" || app.state.ruleSort === "lastUsed") {
      const rulesFlat = sectionGroups.flatMap(({ section, rules }) =>
        rules.map((ruleText) => ({ ruleText, sectionName: section.name })),
      )
      const sorter = {
        added: (a, b) =>
          app.timestampValue(app.addedAtFor(b.ruleText)) - app.timestampValue(app.addedAtFor(a.ruleText)),
        lastUsed: (a, b) =>
          app.timestampValue(app.lastUsedAtFor(b.ruleText)) -
          app.timestampValue(app.lastUsedAtFor(a.ruleText)),
        usage: (a, b) => app.usageCountFor(b.ruleText) - app.usageCountFor(a.ruleText),
      }[app.state.ruleSort]

      rulesFlat.sort(sorter)
      app.elements.rulesList.innerHTML =
        app.renderSectionNotes() +
        "<div class=\"group\">" +
        rulesFlat.map(({ ruleText, sectionName }) => app.renderRule(ruleText, sectionName)).join("") +
        "</div>"
      return
    }

    app.elements.rulesList.innerHTML = app.renderSectionNotes() + sectionGroups
      .map(({ section, rules }) => {
        const sectionMeta = [
          section.origin ? app.escapeHtml(section.origin) : "",
          section.evidencePRs ? `${section.evidencePRs} evidence PRs` : "",
          section.source ? `source: ${app.escapeHtml(section.source)}` : "",
        ]
          .filter(Boolean)
          .join(" - ")
        const metaHtml = sectionMeta ? `<span class="meta">${sectionMeta}</span>` : ""

        return (
          `<div class="group"><div class="ghead"><h2>${app.escapeHtml(section.name)}</h2>${metaHtml}</div>` +
          `${rules.map((ruleText) => app.renderRule(ruleText)).join("")}</div>`
        )
      })
      .join("")
  }

  /**
   * renderView shows the selected dashboard panel.
   */
  app.renderView = () => {
    app.elements.rulesView.hidden = app.state.view !== "rules"
    app.elements.analyticsView.hidden = app.state.view !== "analytics"
    app.elements.miningView.hidden = app.state.view !== "mining"
    app.elements.filesView.hidden = app.state.view !== "files"
    document.querySelectorAll("button[data-view]").forEach((button) => {
      button.classList.toggle("on", button.dataset.view === app.state.view)
    })
  }
}
