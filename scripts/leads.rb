#!/usr/bin/env ruby
#
#
require './lib/greenbot.rb'

CONFIRMATION_PROMPT = ENV['CONFIRMATION_PROMPT'] || 'Would you like someone to contact you?'
NAME_PROMPT = ENV['NAME_PROMPT'] || 'Who should we ask for?'
OTHER_CONTACT_CONFIRM = ENV['OTHER_CONTACT_CONFIRM'] || 'Is there another way you would like to be contacted?'
OTHER_CONTACT_PROMPT = ENV['OTHER_CONTACT_PROMPT'] || 'How else would you like to be contacted?'
NOTE_PROMPT = ENV['NOTE_PROMPT'] || 'Please tell us how we can help. Send a single Q to quit'

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
