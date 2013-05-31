require 'json'
require 'time'
require 'dashing'
require 'octokit'
require 'active_support/core_ext'
require File.expand_path('../../lib/helper', __FILE__)
require File.expand_path('../../lib/big_query_backend', __FILE__)
require File.expand_path('../../lib/leaderboard', __FILE__)

SCHEDULER.every '1h', :first_in => 0 do |job|
	bigquery_backend = BigQueryBackend.new(
		:keystr=>ENV['GOOGLE_KEY'],
		:secret=>ENV['GOOGLE_SECRET'],
		:issuer=>ENV['GOOGLE_ISSUER'],
		:project_id=>ENV['GOOGLE_PROJECT_ID'],
	)
	github_client = Octokit::Client.new(:login => ENV['GITHUB_LOGIN'], :oauth_token => ENV['GITHUB_OAUTH_TOKEN'])

	leaderboard = Leaderboard.new(bigquery_backend, github_client)
	actors = leaderboard.get(
		:period=>'month', 
		:orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']), 
		:repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
		:since=>1.month.ago.beginning_of_month.utc.to_s, # not using ENV because 'since' is likely higher than needed
		:weighting=>ENV['LEADERBOARD_WEIGHTING'].split(',').inject({}) {|c,pair|c.merge Hash[*pair.split('=')]},
		:limit=>15
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
				{
					'value' => actor[1]['current_score'], 
					'title' => actor[1]['current_desc'],
					'class' => 'col-score value',
				},
				{
					'value' => '(%s)' % actor[1]['previous_score'], 
					'title' => 'Score from previous month',
					'class' => 'col-previous-score',
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