require 'json'
require 'time'
require 'faraday'
require 'logger'

class TravisBackend

	attr_accessor :client, :logger, :api_base

	def initialize
		# TODO Init HTTP client
		@logger = Logger.new(STDOUT)
		@logger.level = Logger::DEBUG unless ENV['RACK_ENV'] == 'production'
		@api_base = 'https://api.travis-ci.org/'
	end
	
	# Returns all repositories for a given organization
	def get_repos_by_orga(orga) 
		return self.fetch("repos?owner_name=#{orga}")
	end

	# repo (string) Fully qualified name, incl. owner
	# Returns a single repository as a Hash
	def get_repo(repo)
		return self.fetch("repos/#{repo}")
	end

	# repo (string) Fully qualified name, incl. owner
	# Returns a single repository as a Hash
	def get_builds_by_repo(repo)
		return self.fetch("repos/#{repo}/builds")
	end

	def get_branches_by_repo(repo)
		return self.fetch("repos/#{repo}/branches")
	end

	# Returns a Hash
	def fetch(path)
		@logger.debug 'Fetching %s%s' % [@api_base,path]

		conn = Faraday.new @api_base, :ssl => {:verify => false}
		response = conn.get path

		# TODO Better error handling
		return response.status == 200 ? JSON.parse(response.body) : false
	end

end