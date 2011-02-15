# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "quota_tracker/version"

Gem::Specification.new do |s|
  s.name        = "quota_tracker"
  s.version     = QuotaTracker::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Bill Gathen"]
  s.email       = ["bill@billgathen.com"]
  s.homepage    = "http://rubygems.org/gems/quota_tracker"
  s.summary     = %q{Quota monitoring tool for Yieldmanager}
  s.description = %q{Quota monitoring tool for Yieldmanager}

  s.add_dependency("savon", ">= 0.8.5")
  s.add_development_dependency("rspec")

  s.rubyforge_project = "quota_tracker"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
