require 'json'
require 'time'
require 'dashing'
require File.expand_path('../../lib/helper', __FILE__)
require File.expand_path('../../lib/big_query_backend', __FILE__)

SCHEDULER.every '1h', :first_in => 0 do |job|
	config = YAML.load(ERB.new(File.read(settings.root + '/jobs/config/config.yml')).result)
	backend = BigQueryBackend.new(config['google_api_client'])
	result = backend.issue_count_by_status(:period=>'month', :orgas=>config['orgas'], :repos=>config['repos'])
	data = result.data
	puts data.to_json
	series = [[],[]]
	data['rows'].each do |row,i|
		period = Time.strptime(row['f'][0]['v'], '%Y-%m')
		# Cols: period, count_opened, count_closed
		series[0] << {x: period.to_i,y:row['f'][1]['v'].to_i}
		series[1] << {x: period.to_i,y:row['f'][2]['v'].to_i}
	end
	puts series.to_json
	
	trend_opened = GithubDashing::Helper.trend_percentage_by_month(series[0][-2][:y], series[0][-1][:y])
	trend_closed = GithubDashing::Helper.trend_percentage_by_month(series[1][-2][:y], series[1][-1][:y])
	
	send_event('issues_stacked', {
		series: series, 
		# displayedValue: "#{trend_opened}<br/><small>opened</small>",
		displayedValue: "#{trend_opened} new",
		moreinfo: "#{trend_closed} closed"
	})
end