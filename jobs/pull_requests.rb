require 'json'
require 'time'
require 'dashing'
require File.expand_path('../../lib/helper', __FILE__)


SCHEDULER.every '1h', :first_in => 0 do |job|
	backend = BigQueryBackend.new(
		:keystr=>ENV['GOOGLE_KEY'],
		:secret=>ENV['GOOGLE_SECRET'],
		:issuer=>ENV['GOOGLE_ISSUER'],
		:project_id=>ENV['GOOGLE_PROJECT_ID'],
	)
	result = backend.pull_request_count(
		:period=>'month', 
		:orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']), 
		:repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
		:since=>ENV['SINCE'],
		:limit=>20
	)
	data = result.data
	points = data['rows'].each_with_index.map do |row,i|
		# Cols: period, count
		period = Time.strptime(row['f'][0]['v'], '%Y-%m')
		{x: period.to_i,y:row['f'][1]['v'].to_i}
	end

	current = points[-1][:y]
	prev = points[-2][:y] rescue 0
	trend = GithubDashing::Helper.trend_percentage_by_month(prev, current)
	trend_class = trend.to_f < 0 ? 'bad' : 'good'
	send_event(
		'pull_requests', 
		{
			points: points, 
			displayedValue: current,
			difference: trend,
			arrow: trend.to_f > 0 ? 'icon-arrow-up' : 'icon-arrow-down'
		}
	)
end