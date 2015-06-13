# -*- encoding: utf-8 -*-
# stub: redis-semaphore 0.2.4 ruby lib

Gem::Specification.new do |s|
  s.name = "redis-semaphore"
  s.version = "0.2.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["David Verhasselt"]
  s.date = "2015-01-11"
  s.description = "Implements a distributed semaphore or mutex using Redis.\n"
  s.email = "david@crowdway.com"
  s.homepage = "http://github.com/dv/redis-semaphore"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.4.5"
  s.summary = "Implements a distributed semaphore or mutex using Redis."

  s.installed_by_version = "2.4.5" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<redis>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<rspec>, [">= 2.14"])
      s.add_development_dependency(%q<pry>, [">= 0"])
      s.add_development_dependency(%q<timecop>, [">= 0"])
    else
      s.add_dependency(%q<redis>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<rspec>, [">= 2.14"])
      s.add_dependency(%q<pry>, [">= 0"])
      s.add_dependency(%q<timecop>, [">= 0"])
    end
  else
    s.add_dependency(%q<redis>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<rspec>, [">= 2.14"])
    s.add_dependency(%q<pry>, [">= 0"])
    s.add_dependency(%q<timecop>, [">= 0"])
  end
end
