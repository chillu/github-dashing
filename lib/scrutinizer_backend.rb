require 'json'
require 'time'
require 'faraday'
require 'logger'

# See https://scrutinizer-ci.com/docs/api/
class ScrutinizerBackend

	attr_accessor :client, :logger, :api_base

	def initialize
		# TODO Init HTTP client
		@logger = Logger.new(STDOUT)
		@logger.level = Logger::DEBUG unless ENV['RACK_ENV'] == 'production'
		@api_base = 'https://scrutinizer-ci.com/api/'
	end
	
	# Returns info for a given repository
	def get_repo_info(repo, type='g') 
		return self.fetch("repositories/#{type}/#{repo}")
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