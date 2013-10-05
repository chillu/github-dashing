module GithubDashing
	class Event
		
		# Arbitrary unique type identifier
		attr_accessor :type

		# DateTime object of when the event happened
		attr_accessor :datetime

		# Optional key (e.g. author name)
		attr_accessor :key

		# Optional value
		attr_accessor :value

		def initialize(args={})
			args.each do |k,v|
				instance_variable_set("@#{k}", v) unless v.nil?
			end
		end

		def to_s
			"GithubDashing::Event: #{@type} at #{@datetime}"
		end

	end
end