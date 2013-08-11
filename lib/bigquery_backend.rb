require 'google/api_client'
require 'ostruct'

# Interacts with the Google BigQuery API. 
# Handles authentication and API discovery.
# 
# CAUTION: QUERIES A BILLABLE SERVICE
# Due to the size of the githubarchive.org dataset (70GB+),
# even simple queries will consume at least 6GB of your query quota.
# Given the free BigQuery quota is just 100GB, this doesn't get you very far.
class BigQueryBackend

	attr_accessor :client, :keyfile, :keystr, :secret, :issuer, :project_id
	attr_reader :api, :is_authenticated

	def initialize(args={})
		@client = Google::APIClient.new(
			:application_name => 'Github Dashing BigqueryBackend',
			:application_version => '0.1'
		)
		@client.logger.level = Logger::DEBUG unless ENV['RACK_ENV'] == 'production'
		
		args.each do |k,v|
      instance_variable_set("@#{k}", v) unless v.nil?
    end
	end

	def query(query)
		self.authenticate
		
		result = @client.execute(
		  :api_method => @api.jobs.query,
		  :parameters => {'projectId' => @project_id},
		  # Set higher timeout so we don't have to deal with async jobs
		  :body_object => {'query' => query, 'timeoutMs' => 120000}
		)

		throw "Query error for #{query}: #{result.error_message}" if result.error?

		# TODO Implement async job retrieval and callbacks
		throw "Query timeout for #{query}" if !result.data['jobComplete']

		return result
	end

	def authenticate()
			if @keyfile
				key = Google::APIClient::KeyUtils.load_from_pkcs12(File.open(@keyfile), @secret)
			elsif @keystr
				# See http://ar.zu.my/how-to-store-private-key-files-in-heroku/
			key = OpenSSL::PKey::RSA.new @keystr, @secret
			else
				throw 'No valid key found, define either @keyfile or @keystr'
			end
			
			@api = @client.discovered_api('bigquery', "v2")
			@client.authorization = Signet::OAuth2::Client.new(
			  :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
			  :audience => 'https://accounts.google.com/o/oauth2/token',
			  :scope => 'https://www.googleapis.com/auth/bigquery',
			  :issuer => @issuer,
			  :signing_key => key
			)
			@client.authorization.fetch_access_token!
			# TODO Check for auth success
			@is_authenticated = true
		end

	def pull_request_count(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		offset = self.period_to_offset(opts.period)
		filters = self.default_filters(opts)
		filters << "type='PullRequestEvent'"
		filters << "payload_action = 'opened'"
		filters_str = filters.join(' AND ')
		query = <<eos
			SELECT 
				LEFT(created_at, #{offset}) as period, 
				COUNT(*) as total_count
			FROM [githubarchive:github.timeline]
			WHERE #{filters_str}
			GROUP BY period
			ORDER BY period ASC;
eos

		client.logger.debug(query)

		return self.query(query)
	end

	# Caution: NOT the commit count, only the latest commit in this particular
	# push is tracked through the githubarchive normalization
	def push_count_by_author(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		offset = self.period_to_offset(opts.period)
		filters = self.default_filters(opts)
		filters << "type IN ('PushEvent')"
		filters_str = filters.join(' AND ')
		query = <<eos
			SELECT 
				actor_attributes_login, LEFT(created_at, #{offset}) as period, 
				COUNT(*) as pushes
			FROM [githubarchive:github.timeline]
			WHERE #{filters_str}
			GROUP BY period, actor_attributes_login
			ORDER BY period, actor_attributes_login ASC;
eos

		client.logger.debug(query)
		
		return self.query(query)
	end

	def comment_count_by_author(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		offset = self.period_to_offset(opts.period)
		filters = self.default_filters(opts)
		filters << "type IN ('CommitCommentEvent','IssueCommentEvent','PullRequestReviewCommentEvent')"
		filters_str = filters.join(' AND ')
		query = <<eos
			SELECT 
				actor_attributes_login, LEFT(created_at, #{offset}) as period, 
				SUM(CASE WHEN type='CommitCommentEvent' THEN 1 ELSE 0 END) as commit_comments,
				SUM(CASE WHEN type='PullRequestCommentEvent' THEN 1 ELSE 0 END) as pull_request_comments,
				SUM(CASE WHEN type='IssueCommentEvent' THEN 1 ELSE 0 END) as issue_comments
			FROM [githubarchive:github.timeline]
			WHERE #{filters_str}
			GROUP BY period, actor_attributes_login
			ORDER BY period, actor_attributes_login ASC;
eos

		client.logger.debug(query)
		
		return self.query(query)
	end

	def pull_request_count_by_author(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		offset = self.period_to_offset(opts.period)
		filters = self.default_filters(opts)
		filters << "type='PullRequestEvent'"
		filters << "payload_action = 'opened'"
		filters_str = filters.join(' AND ')
		query = <<eos
			SELECT 
				actor_attributes_login, LEFT(created_at, #{offset}) as period, 
				COUNT(*) as pull_requests_opened
			FROM [githubarchive:github.timeline]
			WHERE #{filters_str}
			GROUP BY period, actor_attributes_login
			ORDER BY period, actor_attributes_login ASC;
eos
		client.logger.debug(query)
		
		return self.query(query)
	end

	def issue_count_by_author(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		offset = self.period_to_offset(opts.period)
		filters = self.default_filters(opts)
		filters << "type='IssuesEvent'"
		filters << "payload_action IN ('opened','closed')"
		filters_str = filters.join(' AND ')
		query = <<eos
			SELECT 
				actor_attributes_login, LEFT(created_at, #{offset}) as period, 
			  SUM(CASE WHEN payload_action='opened' THEN 1 ELSE 0 END) as issues_opened,
			  SUM(CASE WHEN payload_action='closed' THEN 1 ELSE 0 END) as issues_closed
			FROM [githubarchive:github.timeline]
			WHERE #{filters_str}
			GROUP BY period, actor_attributes_login
			ORDER BY period,actor_attributes_login ASC;
eos

		client.logger.debug(query)
		
		return self.query(query)
	end

	def issue_count_by_status(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		offset = self.period_to_offset(opts.period)
		filters = self.default_filters(opts)
		filters << "type='IssuesEvent'"
		filters << "payload_action IN ('opened','closed')"
		filters_str = filters.join(' AND ')
		query = <<eos
			SELECT 
				LEFT(created_at, #{offset}) as period, 
			  SUM(CASE WHEN payload_action='opened' THEN 1 ELSE 0 END) as count_opened,
			  SUM(CASE WHEN payload_action='closed' THEN 1 ELSE 0 END) as count_closed
			FROM [githubarchive:github.timeline]
			WHERE #{filters_str}
			GROUP BY period
			ORDER BY period ASC;
eos

		client.logger.debug(query)
		
		return self.query(query)
	end

	def repo_stats(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct

		filters = self.default_filters(opts)
		filters << "type IN ('PushEvent','IssuesEvent','PullRequestEvent','CommitCommentEvent','IssueCommentEvent','PullRequestReviewCommentEvent')"
		filters_str = filters.join(' AND ')
		query = <<eos
			SELECT 
				repository_url,
				COUNT(*) AS event_count
			FROM [githubarchive:github.timeline]
			WHERE #{filters_str}
			GROUP BY repository_url
			ORDER BY event_count DESC;
eos

		client.logger.debug(query)
		
		return self.query(query)

		end

	def default_filters(opts)
		filters = []
		if opts.orgas and opts.orgas.length > 0
			filters << '(' + opts.orgas.map{|owner|"repository_owner='#{owner}'"}.join(' OR ') + ')' 
		end
		if opts.repos and opts.repos.length > 0
			filters << '(' + opts.repos.map{|repo|"repository_url CONTAINS '#{repo}'"}.join(' OR ') + ')' 
		end
		if opts.since then filters << "created_at > '#{opts.since}'" end
		filters
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