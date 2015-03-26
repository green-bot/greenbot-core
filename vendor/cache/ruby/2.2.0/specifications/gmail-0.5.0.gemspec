# -*- encoding: utf-8 -*-
# stub: gmail 0.5.0 ruby lib

Gem::Specification.new do |s|
  s.name = "gmail"
  s.version = "0.5.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Chris Kowalik"]
  s.date = "2015-01-25"
  s.description = "A Rubyesque interface to Gmail, with all the tools you will need.\n  Search, read and send multipart emails; archive, mark as read/unread,\n  delete emails; and manage labels.\n  "
  s.email = ["chris@nu7hat.ch"]
  s.homepage = "http://github.com/gmailgem/gmail"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.4.6"
  s.summary = "A Rubyesque interface to Gmail, with all the tools you will need."

  s.installed_by_version = "2.4.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<mail>, [">= 2.2.1"])
      s.add_runtime_dependency(%q<gmail_xoauth>, [">= 0.3.0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<rspec>, [">= 3.1"])
      s.add_development_dependency(%q<rubocop>, [">= 0"])
      s.add_development_dependency(%q<gem-release>, [">= 0"])
    else
      s.add_dependency(%q<mail>, [">= 2.2.1"])
      s.add_dependency(%q<gmail_xoauth>, [">= 0.3.0"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<rspec>, [">= 3.1"])
      s.add_dependency(%q<rubocop>, [">= 0"])
      s.add_dependency(%q<gem-release>, [">= 0"])
    end
  else
    s.add_dependency(%q<mail>, [">= 2.2.1"])
    s.add_dependency(%q<gmail_xoauth>, [">= 0.3.0"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<rspec>, [">= 3.1"])
    s.add_dependency(%q<rubocop>, [">= 0"])
    s.add_dependency(%q<gem-release>, [">= 0"])
  end
end
