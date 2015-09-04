#!/usr/bin/env ruby
#
#
require './lib/greenbot.rb'

CONFIRMATION_PROMPT = ENV['CONFIRMATION_PROMPT']
NAME_PROMPT = ENV['NAME_PROMPT']
OTHER_CONTACT_CONFIRM = ENV['OTHER_CONTACT_CONFIRM']
OTHER_CONTACT_PROMPT = ENV['OTHER_CONTACT_PROMPT']
NOTE_PROMPT = ENV['NOTE_PROMPT']

tell ENV['PROMPT_1']
tell ENV['PROMPT_2']
if confirm(CONFIRMATION_PROMPT)
  confirmed = true
  confirmed.remember('confirmed')
  name = ask(NAME_PROMPT)
  name.remember('name')
  if confirm(OTHER_CONTACT_CONFIRM)
    other_contact = ask(OTHER_CONTACT_PROMPT)
    other_contact.remember('other_contact')
  end
  issue = note(NOTE_PROMPT)
  issue.remember('note')
else
  tell('No problem at all.')
end
tell ENV['SIGNATURE']
