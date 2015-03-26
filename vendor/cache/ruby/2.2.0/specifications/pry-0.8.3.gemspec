# -*- encoding: utf-8 -*-
# stub: pry 0.8.3 ruby lib

Gem::Specification.new do |s|
  s.name = "pry"
  s.version = "0.8.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["John Mair (banisterfiend)"]
  s.date = "2011-04-25"
  s.description = "attach an irb-like session to any object at runtime"
  s.email = "jrmair@gmail.com"
  s.executables = ["pry"]
  s.files = ["bin/pry"]
  s.homepage = "http://banisterfiend.wordpress.com"
  s.rubygems_version = "2.4.6"
  s.summary = "attach an irb-like session to any object at runtime"

  s.installed_by_version = "2.4.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<ruby_parser>, [">= 2.0.5"])
      s.add_runtime_dependency(%q<coderay>, [">= 0.9.7"])
      s.add_runtime_dependency(%q<slop>, [">= 1.5.3"])
      s.add_development_dependency(%q<bacon>, [">= 1.1.0"])
      s.add_runtime_dependency(%q<method_source>, [">= 0.4.0"])
    else
      s.add_dependency(%q<ruby_parser>, [">= 2.0.5"])
      s.add_dependency(%q<coderay>, [">= 0.9.7"])
      s.add_dependency(%q<slop>, [">= 1.5.3"])
      s.add_dependency(%q<bacon>, [">= 1.1.0"])
      s.add_dependency(%q<method_source>, [">= 0.4.0"])
    end
  else
    s.add_dependency(%q<ruby_parser>, [">= 2.0.5"])
    s.add_dependency(%q<coderay>, [">= 0.9.7"])
    s.add_dependency(%q<slop>, [">= 1.5.3"])
    s.add_dependency(%q<bacon>, [">= 1.1.0"])
    s.add_dependency(%q<method_source>, [">= 0.4.0"])
  end
end
