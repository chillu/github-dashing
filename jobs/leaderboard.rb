require 'json'
require 'time'
require 'dashing'

SCHEDULER.every '1h', :first_in => '15s' do |job|
	actors = settings.big_query_backend.leaderboard(
		:period=>'month', 
		:orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']), 
		:repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
		:since=>ENV['SINCE'],
		:limit=>20
	)
	
	rows = actors.map do |actor|
		{
			'cols' => [
				{'value' => actor[0]}, 
				# actor[1]['previous_score'],
				{'value' => actor[1]['current_score'], 'title' => actor[1]['current_desc']},
			]
		}
	end

	send_event('leaderboard', {
		rows: rows
	})
end