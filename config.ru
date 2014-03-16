require 'dashing'
require 'faraday'
require 'faraday/http_cache'
require 'time'
require 'yaml'
require 'dotenv'
require 'time'
require 'active_support/core_ext'
require 'raven'
require 'json'

if ENV['DOTENV_FILE']
  Dotenv.load ENV['DOTENV_FILE']
else
  Dotenv.load
end

use Raven::Rack
Raven.configure do |config|
  if ENV['SENTRY_DSN']
  	# TODO Fix "undefined method `send_in_current_environment?'" and disable for dev
  	config.environments = %w[ production development ] 
  else
  	config.environments = []
  end
end

# http caching for octokit middleware
stack = Faraday::RackBuilder.new do |builder|
  builder.use Faraday::HttpCache
  builder.use Octokit::Response::RaiseError
  builder.adapter Faraday.default_adapter
end
Octokit.middleware = stack

# Verbose logging in Octokit
Octokit.configure do |config|
  config.middleware.response :logger unless ENV['RACK_ENV'] == 'production'
end

Octokit.auto_paginate = true

ENV['SINCE'] ||= '12.months.ago.beginning_of_month'
ENV['SINCE'] = ENV['SINCE'].to_datetime.to_s rescue eval(ENV['SINCE']).to_s

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