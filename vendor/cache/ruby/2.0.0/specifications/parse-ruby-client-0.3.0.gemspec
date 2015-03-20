# -*- encoding: utf-8 -*-
# stub: parse-ruby-client 0.3.0 ruby lib

Gem::Specification.new do |s|
  s.name = "parse-ruby-client"
  s.version = "0.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Alan deLevie", "Adam Alpern"]
  s.date = "2014-07-31"
  s.description = "A simple Ruby client for the parse.com REST API"
  s.email = "adelevie@gmail.com"
  s.extra_rdoc_files = ["LICENSE.txt", "README.md"]
  s.files = ["LICENSE.txt", "README.md"]
  s.homepage = "http://github.com/adelevie/parse-ruby-client"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.4.3"
  s.summary = "A simple Ruby client for the parse.com REST API"

  s.installed_by_version = "2.4.3" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<faraday>, [">= 0"])
      s.add_runtime_dependency(%q<faraday_middleware>, [">= 0"])
      s.add_development_dependency(%q<bundler>, [">= 0"])
      s.add_development_dependency(%q<shoulda>, [">= 0"])
      s.add_development_dependency(%q<test-unit>, ["= 2.5.0"])
      s.add_development_dependency(%q<mocha>, ["= 0.12.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.8.5"])
      s.add_development_dependency(%q<simplecov>, [">= 0"])
      s.add_development_dependency(%q<webmock>, ["~> 1.9.0"])
      s.add_development_dependency(%q<vcr>, [">= 0"])
      s.add_development_dependency(%q<pry>, [">= 0"])
    else
      s.add_dependency(%q<faraday>, [">= 0"])
      s.add_dependency(%q<faraday_middleware>, [">= 0"])
      s.add_dependency(%q<bundler>, [">= 0"])
      s.add_dependency(%q<shoulda>, [">= 0"])
      s.add_dependency(%q<test-unit>, ["= 2.5.0"])
      s.add_dependency(%q<mocha>, ["= 0.12.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.8.5"])
      s.add_dependency(%q<simplecov>, [">= 0"])
      s.add_dependency(%q<webmock>, ["~> 1.9.0"])
      s.add_dependency(%q<vcr>, [">= 0"])
      s.add_dependency(%q<pry>, [">= 0"])
    end
  else
    s.add_dependency(%q<faraday>, [">= 0"])
    s.add_dependency(%q<faraday_middleware>, [">= 0"])
    s.add_dependency(%q<bundler>, [">= 0"])
    s.add_dependency(%q<shoulda>, [">= 0"])
    s.add_dependency(%q<test-unit>, ["= 2.5.0"])
    s.add_dependency(%q<mocha>, ["= 0.12.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.8.5"])
    s.add_dependency(%q<simplecov>, [">= 0"])
    s.add_dependency(%q<webmock>, ["~> 1.9.0"])
    s.add_dependency(%q<vcr>, [">= 0"])
    s.add_dependency(%q<pry>, [">= 0"])
  end
end
