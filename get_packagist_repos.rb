# Collect all modules of a specific type from packagist.org
# Useful for configuring the REPOS configuration key.
# Requires the 'composer' binary.

require 'json'
require 'net/https'
require 'cgi'

type='silverstripe-module'
results = []
nexturl = "https://packagist.org/search.json?type=#{type}"
i = 0
while nexturl and i < 100 do
	puts "Loading #{nexturl}"
	uri_obj = URI.parse(nexturl)
	break unless uri_obj and uri_obj.request_uri
	http = Net::HTTP.new(uri_obj.host, uri_obj.port)
	http.use_ssl = true
	http.verify_mode = OpenSSL::SSL::VERIFY_NONE
	request = Net::HTTP::Get.new(uri_obj.request_uri)
	response = http.request(request)
	part = JSON.parse(response.body)
	results += part['results']
	i += 1
	nexturl = part['next'] ? CGI::unescape(part['next'].to_s).sub('[0]','') : nil
end

# Convert composer ids to github URLs
github_paths = []
results.each do |result|
	name = result['name']
	data = `composer show --no-ansi --no-interaction #{name}`
	github_url = /https?:\/\/github.com[^\s]*/.match(data).to_s
	github_paths << github_url.sub(/https?:\/\/github.com\//, '').sub(/\.git/, '')
end

puts github_paths.join(',')