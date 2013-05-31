require 'json'
require 'time'
require 'dashing'
require File.expand_path('../../lib/helper', __FILE__)

SCHEDULER.every '1h', :first_in => '1s' do |job|
	backend = BigQueryBackend.new(
    :keystr=>ENV['GOOGLE_KEY'],
    :secret=>ENV['GOOGLE_SECRET'],
    :issuer=>ENV['GOOGLE_ISSUER'],
    :project_id=>ENV['GOOGLE_PROJECT_ID'],
  )
  stats_raw = backend.repo_stats(
    :orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']), 
    :repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
    :since=>ENV['SINCE'],
  )

  repos = stats_raw.data.rows.collect {|row|row['f'][0]['v']}
  
  # TODO Move out of widget once I've figured out Sinatra/Batman interaction
  
	send_event('meta_stats', {
		:repo_count=> repos.length,
		:repo_titles=> repos.join(', '),
		:event_count=>stats_raw.data.rows.inject(0) {|c,row|c += row['f'][1]['v'].to_i},
		:since=>ENV['SINCE']
	})
end