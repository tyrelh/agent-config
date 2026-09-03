window.DevPrefs = {
  /**
   * analyticsRanges maps each Range control value to a lookback window and the
   * plot-point bucket size used while that range is selected.
   */
  analyticsRanges: {
    "24h": {
      bucketHours: 2,
      label: "Last 24h",
      windowMs: 24 * 60 * 60 * 1000,
    },
    "7d": {
      bucketHours: 12,
      label: "Last 7 days",
      windowMs: 7 * 24 * 60 * 60 * 1000,
    },
    "30d": {
      bucketHours: 24,
      label: "Last 30 days",
      windowMs: 30 * 24 * 60 * 60 * 1000,
    },
    "90d": {
      bucketHours: 72,
      label: "Last 90 days",
      windowMs: 90 * 24 * 60 * 60 * 1000,
    },
    all: {
      bucketHours: 24,
      label: "All",
      windowMs: null,
    },
  },
  data: window.PREFERENCES_DATA,
  elements: {
    analyticsView: document.getElementById("analyticsView"),
    cards: document.getElementById("cards"),
    filesView: document.getElementById("filesView"),
    heading: document.querySelector("h1"),
    miningView: document.getElementById("miningView"),
    rulesList: document.getElementById("list"),
    rulesView: document.getElementById("rulesView"),
    subtitle: document.getElementById("sub"),
    themeToggle: document.getElementById("themeToggle"),
  },
  themeStorageKey: "devprefs-theme",
  historyPageSize: 10,
  ruleSeriesLimit: 8,
  localFiles: [],
  state: {
    analyticsAgent: "all",
    analyticsAgentModel: "all",
    analyticsModel: "all",
    analyticsProject: "all",
    analyticsRange: "7d",
    historyPageByRuleID: {},
    ruleFilter: "all",
    ruleSort: "added",
    view: "rules",
  },
}
