require 'google/api_client'
require 'ostruct'

# Interacts with the Google BigQuery API. 
# Handles authentication and API discovery.
class BigQueryBackend

	attr_accessor :client, :keyfile, :keystr, :secret, :issuer, :project_id
	attr_reader :api, :is_authenticated

	def initialize(args={})
		@client = Google::APIClient.new(
			:application_name => 'Github Dashing BigqueryBackend',
			:application_version => '0.1'
		)
		@client.logger.level = Logger::DEBUG
		
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
			if @keyfile
				key = Google::APIClient::KeyUtils.load_from_pkcs12(File.open(@keyfile), @secret)
			elsif @keystr
				# See http://ar.zu.my/how-to-store-private-key-files-in-heroku/
				 key = OpenSSL::PKey::RSA.new @keystr, @secret
				 # TODO Remove, debug setting
				client.logger.debug('Using key' + @keystr)
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
	end

	def leaderboard(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct

		pull_request_data = self.pull_request_count_by_author(opts).data
		comment_data = self.comment_count_by_author(opts).data
		issue_data = self.issue_count_by_author(opts).data
		commit_data = self.commit_count_by_author(opts).data
		
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
		all_actors += commit_data['rows'].map{|row|row['f'][0]['v']}
		all_actors.delete_if {|x| x == nil}
		all_actors.uniq!.sort!

		all_periods = []
		all_periods += pull_request_data['rows'].map{|row|row['f'][1]['v']}
		all_periods += comment_data['rows'].map{|row|row['f'][1]['v']}
		all_periods += issue_data['rows'].map{|row|row['f'][1]['v']}
		all_periods += commit_data['rows'].map{|row|row['f'][1]['v']}
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
		commit_data['rows'].each do |row|
			actor = row['f'][0]['v']
			next unless actor
			period = row['f'][1]['v']
			actors_by_period[actor]['periods'][period]['commits'] = row['f'][2]['v']
		end
		
		# Add score for each period
		actors_by_period.each do |actor,actor_data|
			actor_data['periods'].each do |period,period_data|
				desc = []
				period_data['score'] = period_data.inject(0) do |c,(k,v)|
					weight = opts.weighting.has_key?(k) ? opts.weighting[k] : 0
					desc.push "(#{k}=#{v} * weight=#{weight})"
					c += v.to_f * weight.to_f
				end
				period_data['desc'] = desc.join(' + ')
			end
			actors_by_period[actor]['current_score'] = actor_data['periods'][all_periods[-1]]['score']
			actors_by_period[actor]['current_desc'] = actor_data['periods'][all_periods[-1]]['desc']
			actors_by_period[actor]['previous_score'] = actor_data['periods'][all_periods[-2]]['score']
		end

		# Sort by score (converts to Array)
		actors_by_period = actors_by_period.sort_by {|k,v|v['current_score']}.reverse

		# Limit to top list
		actors_by_period = actors_by_period[0,opts.limit || 10]

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

	def commit_count_by_author(opts)
		opts = OpenStruct.new(opts) unless opts.kind_of? OpenStruct
		offset = self.period_to_offset(opts.period)
		filters = self.default_filters(opts)
		filters << "type IN ('PushEvent')"
		filters_str = filters.join(' AND ')
		query = <<eos
			SELECT 
				actor_attributes_login, LEFT(created_at, #{offset}) as period, 
				COUNT(*) as commits
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

	def default_filters(opts)
		filters = []
		if opts.orgas.length > 0 then filters << '(' + opts.orgas.map{|owner|"repository_owner='#{owner}'"}.join(' OR ') + ')' end
		if opts.repos.length > 0 then filters << '(' + opts.repos.map{|repo|"repository_name='#{repo}'"}.join(' OR ') + ')' end
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