require 'google/api_client'

# Interacts with the Google BigQuery API. 
# Handles authentication and API discovery.
class BigQueryBackend

	attr_accessor :client, :keyfile, :secret, :issuer, :project_id
	attr_reader :api, :is_authenticated

	def initialize(args={})
		@client = Google::APIClient.new(
			:application_name => 'Github Dashing BigqueryBackend',
			:application_version => '0.1'
		)
		# @client.logger.level = Logger::DEBUG
		
		args.each do |k,v|
      instance_variable_set("@#{k}", v) unless v.nil?
    end
	end

	def query(query)
		self.authenticate
		
		result = @client.execute(
		  :api_method => @api.jobs.query,
		  :parameters => {'projectId' => @project_id},
		  :body_object => {'query' => query}
		)
		# TODO Check for query success (or retry)

		return result
	end

	def authenticate()
		if not @is_authenticated
			@api = @client.discovered_api('bigquery', "v2")
			@client.authorization = Signet::OAuth2::Client.new(
			  :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
			  :audience => 'https://accounts.google.com/o/oauth2/token',
			  :scope => 'https://www.googleapis.com/auth/bigquery',
			  :issuer => @issuer,
			  :signing_key => Google::APIClient::KeyUtils.load_from_pkcs12(File.open(@keyfile), @secret)
			)
			@client.authorization.fetch_access_token!
			# TODO Check for auth success
			@is_authenticated = true
		end
	end

	def pull_requests_by_period(period='month', owners=[], repos=[])
		case period
		when 'day'
			period_filter = 10
		when 'month'
			period_filter = 7
		when 'year'
			period_filter = 4
		end
		owners_filter = owners.map{|owner|"repository_owner='#{owner}'"}.join(' OR ')
		repos_filter = repos.map{|repo|"repository_name='#{repo}'"}.join(' OR ')
		query = <<eos
			SELECT 
				LEFT(created_at, #{period_filter}) as period, 
				COUNT(*) as total_count
			FROM [githubarchive:github.timeline]
			WHERE
			    type='PullRequestEvent' 
			    AND payload_action = 'opened'
			    AND (#{owners_filter})
			    AND (#{repos_filter})
			GROUP BY period
			ORDER BY period ASC;
eos

		client.logger.debug(query)

		return self.query(query)
	end

	def issues_by_status(period='month', owners=[], repos=[])
		case period
		when 'day'
			period_filter = 10
		when 'month'
			period_filter = 7
		when 'year'
			period_filter = 4
		end
		owners_filter = owners.map{|owner|"repository_owner='#{owner}'"}.join(' OR ')
		repos_filter = repos.map{|repo|"repository_name='#{repo}'"}.join(' OR ')
		query = <<eos
			SELECT 
				LEFT(created_at, #{period_filter}) as period, 
			  SUM(CASE WHEN payload_action='opened' THEN 1 ELSE 0 END) as count_opened,
			  SUM(CASE WHEN payload_action='closed' THEN 1 ELSE 0 END) as count_closed
			FROM [githubarchive:github.timeline]
			WHERE
			    type='IssuesEvent' 
			    AND payload_action IN ('opened','closed')
			    AND (#{owners_filter})
			    AND (#{repos_filter})
			GROUP BY period
			ORDER BY period ASC;
eos

		client.logger.debug(query)
		
		return self.query(query)
	end

end