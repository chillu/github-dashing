require 'dashing'
require 'time'
require 'yaml'
require File.expand_path('../lib/big_query_backend', __FILE__)

configure do

  set :auth_token, 'YOUR_AUTH_TOKEN'
  set :environment, :development

  # TODO Better way to attach globals to Sinatra app
  set :big_query_backend, BigQueryBackend.new(
		:keystr=>ENV['GOOGLE_KEY'],
		:secret=>ENV['GOOGLE_SECRET'],
		:issuer=>ENV['GOOGLE_ISSUER'],
		:project_id=>ENV['GOOGLE_PROJECT_ID'],
	)

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