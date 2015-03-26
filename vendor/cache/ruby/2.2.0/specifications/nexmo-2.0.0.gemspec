# -*- encoding: utf-8 -*-
# stub: nexmo 2.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "nexmo"
  s.version = "2.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Tim Craft"]
  s.date = "2014-07-25"
  s.description = "A Ruby wrapper for the Nexmo API"
  s.email = ["mail@timcraft.com"]
  s.homepage = "http://github.com/timcraft/nexmo"
  s.rubygems_version = "2.4.6"
  s.summary = "See description"

  s.installed_by_version = "2.4.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rake>, [">= 0.9.3"])
      s.add_development_dependency(%q<webmock>, ["~> 1.18.0"])
    else
      s.add_dependency(%q<rake>, [">= 0.9.3"])
      s.add_dependency(%q<webmock>, ["~> 1.18.0"])
    end
  else
    s.add_dependency(%q<rake>, [">= 0.9.3"])
    s.add_dependency(%q<webmock>, ["~> 1.18.0"])
  end
end
