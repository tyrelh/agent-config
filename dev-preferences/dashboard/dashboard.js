{
  const app = window.DevPrefs

  /**
   * currentTheme returns the active light/dark theme.
   */
  app.currentTheme = () =>
    document.documentElement.dataset.theme === "dark" ? "dark" : "light"

  /**
   * applyTheme sets the document theme and updates the toggle label.
   */
  app.applyTheme = (theme) => {
    const nextTheme = theme === "dark" ? "dark" : "light"
    document.documentElement.dataset.theme = nextTheme
    localStorage.setItem(app.themeStorageKey, nextTheme)
    if (!app.elements.themeToggle) return

    const nextLabel = nextTheme === "dark" ? "Light" : "Dark"
    app.elements.themeToggle.textContent = nextLabel
    app.elements.themeToggle.setAttribute(
      "aria-label",
      nextTheme === "dark" ? "Switch to light mode" : "Switch to dark mode",
    )
  }

  /**
   * bindControls wires the dashboard controls.
   */
  app.bindControls = () => {
    if (app.elements.themeToggle) {
      app.elements.themeToggle.addEventListener("click", () => {
        app.applyTheme(app.currentTheme() === "dark" ? "light" : "dark")
      })
    }

    document.querySelectorAll("button[data-view]").forEach((button) => {
      button.addEventListener("click", () => {
        app.state.view = button.dataset.view
        app.renderView()
        if (app.state.view === "analytics") app.updateAnalytics()
      })
    })

    document.querySelectorAll("button[data-f], button[data-s]").forEach((button) => {
      button.addEventListener("click", () => {
        const stateKey = button.dataset.f ? "ruleFilter" : "ruleSort"
        const selector = button.dataset.f ? "button[data-f]" : "button[data-s]"

        app.state[stateKey] = button.dataset.f || button.dataset.s
        document.querySelectorAll(selector).forEach((item) => {
          item.classList.toggle("on", item === button)
        })
        app.renderRules()
      })
    })

    app.elements.rulesList.addEventListener("click", (event) => {
      const historyButton = event.target.closest("button[data-history-page]")
      if (historyButton) {
        const rule = historyButton.closest(".rule")
        const ruleId = rule && rule.dataset.ruleId
        if (!ruleId) return

        const direction = historyButton.dataset.historyDirection
        app.state.historyPageByRuleID[ruleId] = Number(historyButton.dataset.historyPage)
        rule.querySelector(".history-content").innerHTML = app.renderUsageHistory(ruleId)
        const nextFocus =
          rule.querySelector(`button[data-history-direction="${direction}"]:not(:disabled)`) ||
          rule.querySelector("button[data-history-page]:not(:disabled)")
        if (nextFocus) nextFocus.focus()
        return
      }

      const rule = event.target.closest(".rule")
      if (!rule) return

      rule.classList.toggle("open")
      rule.setAttribute("aria-expanded", rule.classList.contains("open") ? "true" : "false")
      const historyContent = rule.querySelector(".history-content")
      if (rule.classList.contains("open") && !historyContent.dataset.loaded) {
        historyContent.innerHTML = app.renderUsageHistory(rule.dataset.ruleId)
        historyContent.dataset.loaded = "true"
      }
    })

    app.elements.rulesList.addEventListener("keydown", (event) => {
      if ((event.key !== "Enter" && event.key !== " ") || !event.target.classList.contains("rule")) {
        return
      }

      event.preventDefault()
      event.target.click()
    })

    app.elements.analyticsView.addEventListener("click", (event) => {
      const button = event.target.closest("button[data-a]")
      if (!button) return

      app.state[button.dataset.a] = button.dataset.v
      button
        .closest(".control-group")
        .querySelectorAll("button[data-a]")
        .forEach((item) => item.classList.toggle("on", item === button))
      app.updateAnalytics()
    })
  }

  /**
   * renderDashboard renders all dashboard content.
   */
  app.renderDashboard = () => {
    app.renderCards()
    app.renderFiles()
    app.renderMining()
    app.renderAnalytics()
    app.renderRules()
    app.renderView()
  }

  app.applyTheme(app.currentTheme())
  app.bindControls()
  app.renderDashboard()
}
