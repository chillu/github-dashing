module GithubDashing
	class Helper

		def self.extrapolate_to_month(current)
			current.to_f * (31/Time.now.day.to_f)
		end

		def self.trend_percentage(last, current, use_sign=false)
			if last.to_f > 0 # avoid division by infinity
				trend = (current.to_f / last.to_f)*100-100
				sign = (trend > 0 and use_sign) ? '+' : ''
			else 
				trend = 0
				sign = ''
			end
			return "#{sign}#{trend.ceil}%"
		end

		# Compare to last month by using multiplier based on month "progress"
		# Example: 50 requests in all of March, 40 requests until 15th of April.
		# Multiplier is 0.5 (month halfway through) -> (40/(50*0.5)*100)-100 -> 60% increase
		def self.trend_percentage_by_month(last, current, use_sign=false)
			if last.to_f > 0 # avoid division by infinity
				trend = (current.to_f / last.to_f * (31/Time.now.day.to_f))*100-100
				sign = (trend > 0 and use_sign) ? '+' : ''
			else 
				trend = 0
				sign = ''
			end
			return "#{sign}#{trend.ceil}%"
		end

		def self.trend_class(val)
			if val.to_f > 0
				'up'
			elsif val.to_f < 0
				'down'
			else 
				''
			end
		end

	end
end