module DulyNoted
  module Helpers
    def key_encode(type)
      "#{type}:#{Time.now.to_f}"
    end
    
    def normalize(str)
      str.downcase.gsub(/[^a-z0-9 ]/i, '').strip
    end
  end
end