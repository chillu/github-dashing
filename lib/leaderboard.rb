require 'json'
require 'ostruct'
require 'octokit'

class Leaderboard

	attr_accessor :bigquery_backend, :logger, :github_client

	def initialize(bigquery_backend, github_client=nil)
		@bigquery_backend = bigquery_backend
		@github_client = github_client
		@logger = Logger.new(STDOUT)
		@logger.level = Logger::DEBUG unless ENV['RACK_ENV'] == 'production'
	end


	def get(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct

		pull_request_data = @bigquery_backend.pull_request_count_by_author(opts).data
		comment_data = @bigquery_backend.comment_count_by_author(opts).data
		issue_data = @bigquery_backend.issue_count_by_author(opts).data
		
		commits = self.get_commits(
			Time.parse(opts[:since]), 
			opts[:repos].to_a + self.get_repos_by_orgas(opts[:orgas]).to_a
		)

		# TODO Find out why some commits don't have this data
		commits.select! {|commit|commit['author']['login'] rescue nil}
		commits_by_actor = commits.group_by {|commit|commit['author']['login']}

		# Poor man's testing
		# File.open('spec/fixtures/pull_request_count_by_author.json','w') {|file|file.write(pull_request_data.to_json)}
		# File.open('spec/fixtures/comment_count_by_author.json','w') {|file|file.write(comment_data.to_json)}
		# File.open('spec/fixtures/issue_count_by_author.json','w') {|file|file.write(issue_data.to_json)}
		# File.open('spec/fixtures/commit_count_by_author.json','w') {|file|file.write(comment_data.to_json)}
		# pull_request_data = JSON.parse(File.read('spec/fixtures/pull_request_count_by_author.json'))
		# comment_data = JSON.parse(File.read('spec/fixtures/comment_count_by_author.json'))
		# issue_data = JSON.parse(File.read('spec/fixtures/issue_count_by_author.json'))
		# commit_data = JSON.parse(File.read('spec/fixtures/commit_count_by_author.json'))

		# TODO This should be running as a single aggregate query in BigQuery,
		# but my SQL foo isn't strong enough.
		
		# Collect full keys so we don't have missing ones

		all_actors = []
		all_actors += pull_request_data['rows'].map{|row|row['f'][0]['v']}
		all_actors += comment_data['rows'].map{|row|row['f'][0]['v']}
		all_actors += issue_data['rows'].map{|row|row['f'][0]['v']}
		all_actors += commits.map{|commit|commit['author']['login']}
		all_actors.delete_if {|x| x == nil}
		all_actors.uniq!.sort!

		all_periods = []
		all_periods += pull_request_data['rows'].map{|row|row['f'][1]['v']}
		all_periods += comment_data['rows'].map{|row|row['f'][1]['v']}
		all_periods += issue_data['rows'].map{|row|row['f'][1]['v']}
		all_periods += commits.map{|commit|Time.parse(commit['commit']['author']['date']).strftime('%Y-%m')}
		all_periods.uniq!.sort!

		actors_by_period = all_actors.inject({}) do |v,actor|
			seed = all_periods.inject({}) do |v,period|
				v.update period => {
					'issues_opened' => 0,
					'issues_closed' => 0,
					'pull_requests_opened' => 0,
					'pull_requests_closed' => 0,
					'pull_request_comments' => 0,
					'issue_comments' => 0,
					'commit_comments' => 0,
					'commits' => 0
				}
			end
			v.update actor => {'periods' => seed}
		end
		
		# Combine results
		pull_request_data['rows'].each do |row|
			actor = row['f'][0]['v']
			next unless actor
			period = row['f'][1]['v']
			actors_by_period[actor]['periods'][period]['pull_requests_opened'] = row['f'][2]['v']
		end
		comment_data['rows'].each do |row|
			actor = row['f'][0]['v']
			next unless actor
			period = row['f'][1]['v']
			actors_by_period[actor]['periods'][period]['commit_comments'] = row['f'][2]['v']
			actors_by_period[actor]['periods'][period]['pull_request_comments'] = row['f'][3]['v']
			actors_by_period[actor]['periods'][period]['issue_comments'] = row['f'][4]['v']
		end
		issue_data['rows'].each do |row|
			actor = row['f'][0]['v']
			next unless actor
			period = row['f'][1]['v']
			actors_by_period[actor]['periods'][period]['issues_opened'] = row['f'][2]['v']
			actors_by_period[actor]['periods'][period]['issues_closed'] = row['f'][3]['v']
		end
		commits_by_actor.each do |actor,commits_for_actor|
			commits_by_period = commits_for_actor.group_by{|commit|Time.parse(commit['commit']['author']['date']).strftime('%Y-%m')}
			commits_by_period.each do |period,commits_for_period|
				puts period
				puts commits_for_period.to_s
				actors_by_period[actor]['periods'][period]['commits'] = commits_for_period.length
			end
		end
		
		# Add score for each period
		actors_by_period.each do |actor,actor_data|
			actor_data['periods'].each do |period,period_data|
				desc = []
				period_data['score'] = period_data.inject(0) do |c,(k,v)|
					weight = opts.weighting.has_key?(k) ? opts.weighting[k] : 0
					desc.push "(#{k}=#{v} * weight=#{weight})" if v and v.to_i > 0
					c += v.to_f * weight.to_f
				end
				period_data['desc'] = desc.join(' + ')
			end
			actors_by_period[actor]['current_score'] = actor_data['periods'][all_periods[-1]]['score']
			actors_by_period[actor]['current_desc'] = actor_data['periods'][all_periods[-1]]['desc']
			actors_by_period[actor]['previous_score'] = all_periods.length > 1 ? actor_data['periods'][all_periods[-2]]['score'] : 0
		end

		# Sort by score (converts to Array)
		actors_by_period = actors_by_period.sort_by {|k,v|v['current_score']}.reverse

		# Limit to top list
		actors_by_period = actors_by_period[0,opts.limit || 10]

		puts actors_by_period
		return actors_by_period
	end

	# since - Time
	# repos - Hash with repo slugs (as String)
	# 
	# Returns an Array of commits across all repositories.
	def get_commits(since, repo_slugs=null)
		repo_slugs.inject([]) do |commits,repo_slug|
			@logger.debug 'Getting commits for %s' % repo_slug
			commits_for_repo = @github_client.commits_since(repo_slug, since.utc.to_s)
			commits.concat(commits_for_repo) if commits.length
		end
	end

	# Returns a Hash of repo names
	def get_repos_by_orgas(orgas)
		orgas.inject([]) do |c,orga|
			@logger.debug 'Getting repositories for %s' % orga
			c.concat(@github_client.repositories(orga).collect{|repo|repo['full_name']})
		end
	end

end