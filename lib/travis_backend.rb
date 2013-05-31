require 'json'
require 'time'
require 'net/https'
require 'cgi'
require 'logger'

class TravisBackend

	attr_accessor :client, :logger

	def initialize
		# TODO Init HTTP client
		@logger = Logger.new(STDOUT)
		@logger.level = Logger::DEBUG unless ENV['RACK_ENV'] == 'production'
	end
	
	# Returns all repositories for a given organization
	def get_repos_by_orga(orga) 
		return self.fetch("https://api.travis-ci.org/repos?owner_name=#{orga}")
	end

	# repo (string) Fully qualified name, incl. owner
	# Returns a single repository as a Hash
	def get_repo(repo)
		return self.fetch("https://api.travis-ci.org/repos/#{repo}")
	end

	# repo (string) Fully qualified name, incl. owner
	# Returns a single repository as a Hash
	def get_builds_by_repo(repo)
		return self.fetch("https://api.travis-ci.org/repos/#{repo}/builds")
	end

	# Returns a Hash
	def fetch(uri_str)
		@logger.debug 'Fetching %s' % uri_str

		uri = URI.parse(uri_str)
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		http.verify_mode = OpenSSL::SSL::VERIFY_NONE
		request = Net::HTTP::Get.new(uri.request_uri)
		response = http.request(request)
		return JSON.parse(response.body)
	end

end