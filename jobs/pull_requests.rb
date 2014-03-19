require 'json'
require 'time'
require 'dashing'
require File.expand_path('../../lib/helper', __FILE__)


SCHEDULER.every '1h', :first_in => '1s' do |job|
	backend = GithubBackend.new()
	pulls = backend.pull_count_by_status(
		:period=>'month', 
		:orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']), 
		:repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
		:since=>ENV['SINCE'],
	)
	points = []
	pulls.group_by_month(ENV['SINCE'].to_datetime).each do |period,pulls_by_period|
		timestamp = Time.strptime(period, '%Y-%m').to_i
		points << {
			x: timestamp,
			y: pulls_by_period.count
		}
	end

	current = points[-1][:y] rescue 0
	prev = points[-2][:y] rescue 0
	trend = GithubDashing::Helper.trend_percentage_by_month(prev, current)
	trend_class = GithubDashing::Helper.trend_class(trend)
	send_event(
		'pull_requests', 
		{
			series: [points], # Prepare for showing open/closed stacked
			displayedValue: current,
			difference: trend,
			trend_class: trend_class,
			arrow: 'icon-arrow-' + trend_class
		}
	)
end