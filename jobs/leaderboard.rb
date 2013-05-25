require 'json'
require 'time'
require 'dashing'
require File.expand_path('../../lib/helper', __FILE__)

SCHEDULER.every '1h', :first_in => 0 do |job|
	backend = BigQueryBackend.new(
		:keystr=>ENV['GOOGLE_KEY'],
		:secret=>ENV['GOOGLE_SECRET'],
		:issuer=>ENV['GOOGLE_ISSUER'],
		:project_id=>ENV['GOOGLE_PROJECT_ID'],
	)
	weighting = ENV['LEADERBOARD_WEIGHTING'].split(',').inject({}) {|c,pair|c.merge Hash[*pair.split('=')]}
	actors = backend.leaderboard(
		:period=>'month', 
		:orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']), 
		:repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
		:since=>ENV['SINCE'],
		:weighting=>weighting,
		:limit=>20
	)
	
	rows = actors.map do |actor|
		trend = GithubDashing::Helper.trend_percentage_by_month(
			actor[1]['previous_score'], 
			actor[1]['current_score']
		)
		{
			'cols' => [
				{
					'value' => actor[0],
					'title' => '',
					'class' => 'col-name',
				}, 
				# actor[1]['previous_score'],
				{
					'value' => actor[1]['current_score'], 
					'title' => actor[1]['current_desc'],
					'class' => 'col-score value',
				},
				{
					'value' => trend, 
					'title' => '',
					'arrow' => trend.to_f > 0 ? 'icon-arrow-up' : 'icon-arrow-down',
					'class' => 'col-trend',
				}
			]
		}
	end

	send_event('leaderboard', {
		rows: rows,
		headers: [
			{'value' => 'Name'},
			{'value' => 'Score'},
			{'value' => 'Trend'}
		]
	})
end