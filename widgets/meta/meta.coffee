class Dashing.Meta extends Dashing.Widget
	constructor:  ->
    super

    type = Batman.Filters.dashize(@view)
    # Widget is rendered outside of normal dashboard
    $(@node).removeClass("widget widget-#{type} #{@id}")