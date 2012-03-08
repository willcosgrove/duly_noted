require 'eventmachine'

module DulyNoted
  class Decay
    def initialize
      EM.run do
        if File.exist?("decay.yml")
          puts "Decayfile detected"
        end
      end
    end
  end
end