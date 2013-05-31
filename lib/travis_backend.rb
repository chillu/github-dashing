require 'json'
require 'time'
require 'net/https'
require 'cgi'

class TravisBackend

	attr_accessor :client

	def initialize
		# TODO Init HTTP client
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
		puts uri_str
		uri = URI.parse(uri_str)
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		http.verify_mode = OpenSSL::SSL::VERIFY_NONE
		request = Net::HTTP::Get.new(uri.request_uri)
		response = http.request(request)
		return JSON.parse(response.body)
	end

end