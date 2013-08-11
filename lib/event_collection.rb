require 'date'
require 'active_support/core_ext'
require 'forwardable'

module GithubDashing
	class EventCollection		
		include Enumerable
		extend Forwardable
  	def_delegators :@events, :each, :<<

		def initialize(events=nil)
			@events = events ? events : []
		end

		def group_by_month(start, finish = nil)
			grouped = {}
			finish = Time.new().to_datetime unless finish
			start = start.at_beginning_of_month
			finish = finish.at_beginning_of_month
			(start.to_date..finish.to_date).select {|d| d.day == 1}.each do |period|
				period_str = period.strftime '%Y-%m'
				grouped[period_str] = @events.select{|event|event.datetime.strftime("%Y-%m").to_s == period_str.to_s}
			end
			return grouped
		end

	end
end