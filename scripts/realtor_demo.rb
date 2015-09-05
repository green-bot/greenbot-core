#!/usr/bin/env ruby
#
#
require "./lib/greenbot.rb"

WELCOME_PROMPT = ENV['WELCOME_PROMPT']
HELP_PROMPT = ENV['HELP_PROMPT']
NOTE_PROMPT = ENV['NOTE_PROMPT']
OTHER_CONTACT_PROMPT = ENV['FOLLOWUP_PROMPT']
SIGNATURE = ENV['SIGNATURE']

tell WELCOME_PROMPT
tell HELP_PROMPT
sleep 5
issue = note(NOTE_PROMPT)
issue.remember('issue')
if confirm(OTHER_CONTACT_PROMPT)
  better_number = ask("Please enter that number with an area code")
  better_number.remember("better_number")
end
tell SIGNATURE
