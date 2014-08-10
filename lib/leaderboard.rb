require 'json'
require 'time'
require 'active_support/core_ext'
require 'ostruct'
require 'logger'
require 'octokit'

# Weighting on additions and deletions are capped to avoid large refactorings or library
# additions unfairly influencing the overall score. Github only provides
# "additions by author by week", so there's no way to exclude thirdparty folders.
# So if you add a 10,000 LOC library, it'll still only count as commits_additions_max points.
class Leaderboard

	attr_accessor :backend, :logger

	def initialize(backend)
		@backend = backend
		@logger = Logger.new(STDOUT)
		@logger.level = Logger::DEBUG unless ENV['RACK_ENV'] == 'production'
	end

	# Options
	# - orgas: (Array) github organization names
	# - repos: (Array) github repository names
	# - since: (Datetime)
	# - weighting: (Hash) Event names to a numerical multiplier. Set to nil to disable weighting
	# - edits_weighting: (Hash) Constraints for LOC counts.
	#   Required keys: commits_additions_max, commits_additions_loc_threshold, 
	#   commits_deletions_max, commits_deletions_loc_threshold
	# - limit: (Integer) Maximum number of users to show in board
	# - days_interval: (Integer) Number of days to check for a period
	# - event_titles: (Hash) Event names to titles used in detail descriptions on the widget
	# - skip_orga_members: (Array) Github organization names for which to exclude members.
	def get(opts={})
		days_interval = 30
		default_opts = {
			:days_interval => days_interval,
			:date_until => Time.now.to_datetime,
			:limit => 15,
			:edits_weighting => {
				'commits_additions_max'=>100,
				'commits_additions_loc_threshold'=>1000,
				'commits_deletions_max'=>100,
				'commits_deletions_loc_threshold'=>1000,
			},
			:weighting => {
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
			},
			:event_titles => {
				'commits' => 'commits',
				'issues_comments' => 'issue comments',
				'pulls_comments' => 'pull request comments',
				'issues_comments' => 'issue comments',
				'issues_opened' => 'opened issues',
				'issues_closed' => 'closed issues',
				'pulls_closed' => 'closed pull requests',
				'commits_additions' => 'lines of code added',
				'commits_deletions' => 'lines of code deleted',
			}
		}
		opts = OpenStruct.new(default_opts.merge(opts))

		# Comparing current with last period, so need twice the interval
		date_since = Time.at(opts.date_until.to_i - opts.days_interval.days*2)

		events = GithubDashing::EventCollection.new(
			@backend.contributor_stats_by_author(opts).to_a +
			@backend.issue_comment_count_by_author(opts).to_a +
			@backend.pull_comment_count_by_author(opts).to_a +
			@backend.issue_count_by_author(opts).to_a +
			@backend.pull_count_by_author(opts).to_a
		)
		# TODO Pretty much everything below would be better expressed in 
		# SQL with 1/4th the lines of code

		# Group events by author, then by period
		events_by_actor = {}
		events.each do |event|
			# Filter by date range
			next if event.datetime < date_since or event.datetime > opts.date_until

			author = event.key
			period = (event.datetime > Time.at(opts.date_until.to_i - opts.days_interval)) ? 'current' : 'previous'
			events_by_actor[author] ||= {'periods' => {}}
			events_by_actor[author]['periods'][period] ||= Hash.new(0)
			events_by_actor[author]['periods'][period][event.type] += event.value || 1
		end
		
		# Add score for each period
		actors_scored = {}
		events_by_actor.each do |actor,actor_data|
			is_from_org = opts.skip_orga_members.select {|org|@backend.organization_member?(org, actor)}.length > 0
			next if is_from_org

			actor_data['periods'].each do |period,period_data|
				desc = []
				blacklist = ['commits_additions','commits_deletions']

				# Sum up weighted scores for each criteria, e.g. issues_opened, issues_closed
				period_data['score'] = period_data
					.reject do |k,v|
						blacklist.include?(k)
					end
					.inject(0) do |c,(k,v)|
						weight = opts.weighting.has_key?(k) ? opts.weighting[k] : 0
						event_title = opts.event_titles.has_key?(k) ? opts.event_titles[k] : k
						desc.push "#{v} #{event_title} * #{weight} points" if v and v.to_i > 0
						c += (v.to_f * weight.to_f).to_i
					end

				# Sum up weighted and capped scores for lines of code added and deleted
				['additions','deletions'].each do |type|
					if period_data.has_key?("commits_#{type}") and opts.edits_weighting and opts.edits_weighting["commits_#{type}_max"]
						loc_actual = period_data["commits_#{type}"]
						loc_threshold = opts.edits_weighting["commits_#{type}_loc_threshold"]
						loc_counted = [loc_actual,loc_threshold].min
						score_max = opts.edits_weighting["commits_#{type}_max"]
						score_actual = (score_max * (loc_counted.to_f/loc_threshold.to_f)).to_i
						event_title = opts.event_titles.has_key?("commits_#{type}") ? opts.event_titles["commits_#{type}"] : "commits_#{type}"
						desc.push(
							"#{event_title} #{score_actual} points (<em>actual: #{loc_actual}, " +
							"threshold: #{loc_threshold}, counted: #{loc_counted}, " +
							"max points: #{score_max}</em>)"
						)
						period_data['score'] += score_actual
					end
				end

				period_data['desc'] = desc.join('<br>+ ')
			end
			actors_scored[actor] = {
				'current_score' => 0,
				'current_desc' => 0,
				'previous_score' => 0,
			}
			if actor_data['periods'].has_key?('current')
				actors_scored[actor]['current_score'] = actor_data['periods']['current']['score']
				actors_scored[actor]['current_desc'] = actor_data['periods']['current']['desc']
			end
			if actor_data['periods'].has_key?('previous')
				actors_scored[actor]['previous_score'] = actor_data['periods']['previous']['score']
				actors_scored[actor]['previous_desc'] = actor_data['periods']['previous']['desc']
			end
		end

		# Filter out empties, sort by current score, then previous score (converts to Array)
		actors_scored = actors_scored
			.select {|k,v|v['current_score'].to_i > 0 || v['previous_score'].to_i > 0}
			.sort_by {|k,v|[v['current_score'],v['previoius_score']]}
			.reverse

		# Limit to top list
		actors_scored[0,opts.limit || 10]
	end

end