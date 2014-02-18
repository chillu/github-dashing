require 'json'
require 'time'
require 'dashing'
require 'octokit'
require 'active_support/core_ext'
require File.expand_path('../../lib/helper', __FILE__)
require File.expand_path('../../lib/bigquery_backend', __FILE__)
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
		# 'commits_additions'=>0.005,
		# 'commits_deletions'=>0.005,
		'commits'=>20
	}
	weighting = weighting.merge(
		ENV['LEADERBOARD_WEIGHTING'].split(',').inject({}) {|c,pair|c.merge Hash[*pair.split('=')]}
	) if ENV['LEADERBOARD_WEIGHTING']

	days_interval = 30
	date_since = days_interval.days.ago.utc
	date_until = Time.now.to_datetime
	actors = leaderboard.get(
		:period=>'month', 
		:orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']), 
		:repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
		:since=>date_since, # not using ENV because 'since' is likely higher than needed
		:weighting=>weighting,
		:limit=>15,
		:date_interval=>days_interval.days
	)
	
	rows = actors.map do |actor|
		actor_github_info = backend.user(actor[0])

		if actor_github_info['avatar_url']
			actor_icon = actor_github_info['avatar_url'] + "&s=32"
		elsif actor_github_info['email']
			actor_icon = "http://www.gravatar.com/avatar/" + Digest::MD5.hexdigest(actor_github_info['email'].downcase) + "?s=24"
		else
			actor_icon = ''
		end

		trend = GithubDashing::Helper.trend_percentage(
			actor[1]['previous_score'], 
			actor[1]['current_score']
		)

		{
			nickname: actor[0],
			fullname: actor_github_info['name'],
			icon: actor_icon,
			current_score: actor[1]['current_score'],
			current_score_desc: 'Score from current %d days period. %s' % [days_interval, actor[1]['current_desc']],
			previous_score: actor[1]['previous_score'],
			previous_score_desc: 'Score from previous %d days period. %s' % [days_interval, actor[1]['previous_desc']],
			trend: trend,
			trend_class: GithubDashing::Helper.trend_class(trend),
			github: actor_github_info
		}
	end if actors

	send_event('leaderboard', {
		rows: rows,
		date_since: date_since.strftime("#{date_since.day.ordinalize} %b"),
		date_until: date_until.strftime("#{date_until.day.ordinalize} %b"),
	})
end