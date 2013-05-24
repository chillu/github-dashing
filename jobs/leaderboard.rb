require 'json'
require 'time'
require 'dashing'

SCHEDULER.every '1h', :first_in => 0 do |job|
	actors = settings.big_query_backend.leaderboard(
		:period=>'month', 
		:orgas=>ENV['ORGAS'].split(','), 
		:repos=>ENV['REPOS'].split(','),
		:limit=>20
	)
	
	rows = actors.map do |actor|
		{
			'values' => [
				actor[0], 
				actor[1]['previous_score'],
				actor[1]['current_score'],
				# actor[1]['current_desc'],
			]
		}
	end

	send_event('leaderboard', {
		rows: rows
	})
end