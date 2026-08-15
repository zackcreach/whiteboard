import * as echarts from 'echarts/core'
import { LineChart } from 'echarts/charts'
import {
  GridComponent,
  MarkLineComponent,
  TooltipComponent,
} from 'echarts/components'
import { SVGRenderer } from 'echarts/renderers'

echarts.use([
  GridComponent,
  LineChart,
  MarkLineComponent,
  SVGRenderer,
  TooltipComponent,
])

const labelSpacing = 56
const symbolSpacing = 18
const axisDateFormatter = new Intl.DateTimeFormat(undefined, {
  month: 'numeric',
  day: 'numeric',
  timeZone: 'UTC',
})
const tooltipDateFormatter = new Intl.DateTimeFormat(undefined, {
  dateStyle: 'medium',
  timeZone: 'UTC',
})
const weightFormatter = new Intl.NumberFormat(undefined, {
  maximumFractionDigits: 2,
})
const htmlEntities = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }

function cssColor(colorProbe, name) {
  colorProbe.style.color = `var(${name})`
  return getComputedStyle(colorProbe).color
}

function dateLabel(value) {
  return axisDateFormatter.format(value)
}

function escapeHtml(value) {
  return value.replace(/[&<>"']/g, (character) => htmlEntities[character])
}

function tooltipFormatter(parameters) {
  const points = parameters.filter((parameter) => parameter.data?.workoutName)
  if (points.length === 0) return ''

  const date = tooltipDateFormatter.format(points[0].value[0])
  const rows = points.map((point) => {
    const weight = weightFormatter.format(point.value[1])
    return `${point.marker}${escapeHtml(point.seriesName)}<br>${escapeHtml(point.data.workoutName)}: ${weight}`
  })

  return `${date}<br>${rows.join('<br>')}`
}

function chartOption(element, model, colorProbe) {
  const width = element.clientWidth
  const maximumLabels = Math.max(2, Math.floor((width - 80) / labelSpacing))
  const labelStep = Math.max(
    1,
    Math.ceil(model.boundaries.length / maximumLabels)
  )
  const visibleLabels = model.boundaries.filter(
    (_boundary, index) => index % labelStep === 0
  )
  const plotWidth = Math.max(0, width - 80)
  const rangeDuration = Math.max(1, model.range[1] - model.range[0])
  const textColor = cssColor(colorProbe, '--chart-text-color')
  const gridColor = cssColor(colorProbe, '--chart-grid-color')

  return {
    animation: false,
    grid: { left: model.axis_label ? 64 : 48, right: 16, top: 16, bottom: 48 },
    tooltip: { trigger: 'axis', formatter: tooltipFormatter },
    xAxis: {
      type: 'time',
      min: model.range[0],
      max: model.range[1],
      axisLabel: {
        color: textColor,
        customValues: visibleLabels,
        formatter: dateLabel,
      },
      axisLine: { lineStyle: { color: gridColor } },
      axisTick: {
        customValues: visibleLabels,
        lineStyle: { color: gridColor },
      },
      splitLine: { show: false },
    },
    yAxis: {
      type: 'value',
      min: 0,
      name: model.axis_label || '',
      nameLocation: 'middle',
      nameGap: 48,
      nameTextStyle: { color: textColor, fontWeight: 600 },
      axisLabel: { color: textColor },
      splitLine: { lineStyle: { color: gridColor } },
    },
    series: model.series.map((series, index) => {
      const color = cssColor(colorProbe, series.color)
      const points = series.points.map((point) => ({
        value: [point.occurred_at, point.weight],
        workoutId: point.workout_id,
        workoutName: point.workout_name,
      }))
      const spacing =
        points.length < 2
          ? plotWidth
          : (plotWidth *
              (points[points.length - 1].value[0] - points[0].value[0])) /
            rangeDuration /
            (points.length - 1)

      return {
        type: 'line',
        name: series.label,
        data: points,
        showSymbol: spacing >= symbolSpacing,
        symbolSize: 8,
        lineStyle: { color },
        itemStyle: { color },
        markLine:
          index === 0
            ? {
                silent: true,
                symbol: 'none',
                label: { show: false },
                lineStyle: { color: gridColor, type: 'solid', width: 1 },
                data: model.boundaries.map((boundary) => ({ xAxis: boundary })),
              }
            : undefined,
      }
    }),
  }
}

export const ProgressionChart = {
  mounted() {
    this.model = JSON.parse(this.el.dataset.chartModel)
    this.colorProbe = document.createElement('span')
    this.colorProbe.hidden = true
    document.body.appendChild(this.colorProbe)
    this.chart = echarts.init(this.el, null, { renderer: 'svg' })
    this.renderChart = () => {
      if (this.el.clientWidth === 0 || this.el.clientHeight === 0) return
      this.chart.resize()
      this.chart.setOption(chartOption(this.el, this.model, this.colorProbe), true)
    }
    this.scheduleRenderChart = () => {
      cancelAnimationFrame(this.renderAnimationFrame)
      this.renderAnimationFrame = requestAnimationFrame(this.renderChart)
    }
    this.resizeObserver = new ResizeObserver(this.scheduleRenderChart)
    this.themeObserver = new MutationObserver(this.scheduleRenderChart)
    this.resizeObserver.observe(this.el)
    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['class'],
    })
    this.scheduleRenderChart()
  },

  updated() {
    this.model = JSON.parse(this.el.dataset.chartModel)
    this.scheduleRenderChart()
  },

  destroyed() {
    cancelAnimationFrame(this.renderAnimationFrame)
    this.resizeObserver.disconnect()
    this.themeObserver.disconnect()
    this.chart.dispose()
    this.colorProbe.remove()
  },
}
