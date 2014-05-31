require 'json'
require 'time'
require 'activesupport/core_ext'
require 'ostruct'
require 'logger'
require 'octokit'

class Leaderboard

	attr_accessor :backend, :logger

	def initialize(backend)
		@backend = backend
		@logger = Logger.new(STDOUT)
		@logger.level = Logger::DEBUG unless ENV['RACK_ENV'] == 'production'
	end


	def get(opts=nil)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct

		date_since = opts.since || 3.months.ago.to_datetime
		date_until = opts.date_until || Time.now.to_datetime
		date_interval = opts.date_interval || 30.days
		date_since = Time.at(date_until.to_i - date_interval*2)
		
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
			next if event.datetime < date_since or event.datetime > date_until

			author = event.key
			period = (event.datetime > Time.at(date_until.to_i - date_interval)) ? 'current' : 'previous'
			events_by_actor[author] ||= {'periods' => {}}
			events_by_actor[author]['periods'][period] ||= Hash.new(0)
			events_by_actor[author]['periods'][period][event.type] += event.value || 1
		end
		
		# Add score for each period
		actors_scored = {}
		events_by_actor.each do |actor,actor_data|
			actor_data['periods'].each do |period,period_data|
				desc = []
				period_data['score'] = period_data.inject(0) do |c,(k,v)|
					weight = opts.weighting.has_key?(k) ? opts.weighting[k] : 0
					desc.push "(#{k}=#{v} * weight=#{weight})" if v and v.to_i > 0
					c += (v.to_f * weight.to_f).to_i
				end
				period_data['desc'] = desc.join(' + ')
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
		actors_scored = actors_scored.
			select {|k,v|v['current_score'].to_i > 0 || v['previous_score'].to_i > 0}.
			sort_by {|k,v|[v['current_score'],v['previoius_score']]}.
			reverse

		# Limit to top list
		actors_scored[0,opts.limit || 10]
	end


end