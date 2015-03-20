#!/usr/bin/env ruby
#
#
require "./lib/greenbot.rb"
require "timeout"

HOUR = 60 * 60
timeout = ENV['CONVERSATION_TIMEOUT'].to_i || 4 * HOUR

begin
  Timeout::timeout(timeout) {
    tell ENV['PROMPT_1']
    issue = note(ENV['PROMPT_2'])
    if confirm("Would you like someone to contact you?")
      contact_me = true
      contact_me.remember("contact_me")
      name = ask("When we call, who should we ask for?")
      name.remember("who_to_ask_for")
      if confirm("Is there another number we should try?")
        better_number = ask("Please enter that number with an area code")
        better_number.remember("better_number")
      end
    else
      tell("No problem at all.")
    end
    tell ENV['PROMPT_3']
  }
rescue Timeout::Error  => e
  tell "If you want to restart this conversation, text us again!"
end
tell ENV['SIGNATURE']
