require 'json'
require 'time'
require 'dashing'
require File.expand_path('../../lib/helper', __FILE__)


SCHEDULER.every '1h', :first_in => '15s' do |job|
	result = settings.big_query_backend.pull_request_count(
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
	trend = GithubDashing::Helper.trend_percentage_by_month(points[-2][:y], points[-1][:y])
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