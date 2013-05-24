module GithubDashing
	class Helper
		# Compare to last month by using multiplier based on month "progress"
		# Example: 50 requests in all of March, 40 requests until 15th of April.
		# Multiplier is 0.5 (month halfway through) -> (40/(50*0.5)*100)-100 -> 60% increase
		def self.trend_percentage_by_month(last, current)
			trend = (current.to_f / last.to_f * (31/Time.now.day.to_f))*100-100
			sign = trend > 0 ? '+' : ''
			return "#{sign}#{trend.ceil}%"
		end
	end
end