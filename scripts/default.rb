#!/usr/bin/env ruby
#
#
require "./lib/greenbot.rb"
require "timeout"

HOUR = 60 * 60
timeout = ENV['CONVERSATION_TIMEOUT'].to_i || 1 * HOUR

begin
  Timeout::timeout(timeout) {
    tell "Thank you for texting us. This KISST bot is currently under construction. If you are looking for the owner of this number, I can take a message."
    if confirm("Would you like someone to contact you?")
      contact_me = true
      contact_me.remember("contact_me")
      name = ask("When we call, who should we ask for?")
      name.remember("who_to_ask_for")
      if confirm("Is there another number we should try?")
        better_number = ask("Please enter that number with an area code")
        better_number.remember("better_number")
      end
    end
    if confirm("Would you like to leave a message?")
      issue = note("How can we help you? Please use as many messages as you need.")
      tell "Thank you. We will forward the message."
    end
  }
rescue Timeout::Error  => e
  tell "If you want to restart this conversation, text us again!"
end
tell "Goodbye."
