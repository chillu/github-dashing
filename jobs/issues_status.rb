require 'json'
require 'time'
require 'dashing'
require File.expand_path('../../lib/helper', __FILE__)

SCHEDULER.every '1h', :first_in => '10s' do |job|
	backend = BigQueryBackend.new(
		:keystr=>ENV['GOOGLE_KEY'],
		:secret=>ENV['GOOGLE_SECRET'],
		:issuer=>ENV['GOOGLE_ISSUER'],
		:project_id=>ENV['GOOGLE_PROJECT_ID'],
	)
	result = backend.issue_count_by_status(
		:period=>'month', 
		:orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']), 
		:repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
		:since=>ENV['SINCE']
	)
	data = result.data
	puts data.to_json
	series = [[],[]]
	data['rows'].each do |row,i|
		period = Time.strptime(row['f'][0]['v'], '%Y-%m')
		# Cols: period, count_opened, count_closed
		series[0] << {x: period.to_i,y:row['f'][1]['v'].to_i}
		series[1] << {x: period.to_i,y:row['f'][2]['v'].to_i}
	end
	
	opened = series[0][-1][:y]
	closed = series[1][-1][:y]
	opened_prev = series[0][-2][:y] rescue 0
	closed_prev = series[1][-2][:y] rescue 0
	trend_opened = GithubDashing::Helper.trend_percentage_by_month(opened_prev, opened)
	trend_closed = GithubDashing::Helper.trend_percentage_by_month(closed_prev, closed)
	
	send_event('issues_stacked', {
		series: series, 
		displayedValue: opened,
		moreinfo: "<span title=\"#{trend_closed}\">#{closed}</span> closed (#{trend_closed})",
		difference: trend_opened,
		arrow: trend_opened.to_f > 0 ? 'icon-arrow-up' : 'icon-arrow-down'
	})
end