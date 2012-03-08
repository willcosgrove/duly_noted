require "duly_noted/version"

module DulyNoted
  module Updater
    def update_schema(schema_version, redis)
      # magic updating!
      redis.set "dn:version", VERSION
      puts "All up to date"
      return true
    end

    def check_schema(redis)
      schema_version = redis.get "dn:version"
      if !schema_version.nil?
        schema_version = schema_version.split(".")
        current_version = VERSION.split(".")
        if schema_version[0] != current_version[0]
          puts "Your duly_noted schema needs to be updated"
          if update_schema(schema_version.join("."), redis)
            check_schema(redis)
          else
            raise UpdateError
          end
        end
      end
      redis.set "dn:version", VERSION
      return redis
    end
  end
end