# -*- encoding: utf-8 -*-
require File.expand_path('../lib/duly_noted/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Will Cosgrove"]
  gem.email         = ["will@willcosgrove.com"]
  gem.description   = %q{a simple redis based stat-tracker}
  gem.summary       = %q{keep detailed metrics on your project with a speedy, powerful redis backend.}
  gem.homepage      = "http://github.com/willcosgrove/duly_noted"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "duly_noted"
  gem.require_paths = ["lib"]
  gem.version       = DulyNoted::VERSION
  gem.add_dependency "redis", "~> 2.2.2"
  gem.add_development_dependency "rspec", "~> 2.8.0"
  gem.add_development_dependency "rake", "~> 0.9.2.2"
  gem.add_development_dependency "rb-fsevent", "~> 0.9.0"
  gem.add_development_dependency "guard-rspec", "~> 0.6.0"
  gem.add_development_dependency "guard-bundler", "~> 0.1.3"
  gem.add_development_dependency "chronic", "~> 0.6.7"
  gem.add_development_dependency "timecop", "~> 0.3.5"
  gem.add_development_dependency "ruby_gntp", "~> 0.3.4"
end
