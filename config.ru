require 'dashing'
require 'faraday'
require 'faraday/http_cache'
require 'time'
require 'yaml'
require 'time'
require 'active_support'
require 'active_support/core_ext'
require 'raven'
require 'json'
require 'typhoeus'
require 'typhoeus/adapters/faraday'

use Raven::Rack
Raven.configure do |config|
  if ENV['SENTRY_DSN'] and not ENV['SENTRY_DSN'].empty?
  	# TODO Fix "undefined method `send_in_current_environment?'" and disable for dev
  	config.environments = %w[ production development ] 
  else
  	config.environments = []
  end
end

# Persist on disk, don't exceed heroku memory limit
stack = Faraday::RackBuilder.new do |builder|
  store = ActiveSupport::Cache.lookup_store(:file_store, [Dir.pwd + '/tmp'])
  logger = Logger.new(STDOUT)
  logger.level = Logger::DEBUG unless ENV['RACK_ENV'] == 'production'
  builder.use :http_cache, store: store, logger: logger, shared_cache: false, serializer: Marshal
  builder.use Octokit::Response::RaiseError
  builder.request :retry
  builder.adapter :typhoeus

end
Octokit.middleware = stack

# Verbose logging in Octokit
Octokit.configure do |config|
  config.middleware.response :logger unless ENV['RACK_ENV'] == 'production'
end

Octokit.auto_paginate = true

ENV['SINCE'] ||= '12.months.ago.beginning_of_month'
ENV['SINCE'] = DateTime.iso8601(ENV['SINCE']).to_s rescue eval(ENV['SINCE']).to_s

ENV['TRAVIS_API_ENDPOINT'] ||= 'https://api.travis-ci.org/'

configure do

  set :auth_token, 'YOUR_AUTH_TOKEN'
  set :environment, ENV['RACK_ENV']
  disable :protection

  helpers do
    def protected!
     # Put any authentication code you want in here.
     # This method is run before accessing any resource.
    end
  end
end

# class NoCompression
#   def compress(string)
#     # do nothing
#     string
#   end
# end
# Sinatra::Application.sprockets.js_compressor = NoCompression.new

map Sinatra::Application.assets_prefix do
  run Sinatra::Application.sprockets
end

run Sinatra::Application
