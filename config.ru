require 'dashing'
require 'time'
require 'yaml'
require 'dotenv'
require File.expand_path('../lib/big_query_backend', __FILE__)

Dotenv.load

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