require 'json'
require 'time'
require 'dashing'
require 'octokit'
require 'active_support/core_ext'
require File.expand_path('../../lib/helper', __FILE__)
require File.expand_path('../../lib/big_query_backend', __FILE__)
require File.expand_path('../../lib/leaderboard', __FILE__)
require File.expand_path('../../lib/bigquery_leaderboard', __FILE__)

SCHEDULER.every '1h', :first_in => 0 do |job|
	if ENV['GOOGLE_KEY']
		backend = BigQueryBackend.new(
			:keystr=>ENV['GOOGLE_KEY'],
			:secret=>ENV['GOOGLE_SECRET'],
			:issuer=>ENV['GOOGLE_ISSUER'],
			:project_id=>ENV['GOOGLE_PROJECT_ID'],
		)
		github_client = Octokit::Client.new(:login => ENV['GITHUB_LOGIN'], :oauth_token => ENV['GITHUB_OAUTH_TOKEN'])
		leaderboard = BigQueryLeaderboard.new(backend, github_client)
	else
		backend = GithubBackend.new()
		leaderboard = Leaderboard.new(backend, github_client)
	end

	weighting = {
		'issues_opened'=>5,
		'issues_closed'=>5,
		'pulls_opened'=>10,
		'pulls_closed'=>5,
		'pulls_comments'=>1,
		'issues_comments'=>1,
		'commits_comments'=>1,
		'commits_additions'=>0.05,
		'commits_deletions'=>0.05,
		'commits'=>20
	}
	weighting = weighting.merge(
		ENV['LEADERBOARD_WEIGHTING'].split(',').inject({}) {|c,pair|c.merge Hash[*pair.split('=')]}
	) if ENV['LEADERBOARD_WEIGHTING']

	actors = leaderboard.get(
		:period=>'month', 
		:orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']), 
		:repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
		:since=>1.month.ago.beginning_of_month.utc.to_s, # not using ENV because 'since' is likely higher than needed
		:weighting=>weighting,
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
					'value' => '(%s)' % actor[1]['previous_score'].to_i, 
					'title' => 'Score from previous month',
					'class' => 'col-previous-score',
				},
				{
					'value' => trend, 
					'title' => '',
					'arrow' => 'icon-arrow-' + GithubDashing::Helper.trend_class(trend),
					'class' => 'col-trend trend-' + GithubDashing::Helper.trend_class(trend),
				}
			]
		}
	end if actors

	send_event('leaderboard', {
		moreinfo: 'Activity score based on issues, pulls and comments. Compares current month to last month.',
		rows: rows,
		headers: [
			{'value' => 'Name'},
			{'value' => 'Score'},
			{'value' => 'Trend'}
		]
	})
end