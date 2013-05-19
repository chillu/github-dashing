require 'json'
require 'time'
require 'dashing'
require File.expand_path('../../lib/helper', __FILE__)
require File.expand_path('../../lib/big_query_backend', __FILE__)

SCHEDULER.every '1h', :first_in => 0 do |job|
	config = YAML.load(ERB.new(File.read(settings.root + '/jobs/config/config.yml')).result)
	backend = BigQueryBackend.new(config['google_api_client'])
	result = backend.pull_requests_by_period('month', config['orgas'], config['repos'])
	data = result.data
	points = data['rows'].each_with_index.map do |row,i|
		# Cols: period, count
		period = Time.strptime(row['f'][0]['v'], '%Y-%m')
		{x: period.to_i,y:row['f'][1]['v'].to_i}
	end

	trend = GithubDashing::Helper.trend_percentage_by_month(points[-2][:y], points[-1][:y])
	send_event('pull_requests', {points: points, moreinfo: trend})
end