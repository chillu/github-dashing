require 'json'
require 'time'
require 'dashing'
require File.expand_path('../../lib/helper', __FILE__)


SCHEDULER.every '1h', :first_in => '1s' do |job|
	if ENV['GOOGLE_KEY']
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
	else
		backend = GithubBackend.new()
		results = backend.pull_count_by_status(
			:period=>'month', 
			:orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']), 
			:repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
			:since=>ENV['SINCE'],
		)
		points = []
		results.each_with_index do |(period,data),i|
			# TODO Flexible periods
			timestamp = Time.strptime(period, '%Y-%m')
			# Pulls can't be filtered by date
			if(Time.at(timestamp) > ENV['SINCE'].to_datetime)
				points << {
					x: timestamp.to_i,
					y: data[:count_open].to_i + data[:count_closed].to_i
				}
			end
		end if results
	end

	current = points[-1][:y] rescue 0
	prev = points[-2][:y] rescue 0
	trend = GithubDashing::Helper.trend_percentage_by_month(prev, current)
	send_event(
		'pull_requests', 
		{
			points: points, 
			displayedValue: current,
			difference: trend,
			arrow: 'icon-arrow-' + GithubDashing::Helper.trend_class(trend)
		}
	)
end