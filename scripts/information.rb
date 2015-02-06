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
  puts ENV['PROMPT_1']
  puts ENV['PROMPT_2']
  Timeout::timeout(timeout) {
    begin
      tasks = %w(hours specials address contact quit)
      my_task = select("How can I help?", tasks)

      case my_task
      when "hours"
        puts ENV['HOURS']
      when "specials"
        puts ENV['SPECIALS']
      when "address"
        puts ENV['ADDRESS']
      when "contact"
          if confirm("Would you like someone to contact you?")
            contact_me = true
            contact_me.remember("remember_me")
            puts("When we call, who should we ask for?")
            name = gets.chomp
            name.remember("who_to_ask_for")
            if confirm("Is there another number we should try?")
              puts("Please enter that number with an area code")
              better_number = gets.chomp
              better_number.remember("better_number")
            end
          else
            puts("No problem at all.")
          end
      when "quit"
        break
      end
    end while true
  }
rescue Timeout::Error  => e
  puts "If you want to restart this conversation, text us again!"
end
puts ENV['SIGNATURE']
