# -*- encoding: utf-8 -*-
# stub: gmail_xoauth 0.4.1 ruby lib

Gem::Specification.new do |s|
  s.name = "gmail_xoauth"
  s.version = "0.4.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.6") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Nicolas Fouch\u{e9}"]
  s.date = "2012-09-16"
  s.description = "Get access to Gmail IMAP and STMP via OAuth, using the standard Ruby Net libraries"
  s.email = ["nicolas.fouche@gmail.com"]
  s.homepage = "https://github.com/nfo/gmail_xoauth"
  s.rdoc_options = ["--charset=UTF-8"]
  s.rubygems_version = "2.4.6"
  s.summary = "Get access to Gmail IMAP and STMP via OAuth, using the standard Ruby Net libraries"

  s.installed_by_version = "2.4.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<oauth>, [">= 0.3.6"])
      s.add_development_dependency(%q<shoulda>, [">= 0"])
    else
      s.add_dependency(%q<oauth>, [">= 0.3.6"])
      s.add_dependency(%q<shoulda>, [">= 0"])
    end
  else
    s.add_dependency(%q<oauth>, [">= 0.3.6"])
    s.add_dependency(%q<shoulda>, [">= 0"])
  end
end
