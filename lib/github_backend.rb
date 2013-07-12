require 'octokit'
require 'ostruct'

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

	def pull_request_count(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		result = {}
		offset = self.period_to_offset(opts.period)
		self.get_repos(opts).each do |repo|
			['open','closed'].each do |state|
				pulls = @client.pulls(repo, {:since => opts.since,:state => state})
				pulls_by_period = pulls.group_by do |pull| 
					pull.created_at.to_s[0,offset]
				end
				pulls_by_period.each_with_index do |(period,pulls_in_period),i|
					result[period] = Hash.new(0) unless result[period]
					result[period][:count] += pulls_in_period.count
				end
			end
		end
		
		return result.sort
	end

	# Caution: NOT the commit count, only the latest commit in this particular
	# push is tracked through the githubarchive normalization
	def push_count_by_author(opts)
		# TODO
	end

	def comment_count_by_author(opts)
		# TODO
	end

	def pull_request_count_by_author(opts)
		# TODO
	end

	def issue_count_by_author(opts)
		# TODO
	end

	def issue_count_by_status(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		result = {}
		offset = self.period_to_offset(opts.period)
		self.get_repos(opts).each do |repo|
			['open','closed'].each do |state|
				issues = @client.issues(repo, {:since => opts.since,:state => state})
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