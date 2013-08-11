require 'dashing'
require 'time'
require 'yaml'
require 'dotenv'
require 'time'
require 'active_support/core_ext'
require File.expand_path('../lib/bigquery_backend', __FILE__)

Dotenv.load

ENV['SINCE'] ||= '12.months.ago.beginning_of_month'
ENV['SINCE'] = ENV['SINCE'].to_datetime.utc.to_s rescue eval(ENV['SINCE']).utc.to_s

configure do

  set :auth_token, 'YOUR_AUTH_TOKEN'
  set :environment, ENV['RACK_ENV']

  helpers do
    def protected!
     # Put any authentication code you want in here.
     # This method is run before accessing any resource.
    end
  end
end

map Sinatra::Application.assets_prefix do
  run Sinatra::Application.sprockets
end

run Sinatra::Application