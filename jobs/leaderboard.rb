require 'json'
require 'time'
require 'dashing'
require File.expand_path('../../lib/helper', __FILE__)
require File.expand_path('../../lib/big_query_backend', __FILE__)

SCHEDULER.every '1h', :first_in => 0 do |job|
	config = YAML.load(ERB.new(File.read(settings.root + '/jobs/config/config.yml')).result)
	backend = BigQueryBackend.new(config['google_api_client'])
	actors = backend.leaderboard(:period=>'month', :orgas=>config['orgas'], :repos=>config['repos'], :limit=>20)
	
	rows = actors.map do |actor|
		{
			'values' => [
				actor[0], 
				actor[1]['previous_score'],
				actor[1]['current_score'],
				# actor[1]['current_desc'],
			]
		}
	end

	send_event('leaderboard', {
		rows: rows
	})
end