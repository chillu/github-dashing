require 'json'
require 'ostruct'
require 'logger'
require 'octokit'

class Leaderboard

	attr_accessor :backend, :logger, :github_client

	def initialize(backend, github_client=nil)
		@backend = backend
		@github_client = github_client
		@logger = Logger.new(STDOUT)
		@logger.level = Logger::DEBUG unless ENV['RACK_ENV'] == 'production'
	end


	def get(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct

		contrib_data = @backend.contributor_stats_by_author(opts) || {}
		issue_comment_data = @backend.issue_comment_count_by_author(opts) || {}
		pull_comment_data = @backend.pull_comment_count_by_author(opts) || {}
		issue_data = @backend.issue_count_by_author(opts) || {}
		pull_data = @backend.pull_count_by_author(opts) || {}
		
		# TODO Find out why some commits don't have this data
		# commits.select! {|commit|commit['author']['login'] rescue nil}
		# commits_by_actor = commits.group_by {|commit|commit['author']['login']}

		# Poor man's testing
		# File.open('spec/fixtures/contributor_data.json','w') {|file|file.write(contributor_data.to_json)}
		# File.open('spec/fixtures/pull_request_count_by_author.json','w') {|file|file.write(pull_request_data.to_json)}
		# File.open('spec/fixtures/comment_count_by_author.json','w') {|file|file.write(comment_data.to_json)}
		# File.open('spec/fixtures/issue_count_by_author.json','w') {|file|file.write(issue_data.to_json)}
		# File.open('spec/fixtures/commit_count_by_author.json','w') {|file|file.write(comment_data.to_json)}
		# contributor_data = JSON.parse(File.read('spec/fixtures/contributor_data.json'))
		# pull_request_data = JSON.parse(File.read('spec/fixtures/pull_request_count_by_author.json'))
		# comment_data = JSON.parse(File.read('spec/fixtures/comment_count_by_author.json'))
		# issue_data = JSON.parse(File.read('spec/fixtures/issue_count_by_author.json'))
		# commit_data = JSON.parse(File.read('spec/fixtures/commit_count_by_author.json'))

		# TODO This should be running as a single aggregate query in BigQuery,
		# but my SQL foo isn't strong enough.
		
		# Collect full keys so we don't have missing ones
		all_actors = []
		all_actors += issue_data.keys
		all_actors += issue_comment_data.keys
		all_actors += pull_comment_data.keys
		all_actors += contrib_data.keys
		all_actors += pull_data.keys
		all_actors.delete_if {|x| x == nil}
		all_actors = all_actors.uniq.sort

		all_periods = []
		[contrib_data,issue_data,pull_comment_data,issue_comment_data,pull_data].each do |data|
			all_periods += data.inject([]) {|all,(k,row)|all += row.keys}	
		end
		all_periods = all_periods.uniq.sort

		actors_by_period = all_actors.inject({}) do |v,actor|
			seed = all_periods.inject({}) do |v,period|
				v.update period => {
					'issues_opened' => 0,
					# 'issues_closed' => 0,
					'pulls_opened' => 0,
					# 'pull_requests_closed' => 0,
					'pulls_comments' => 0,
					'issues_comments' => 0,
					'commits_comments' => 0,
					'commits' => 0,
					'commits_additions' => 0,
					'commits_deletions' => 0
				}
			end
			v.update actor => {'periods' => seed}
		end
		
		# Combine results
		contrib_data.each_with_index do |(actor,periods)|
			periods.each_with_index do |(period,data)|
				actors_by_period[actor]['periods'][period]['commits'] = data[:commits]
				actors_by_period[actor]['periods'][period]['commits_additions'] = data[:additions]
				actors_by_period[actor]['periods'][period]['commits_deletions'] = data[:deletions]
			end
		end
		pull_comment_data.each_with_index do |(actor,periods)|
			periods.each_with_index do |(period,data)|
				actors_by_period[actor]['periods'][period]['pulls_comments'] = data[:count]
			end
		end
		pull_data.each_with_index do |(actor,periods)|
			periods.each_with_index do |(period,data)|
				actors_by_period[actor]['periods'][period]['pulls_opened'] = data[:count]
			end
		end
		issue_comment_data.each_with_index do |(actor,periods)|
			periods.each_with_index do |(period,data)|
				actors_by_period[actor]['periods'][period]['issues_comments'] = data[:count]
			end
		end
		issue_data.each_with_index do |(actor,periods)|
			periods.each_with_index do |(period,data)|
				actors_by_period[actor]['periods'][period]['issues_opened'] = data[:count]
			end
		end
		
		# Add score for each period
		actors_by_period.each do |actor,actor_data|
			actor_data['periods'].each do |period,period_data|
				desc = []
				period_data['score'] = period_data.inject(0) do |c,(k,v)|
					weight = opts.weighting.has_key?(k) ? opts.weighting[k] : 0
					desc.push "(#{k}=#{v} * weight=#{weight})" if v and v.to_i > 0
					c += (v.to_f * weight.to_f).to_i
				end
				period_data['desc'] = desc.join(' + ')
			end
			actors_by_period[actor]['current_score'] = actor_data['periods'][all_periods[-1]]['score']
			actors_by_period[actor]['current_desc'] = actor_data['periods'][all_periods[-1]]['desc']
			actors_by_period[actor]['previous_score'] = all_periods.length > 1 ? actor_data['periods'][all_periods[-2]]['score'] : 0
		end

		# Sort by score (converts to Array)
		actors_by_period = actors_by_period.
			select {|k,v|v['current_score'].to_i > 0 || v['previous_score'].to_i > 0}.
			sort_by {|k,v|v['current_score']}.
			reverse

		# Limit to top list
		actors_by_period[0,opts.limit || 10]
	end


end