module DulyNoted
  module Helpers
    def key_encode(type)
      "#{type}:#{Time.now.to_f}"
    end
  end
end