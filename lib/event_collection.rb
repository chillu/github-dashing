require 'date'
require 'active_support/core_ext'
require 'forwardable'

module GithubDashing
	class EventCollection		
		include Enumerable
		extend Forwardable
		def_delegators :@events, :each, :<<, :merge

		def initialize(events=nil)
			@events = events ? events : []
		end

		def group_by_month(date_since, date_until = nil)
			grouped = {}
			date_since ||= @events.map { |event| event.datetime }.min
			date_until ||= Time.new().to_datetime
			date_since = date_since.at_beginning_of_month
			(date_since.to_date..date_until.to_date).select {|d| d.day == 1}.each do |period|
				period_str = period.strftime '%Y-%m'
				grouped[period_str] = @events.select do |event|
					event.datetime.strftime("%Y-%m").to_s == period_str.to_s and
					event.datetime >= date_since and
					event.datetime < date_until
				end
			end
			return grouped
		end

	end
end