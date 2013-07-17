require 'time'
require 'octokit'
require 'ostruct'
require 'json'
require 'active_support/core_ext'

class GithubBackend

	attr_accessor :client, :logger

	def initialize(args={})
		@logger = Logger.new(STDOUT)
		@logger.level = Logger::DEBUG unless ENV['RACK_ENV'] == 'production'
		
		# Verbose logging in Octokit
		Octokit.configure do |config|
			config.faraday_config do |faraday| 
				faraday.response :logger unless ENV['RACK_ENV'] == 'production'
			end
		end

		@client = Octokit::Client.new(
			:login => ENV['GITHUB_LOGIN'], 
			:oauth_token => ENV['GITHUB_OAUTH_TOKEN']
		)
		
	end

	def contributor_stats_by_author(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		result = {}
		offset = self.period_to_offset(opts.period)
		self.get_repos(opts).each do |repo|
			['open','closed'].each do |state|
				# Can't limit timeframe
				stats_by_author = @client.contributors_stats(repo)
				stats_by_author.each do |stats_for_author|
					author = stats_for_author.author.login
					result[author] = {} unless result[author]
					stats_by_period = stats_for_author.weeks.
						select {|stat|Time.at(stat.w) > opts.since.to_datetime}.
						group_by {|stat|Time.at(stat.w).to_s[0,offset]}
					stats_by_period.each_with_index do |(period,weeks),i|
						weeks.each do |week|
							result[author][period] = Hash.new(0) unless result[author][period]
							result[author][period][:additions] += week.a
							result[author][period][:deletions] += week.d
							result[author][period][:commits] += week.c
						end
					end
				end
			end
		end
		
		return result
	rescue Octokit::Error
		false
	end

	def issue_comment_count_by_author(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		result = {}
		offset = self.period_to_offset(opts.period)
		self.get_repos(opts).each do |repo|
			comments = @client.issues_comments(repo, {:since => opts.since})
			comments = comments.select {|comment|comment.created_at.to_datetime > opts.since.to_datetime}
			comments_by_author = comments.group_by {|comment| comment.user.login}
			comments_by_author.each_with_index do |(author,comments_for_author),i|
				result[author] = {} unless result[author]
				comments_by_period = comments_for_author.group_by {|comment|comment.created_at.to_s[0,offset]}
				comments_by_period.each_with_index do |(period,comments),i|
					result[author][period] = Hash.new(0) unless result[author][period]
					result[author][period][:count] += comments.count
				end
			end
		end
		
		return result
	rescue Octokit::Error
		false
	end

	def pull_count_by_author(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		result = {}
		offset = self.period_to_offset(opts.period)
		self.get_repos(opts).each do |repo|
			['open','closed'].each do |state|
				pulls = @client.pulls(repo, {:since => opts.since, :state => state})
				pulls = pulls.select {|pull|pull.created_at.to_datetime > opts.since.to_datetime}
				pulls_by_author = pulls.group_by {|pull| pull.user.login}
				pulls_by_author.each_with_index do |(author,pulls_for_author),i|
					result[author] = {} unless result[author]
					pulls_by_period = pulls_for_author.group_by {|pull|pull.created_at.to_s[0,offset]}
					pulls_by_period.each_with_index do |(period,pulls),i|
						result[author][period] = Hash.new(0) unless result[author][period]
						result[author][period][:count] += pulls.count
					end
				end
			end
		end
		
		return result
	rescue Octokit::Error
		false
	end

	def pull_comment_count_by_author(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		result = {}
		offset = self.period_to_offset(opts.period)
		self.get_repos(opts).each do |repo|
			comments = @client.pulls_comments(repo, {:since => opts.since})
			comments = comments.select {|comment|comment.created_at.to_datetime > opts.since.to_datetime}
			comments_by_author = comments.group_by {|comment| comment.user.login}
			comments_by_author.each_with_index do |(author,comments_for_author),i|
				result[author] = {} unless result[author]
				comments_by_period = comments_for_author.group_by {|comment|comment.created_at.to_s[0,offset]}
				comments_by_period.each_with_index do |(period,comments),i|
					result[author][period] = Hash.new(0) unless result[author][period]
					result[author][period][:count] += comments.count
				end
			end
		end
		
		return result
	rescue Octokit::Error
		false
	end

	def issue_count_by_author(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		result = {}
		offset = self.period_to_offset(opts.period)
		self.get_repos(opts).each do |repo|
			['open','closed'].each do |state|
				issues = @client.issues(repo, {:since => opts.since,:state => state})
				issues = issues.select {|issue|issue.created_at.to_datetime > opts.since.to_datetime}
				issues_by_author = issues.group_by {|issue| issue.user.login}
				issues_by_author.each_with_index do |(author,issues_for_author),i|
					result[author] = {} unless result[author]
					issues_by_period = issues_for_author.group_by {|issue|issue.created_at.to_s[0,offset]}
					issues_by_period.each_with_index do |(period,issues),i|
						result[author][period] = Hash.new(0) unless result[author][period]
						result[author][period][:count] += issues.count
					end
				end
			end
		end
		
		return result
	rescue Octokit::Error
		false
	end

	def issue_count_by_status(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		result = {}
		offset = self.period_to_offset(opts.period)
		self.get_repos(opts).each do |repo|
			['open','closed'].each do |state|
				issues = @client.issues(repo, {:since => opts.since,:state => state})
				issues = issues.select {|issue|issue.created_at.to_datetime > opts.since.to_datetime}
				issues_by_period = issues.group_by do |issue| 
					issue.state == 'open' ? issue.created_at.to_s[0,offset] : issue.closed_at.to_s[0,offset]
				end
				issues_by_period.each_with_index do |(period,issues_in_period),i|
					result[period] = Hash.new(0) unless result[period]
					result[period]["count_#{state}".to_sym] += issues_in_period.count
				end
			end
		end
		
		return result.sort
	rescue Octokit::Error
		false
	end

	def pull_count_by_status(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		result = {}
		offset = self.period_to_offset(opts.period)
		self.get_repos(opts).each do |repo|
			['open','closed'].each do |state|
				pulls = @client.pulls(repo, {:since => opts.since,:state => state})
				pulls = pulls.select {|pull|pull.created_at.to_datetime > opts.since.to_datetime}
				pulls_by_period = pulls.group_by do |pull| 
					pull.created_at.to_s[0,offset]
				end
				pulls_by_period.each_with_index do |(period,pulls_in_period),i|
					result[period] = Hash.new(0) unless result[period]
					result[period]["count_#{state}".to_sym] += pulls_in_period.count
				end
			end
		end
		
		return result.sort
	rescue Octokit::Error
		false
	end

	def repo_stats(opts)
		# TODO
	end

	def get_repos(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		repos = []
		if opts.repos != nil
			repos = repos.concat(opts.repos)
		end
		if opts.orgas != nil
			opts.orgas.each do |orga|
				repos = repos.concat(@client.org_repos(orga, {:type => 'owner'}).map {|repo|repo.full_name})
			end
		end

		return repos
	rescue Octokit::Error
		false
	end

	def period_to_offset(period)
		case period
		when 'day'
			offset = 10
		when 'month'
			offset = 7
		when 'year'
			offset = 4
		end
	end

end