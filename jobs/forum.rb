require 'json'
require 'time'
require 'dashing'
require 'faraday'
require File.expand_path('../../lib/helper', __FILE__)

# Shows number of unanswered forum posts
SCHEDULER.every '1h', :first_in => '1s' do |job|
	next unless ENV['FORUM_STATS_URL']

	response = Faraday.get ENV['FORUM_STATS_URL']
	data = response.status == 200 ? JSON.parse(response.body) : false

	series = []
	series[0] = data['unanswered'].map do |period,count|
		{x: Time.strptime(period, '%Y-%m').to_i, y: count.to_i}
	end

	trend = GithubDashing::Helper.trend_percentage_by_month(series[0][-2][:y], series[0][-1][:y])
	trend_class = GithubDashing::Helper.trend_class(trend)

	send_event('forum_unanswered', {
		series: series,
		displayedValue: series[0][-1][:y],
		difference: trend,
		trend_class: trend_class,
		arrow: 'icon-arrow-' + trend_class
	})

end