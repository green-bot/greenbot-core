# -*- encoding: utf-8 -*-
# stub: rubygems-bundler 1.4.4 ruby lib

Gem::Specification.new do |s|
  s.name = "rubygems-bundler"
  s.version = "1.4.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Josh Hull", "Michal Papis"]
  s.date = "2014-06-06"
  s.description = "Stop using bundle exec. Integrate Rubygems and Bundler. Make rubygems generate bundler aware executable wrappers."
  s.email = ["joshbuddy@gmail.com", "mpapis@gmail.com"]
  s.homepage = "http://mpapis.github.com/rubygems-bundler"
  s.licenses = ["Apache-2.0"]
  s.rubygems_version = "2.4.5"
  s.summary = "Stop using bundle exec"

  s.installed_by_version = "2.4.5" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<bundler-unload>, [">= 1.0.2"])
      s.add_runtime_dependency(%q<executable-hooks>, [">= 1.3.2"])
      s.add_development_dependency(%q<tf>, [">= 0"])
    else
      s.add_dependency(%q<bundler-unload>, [">= 1.0.2"])
      s.add_dependency(%q<executable-hooks>, [">= 1.3.2"])
      s.add_dependency(%q<tf>, [">= 0"])
    end
  else
    s.add_dependency(%q<bundler-unload>, [">= 1.0.2"])
    s.add_dependency(%q<executable-hooks>, [">= 1.3.2"])
    s.add_dependency(%q<tf>, [">= 0"])
  end
end
