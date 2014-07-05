require 'json'
require 'time'
require 'dashing'
require 'active_support/core_ext'
require File.expand_path('../../lib/helper', __FILE__)

SCHEDULER.every '1h', :first_in => '1s' do |job|
	backend = GithubBackend.new()
	opened_series = [[],[]]
	closed_series = [[],[]]
	issues_by_period = backend.issue_count_by_status(
		:orgas=>(ENV['ORGAS'].split(',') if ENV['ORGAS']), 
		:repos=>(ENV['REPOS'].split(',') if ENV['REPOS']),
		:since=>ENV['SINCE']
	).group_by_month(ENV['SINCE'].to_datetime)
	issues_by_period.each_with_index do |(period,issues),i|
		timestamp = Time.strptime(period, '%Y-%m').to_i

		opened_count = issues.select {|issue|issue.key == 'open'}.count
		opened_series[0] << {
			x: timestamp,
			y: opened_count
		}
		# Add empty second series stack, and extrapolate last month for better trend visualization
		opened_series[1] << {
			x: timestamp,
			y: (i == issues_by_period.count-1) ? GithubDashing::Helper.extrapolate_to_month(opened_count)-opened_count : 0
		}

		closed_count = issues.select {|issue|issue.key == 'closed'}.count
		closed_series[0] << {
			x: timestamp,
			y: closed_count
		}
		# Add empty second series stack, and extrapolate last month for better trend visualization
		closed_series[1] << {
			x: timestamp,
			y: (i == issues_by_period.count-1) ? GithubDashing::Helper.extrapolate_to_month(closed_count)-opened_count : 0
		}
	end
	
	opened = series[0][-1][:y] rescue 0
	closed = series[1][-1][:y] rescue 0
	opened_prev = series[0][-2][:y] rescue 0
	closed_prev = series[1][-2][:y] rescue 0
	trend_opened = GithubDashing::Helper.trend_percentage_by_month(opened_prev, opened)
	trend_closed = GithubDashing::Helper.trend_percentage_by_month(closed_prev, closed)
	trend_class_opened = GithubDashing::Helper.trend_class(trend_opened)
	trend_class_closed = GithubDashing::Helper.trend_class(trend_closed)

	send_event('issues_stacked', {
		series: [opened_series[0],closed_series[0]],
		displayedValue: opened,
		moreinfo: "<span title=\"#{trend_closed}\">#{closed}</span> closed (#{trend_closed})",
		difference: trend_opened,
		trend_class: trend_class_opened,
		arrow: 'icon-arrow-' + trend_class_opened
	})

	send_event('issues_opened', {
		series: opened_series,
		displayedValue: opened,
		moreinfo: "",
		difference: trend_opened,
		trend_class: trend_class_opened,
		arrow: 'icon-arrow-' + trend_class_opened
	})

	send_event('issues_closed', {
		series: closed_series,
		displayedValue: closed,
		moreinfo: "",
		difference: trend_closed,
		trend_class: trend_class_closed,
		arrow: 'icon-arrow-' + trend_class_closed
	})
end