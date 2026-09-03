{
  const app = window.DevPrefs

  app.chartPalette = [
    "#4e79a7",
    "#f28e2b",
    "#e15759",
    "#76b7b2",
    "#59a14f",
    "#edc948",
    "#b07aa1",
    "#ff9da7",
    "#9c755f",
    "#bab0ac",
    "#86bcb6",
    "#d37295",
  ]

  /**
   * chartColorFor returns a distinct color for a series index.
   */
  app.chartColorFor = (index) => app.chartPalette[index % app.chartPalette.length]

  /**
   * createLineChart builds one persistent interactive line chart inside element.
   *
   * Uses D3 scaleTime / scaleLinear and axisBottom / axisLeft so range changes
   * refresh both axes. Each series is { label, rows: [{ key, label, date, value }] }.
   */
  app.createLineChart = (element, options = {}) => {
    if (!window.d3) {
      element.innerHTML = "<p class=\"empty\">D3 failed to load, so charts cannot render.</p>"
      return { update: () => {} }
    }

    const d3 = window.d3
    const height = 260
    const margin = { bottom: 56, left: 44, right: 16, top: 18 }
    const plotHeight = height - margin.top - margin.bottom
    const suffix = options.valueSuffix || ""
    const hiddenLabels = new Set()
    const bisectDate = d3.bisector((row) => row.date).center
    let series = []
    let colorByLabel = new Map()
    let plotWidth = 0
    let rows = []

    element.setAttribute("aria-label", options.label || "Time-series chart")

    const root = d3.select(element)
    const legend = root.append("div").attr("class", "chart-legend")
    const totalNote = options.showTotal ? root.append("div").attr("class", "chart-total") : null
    const emptyNote = root
      .append("p")
      .attr("class", "empty")
      .style("display", "none")
      .text(options.emptyText || "No data yet.")
    const svg = root.append("svg").attr("role", "img").style("width", "100%")
    const plot = svg.append("g").attr("transform", `translate(${margin.left},${margin.top})`)
    const gridLayer = plot.append("g").attr("class", "grid")
    const yAxisLayer = plot.append("g").attr("class", "axis axis-y")
    const xAxisLayer = plot
      .append("g")
      .attr("class", "axis axis-x")
      .attr("transform", `translate(0,${plotHeight})`)
    const seriesLayer = plot.append("g").attr("class", "series-layer")
    const focusLine = plot
      .append("line")
      .attr("class", "focus-line")
      .attr("y1", 0)
      .attr("y2", plotHeight)
      .style("display", "none")
    const overlay = plot
      .append("rect")
      .attr("class", "chart-overlay")
      .attr("height", plotHeight)
      .attr("fill", "transparent")
    const tooltip = root.append("div").attr("class", "chart-tooltip").style("display", "none")
    const legendTip = root
      .append("div")
      .attr("class", "chart-tooltip legend-tooltip")
      .style("display", "none")
    const x = d3.scaleTime().range([0, 0])
    const y = d3.scaleLinear().range([plotHeight, 0])
    const line = d3
      .line()
      .x((row) => x(row.date))
      .y((row) => y(Number(row.value) || 0))
      .curve(d3.curveLinear)

    /**
     * hideFocus hides the hover tooltip and focus line.
     */
    const hideFocus = () => {
      tooltip.style("display", "none")
      focusLine.style("display", "none")
    }

    /**
     * hideLegendTip hides the legend description tooltip.
     */
    const hideLegendTip = () => {
      legendTip.style("display", "none")
    }

    /**
     * placeTooltip positions a floating tip inside the chart element.
     */
    const placeTooltip = (node, clientX, clientY, widthHint = 220) => {
      const bounds = element.getBoundingClientRect()
      const left = Math.min(clientX - bounds.left + 12, bounds.width - widthHint)
      const top = Math.max(clientY - bounds.top - 12, 8)
      node.style("left", `${Math.max(8, left)}px`).style("top", `${top}px`)
    }

    /**
     * showLegendTip renders the rule/series description beside a legend item.
     */
    const showLegendTip = (event, item) => {
      if (!item.description) {
        hideLegendTip()
        return
      }

      legendTip
        .style("display", "block")
        .html(
          `<span class="legend-tooltip-id">${app.escapeHtml(item.label)}</span>` +
            `<p class="legend-tooltip-text">${app.escapeHtml(item.description)}</p>`,
        )
      placeTooltip(legendTip, event.clientX, event.clientY, 280)
    }

    /**
     * xTickFormat picks a compact local label from the active bucket size.
     */
    const xTickFormat = (date) => {
      if (app.activeBucketHours() >= 24) {
        return date.toLocaleDateString(undefined, { day: "numeric", month: "short" })
      }
      return date.toLocaleString(undefined, {
        day: "numeric",
        hour: "numeric",
        month: "short",
      })
    }

    /**
     * xTickValues returns evenly spaced bucket dates that fit the plot width.
     */
    const xTickValues = () => {
      if (!rows.length) return []
      if (rows.length === 1) return [rows[0].date]

      const labelWidth = app.activeBucketHours() >= 24 ? 72 : 100
      const capacity = Math.max(2, Math.floor(plotWidth / labelWidth))
      const count = Math.min(capacity, rows.length)
      if (count >= rows.length) return rows.map((row) => row.date)

      return d3.range(count).map((index) => {
        const rowIndex = Math.round((index * (rows.length - 1)) / (count - 1))
        return rows[rowIndex].date
      })
    }

    /**
     * drawAxes redraws D3 axes for the current scales.
     */
    const drawAxes = () => {
      const yMax = y.domain()[1]
      const yTicks = yMax <= 5 ? d3.range(0, yMax + 1) : null
      const yAxis = d3
        .axisLeft(y)
        .tickFormat((value) => (Number.isInteger(value) ? app.formatInteger(value) : ""))
      if (yTicks) yAxis.tickValues(yTicks)
      else yAxis.ticks(4)

      gridLayer.call(
        d3
          .axisLeft(y)
          .tickValues(yTicks || y.ticks(4))
          .tickSize(-plotWidth)
          .tickFormat(""),
      )
      yAxisLayer.call(yAxis)

      const tickValues = xTickValues()
      xAxisLayer.call(
        d3.axisBottom(x).tickValues(tickValues).tickSizeOuter(0).tickFormat(xTickFormat),
      )
      xAxisLayer
        .selectAll("text")
        .attr("text-anchor", "end")
        .attr("dx", "-0.35em")
        .attr("dy", "0.55em")
        .attr("transform", "rotate(-32)")
    }

    /**
     * drawSeries joins lines and points for the series visible in the legend.
     */
    const drawSeries = () => {
      const visible = series.filter((item) => !hiddenLabels.has(item.label))
      const groups = seriesLayer
        .selectAll("g.series")
        .data(visible, (item) => item.label)
        .join((enter) => {
          const group = enter.append("g").attr("class", "series")
          group.append("path").attr("class", "line-path")
          return group
        })

      groups
        .select(".line-path")
        .attr("stroke", (item) => colorByLabel.get(item.label))
        .attr("d", (item) => line(item.rows))

      groups
        .selectAll("circle.line-point")
        .data(
          (item) =>
            item.rows.map((row) => ({ ...row, seriesLabel: item.label })),
          (row) => row.key,
        )
        .join("circle")
        .attr("class", "line-point")
        .attr("cx", (row) => x(row.date))
        .attr("cy", (row) => y(Number(row.value) || 0))
        .attr("r", (row) => (Number(row.value) > 0 ? 4 : 2.25))
        .attr("opacity", (row) => (Number(row.value) > 0 ? 1 : 0.35))
        .attr("stroke", (row) => colorByLabel.get(row.seriesLabel))
    }

    /**
     * drawLegend joins one visibility-toggle button per series.
     */
    const drawLegend = () => {
      legend
        .selectAll("button.legend-item")
        .data(series, (item) => item.label)
        .join((enter) => {
          const button = enter
            .append("button")
            .attr("type", "button")
            .attr("class", "legend-item")
            .on("click", (event, item) => {
              if (hiddenLabels.has(item.label)) hiddenLabels.delete(item.label)
              else hiddenLabels.add(item.label)

              const pressed = !hiddenLabels.has(item.label)
              event.currentTarget.classList.toggle("off", !pressed)
              event.currentTarget.setAttribute("aria-pressed", String(pressed))
              hideLegendTip()
              drawSeries()
            })
            .on("mouseenter", (event, item) => showLegendTip(event, item))
            .on("mousemove", (event, item) => showLegendTip(event, item))
            .on("mouseleave", hideLegendTip)
          button.append("span").attr("class", "legend-swatch")
          button.append("span").attr("class", "legend-label")
          return button
        })
        .order()
        .classed("off", (item) => hiddenLabels.has(item.label))
        .classed("has-description", (item) => Boolean(item.description))
        .attr("aria-pressed", (item) => String(!hiddenLabels.has(item.label)))
        .attr("aria-label", (item) =>
          item.description ? `${item.label}: ${item.description}` : item.label,
        )
        .call((buttons) =>
          buttons.select(".legend-swatch").style("background", (item) => colorByLabel.get(item.label)),
        )
        .call((buttons) => buttons.select(".legend-label").text((item) => item.label))
    }

    overlay
      .on("mousemove", (event) => {
        if (!rows.length) return

        const [pointerX] = d3.pointer(event)
        const index = bisectDate(rows, x.invert(pointerX))
        const nearest = rows[Math.max(0, Math.min(rows.length - 1, index))]
        const visible = series.filter((item) => !hiddenLabels.has(item.label))
        const points = visible
          .map((item) => {
            const row = item.rows.find((entry) => entry.key === nearest.key)
            if (!row || !Number(row.value)) return null
            return {
              color: colorByLabel.get(item.label),
              description: item.description || "",
              label: item.label,
              value: Number(row.value),
              xLabel: row.label,
            }
          })
          .filter(Boolean)
          .sort((a, b) => b.value - a.value)

        if (!points.length) {
          hideFocus()
          return
        }

        focusLine
          .style("display", null)
          .attr("x1", x(nearest.date))
          .attr("x2", x(nearest.date))

        tooltip
          .style("display", "block")
          .html(
            `<strong>${app.escapeHtml(points[0].xLabel)}</strong>` +
              points
                .map((point) => {
                  const detail = point.description
                    ? `<span class="tooltip-rule">${app.escapeHtml(point.description)}</span>`
                    : ""
                  return (
                    `<div class="tooltip-row">` +
                    `<span class="tooltip-swatch" style="background:${point.color}"></span>` +
                    `<div class="tooltip-copy">` +
                    `<span class="tooltip-label">${app.escapeHtml(point.label)}: ${app.formatInteger(point.value)}${app.escapeHtml(suffix)}</span>` +
                    detail +
                    `</div></div>`
                  )
                })
                .join(""),
          )

        placeTooltip(tooltip, event.clientX, event.clientY, 260)
      })
      .on("mouseleave", hideFocus)

    /**
     * update joins the next series into the chart, keeping legend toggles.
     */
    const update = (nextSeries) => {
      series = nextSeries || []
      hiddenLabels.forEach((label) => {
        if (!series.some((item) => item.label === label)) hiddenLabels.delete(label)
      })
      colorByLabel = new Map(series.map((item, index) => [item.label, app.chartColorFor(index)]))
      hideFocus()
      hideLegendTip()

      rows = series[0]?.rows || []
      const hasData = Boolean(series.length && rows.length)
      emptyNote.style("display", hasData ? "none" : null)
      svg.style("display", hasData ? null : "none")
      legend.style("display", hasData ? null : "none")
      if (totalNote) totalNote.style("display", hasData ? null : "none")
      if (!hasData) {
        seriesLayer.selectAll("*").remove()
        return
      }

      const width = Math.max(element.clientWidth || 420, 280)
      plotWidth = width - margin.left - margin.right
      svg.attr("viewBox", `0 0 ${width} ${height}`)
      overlay.attr("width", plotWidth)

      const extent = d3.extent(rows, (row) => row.date)
      x.domain(extent[0] && extent[1] && extent[0] < extent[1] ? extent : [extent[0], d3.timeHour.offset(extent[0], 1)])
        .range([0, plotWidth])

      const yMax = Math.max(
        1,
        d3.max(series, (item) => d3.max(item.rows, (row) => Number(row.value) || 0)) || 0,
      )
      y.domain([0, yMax]).nice(4)

      drawAxes()

      if (totalNote) {
        const total = d3.sum(series, (item) => d3.sum(item.rows, (row) => Number(row.value) || 0))
        totalNote.text(`${app.formatInteger(total)}${suffix} total`)
      }

      drawLegend()
      drawSeries()
    }

    return { update }
  }

}
