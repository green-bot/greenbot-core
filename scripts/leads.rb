#!/usr/bin/env ruby
#
#
require "./lib/greenbot.rb"
require "timeout"

HOUR = 60 * 60
timeout = ENV['CONVERSATION_TIMEOUT'].to_i || 4 * HOUR
CONFIRMATION_PROMPT = ENV['CONFIRMATION_PROMPT'] || "Would you like someone to contact you?"
NAME_PROMPT = ENV['NAME_PROMPT'] || "When we call, who should we ask for?"
OTHER_CONTACT_CONFIRM = ENV['OTHER_CONTACT'] || "Is there another number we should try?"
OTHER_CONTACT_PROMPT = ENV['OTHER_CONTACT_PROMPT'] || "Please enter that number with an area code"
NOTE_PROMPT = ENV['NOTE_PROMPT'] || "How can we help you? Please use as many messages as you need."
begin
  Timeout::timeout(timeout) {
    tell ENV['PROMPT_1']
    tell ENV['PROMPT_2']
    if confirm(CONFIRMATION_PROMPT)
      confirmed = true
      confirmed.remember("confirmed")
      name = ask(NAME_PROMPT)
      name.remember("name")
      if confirm(OTHER_CONTACT_CONFIRM)
        other_contact = ask(OTHER_CONTACT_PROMPT)
        other_contact.remember("other_contact")
      end
      issue = note(NOTE_PROMPT)
    else
      tell("No problem at all.")
    end
  }
rescue Timeout::Error  => e
  tell "If you want to restart this conversation, text us again!"
end
tell ENV['SIGNATURE']
