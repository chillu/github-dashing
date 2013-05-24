require 'json'
require 'time'
require 'dashing'

SCHEDULER.every '1h', :first_in => '15s' do |job|
	actors = settings.big_query_backend.leaderboard(
		:period=>'month', 
		:orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']), 
		:repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
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