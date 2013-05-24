require 'json'
require 'time'
require 'dashing'
require File.expand_path('../../lib/helper', __FILE__)


SCHEDULER.every '1h', :first_in => '5s' do |job|
	result = settings.big_query_backend.pull_request_count(
		:period=>'month', 
		:orgas=>ENV['ORGAS'].split(','), 
		:repos=>ENV['REPOS'].split(','),
		:limit=>20
	)
	data = result.data
	points = data['rows'].each_with_index.map do |row,i|
		# Cols: period, count
		period = Time.strptime(row['f'][0]['v'], '%Y-%m')
		{x: period.to_i,y:row['f'][1]['v'].to_i}
	end

	trend = GithubDashing::Helper.trend_percentage_by_month(points[-2][:y], points[-1][:y])
	send_event('pull_requests', {points: points, moreinfo: trend})
end