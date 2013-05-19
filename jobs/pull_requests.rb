require 'json'
require 'time'
require 'dashing'
require File.expand_path('../../lib/big_query_backend', __FILE__)

# :first_in sets how long it takes before the job is first run. In this case, it is run immediately
SCHEDULER.every '1d', :first_in => 0 do |job|
	config = YAML.load(ERB.new(File.read(settings.root + '/jobs/config/config.yml')).result)
	backend = BigQueryBackend.new(config['google_api_client'])
	result = backend.pull_requests_by_period('month', config['orgas'], config['repos'])
	data = result.data
	points = data['rows'].each_with_index.map do |row,i|
		period = Time.strptime(row['f'][0]['v'], '%Y-%m')
		{x: period.to_i,y:row['f'][1]['v'].to_i}
	end

	# Compare to last month by using multiplier based on month "progress"
	# Example: 50 requests in all of March, 40 requests until 15th of April.
	# Multiplier is 0.5 (month halfway through) -> (40/(50*0.5)*100)-100 -> 60% increase
	trend_pct = ((points[-1][:y].to_f / points[-2][:y].to_f * (31/Time.now.day.to_f))*100) - 100
	trend_sign = trend_pct > 0 ? '+' : '-'
	send_event('pull_requests', {points: points, moreinfo: "#{trend_sign}#{trend_pct.ceil}%"})
end