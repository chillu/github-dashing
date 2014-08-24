class Dashing.SeriesGraph extends Dashing.Widget

  @accessor 'current', ->
    return @get('displayedValue') if @get('displayedValue')
    series = @get('series')
    if series
      series[0][series[0].length - 1].y

  ready: ->
    container = $(@node).parent()
    # Gross hacks. Let's fix this.
    width = (Dashing.widget_base_dimensions[0] * container.data("sizex")) + Dashing.widget_margins[0] * 2 * (container.data("sizex") - 1)
    height = (Dashing.widget_base_dimensions[1] * container.data("sizey"))
    series = @get('series') ? []

    # Rickshaw causes exceptions when asked to render an empty series
    return unless series && series[0] && series[0].length > 1
    
    if $(@node).data("colorscheme") 
      scheme = $(@node).data("colorscheme")
    else if $(@node).data("colors") 
      scheme = $(@node).data("colors").split(' ')
    else 
      scheme = 'spectrum14'
    palette = new Rickshaw.Color.Palette({scheme: scheme})
    
    seriesCombined = []
    for data,i in series
      seriesCombined[i] = {data: data, color: palette.color()}
    
    @graph = new Rickshaw.Graph(
      element: @node
      renderer: $(@node).data("renderer") || 'area'
      width: width
      height: height
      series: seriesCombined,
      padding: {
        top: $(@node).data('paddingTop') || 0,
        bottom: $(@node).data('paddingBottom') || 0,
        left: $(@node).data('paddingLeft') || 0,
        right: $(@node).data('paddingRight') || 0
      }
    )

    x_axis = new Rickshaw.Graph.Axis.Time(graph: @graph)
    y_axis = new Rickshaw.Graph.Axis.Y(graph: @graph, tickFormat: Rickshaw.Fixtures.Number.formatKMBT)
    @graph.renderer.unstack = true if $(@node).data("unstack")
    @graph.render()

  onData: (data) ->
    if @graph
      @graph.series[i].data = seriesData for seriesData, i in series
      @graph.render()
