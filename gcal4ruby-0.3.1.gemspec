# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{gcal4ruby}
  s.version = "0.3.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Mike Reich", "Matt Gornick"]
  s.date = %q{2010-02-18}
  s.description = %q{A full featured wrapper for interacting with the Google Calendar API}
  s.email = %q{mike@seabourneconsulting.com}
  s.files = ["README", "CHANGELOG", "lib/gcal4ruby.rb", "lib/gcal4ruby/base.rb", "lib/gcal4ruby/service.rb", "lib/gcal4ruby/calendar.rb", "lib/gcal4ruby/event.rb", "lib/gcal4ruby/recurrence.rb", "test/unit.rb"]
  s.homepage = %q{http://github.com/mgornick/gcal4ruby}
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{gcal4ruby}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{A full featured wrapper for interacting with the Google Calendar API.  This is a new branch to written by Matt Gornick in incorporate Google Authsub into the Authentication}
  s.test_files = ["test/unit.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
