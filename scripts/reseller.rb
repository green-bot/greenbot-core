#!/usr/bin/env ruby
# The basic usage script from https://github.com/JEG2/highline.git
#
# basic_usage.rb
#
require "./lib/greenbot.rb"
require "timeout"

HOUR = 60 * 60
timeout = ENV['CONVERSATION_TIMEOUT'].to_i || 4 * HOUR

begin
  Timeout::timeout(timeout) {
    tell ENV['PROMPT_1']
    tell ENV['PROMPT_2']
    begin
      tasks = %w(demos docs purchase contact quit )
      my_task = select("How can I help?", tasks)

      case my_task
      when "demos"
        tell ENV['DEMOS_PROMPT']
      when "docs"
        tell ENV['DOCS_PROMPT']
      when "purchase"
        tell ENV['PURCHASE_PROMPT']
      when "contact"
          if confirm("Would you like someone to contact you?")
            contact_me = true
            contact_me.remember("contact_me")
            name = ask("When we call, who should we ask for?")
            name.remember("who_to_ask_for")
            if confirm("Is there another number we should try?")
              better_number = ask("Please enter that number with an area code")
              better_number.remember("better_number")
            end
            tell "Thank you! We will have somebody contact you right away."
          else
            tell("No problem at all.")
            contact_me = false
            contact_me.remember("contact_me")
          end
      when "quit"
        break
      end
    end while true
  }
rescue Timeout::Error  => e
  tell "If you want to restart this conversation, text us again!"
end
tell ENV['SIGNATURE']
