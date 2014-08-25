class Dashing.Leaderboard extends Dashing.Widget

	ready: ->
		# Requires jQuery Powertip plugin
    	setTimeout ( =>
    		$(@node).find('.tooltip').powerTip {placement: 's', smartPlacement: true, mouseOnToPopup: true}
    	), 500