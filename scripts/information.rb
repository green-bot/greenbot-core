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
    puts ENV['PROMPT_1']
    puts ENV['PROMPT_2']

    puts("How can I help? (Hours, Specials, Address, Contact, Quit)")
    choice = gets
    choice.downcase!
    choice.remember("choice")

    case choice.each_char.first
    when "h"
      puts ENV['HOURS']
    when "s"
      puts ENV['SPECIALS']
    when "a"
      puts ENV['ADDRESS']
    when "c"
        if agree("Would you like someone to contact you?", false)
          contact_me = true
          contact_me.remember("remember_me")
          name = ask("When we call, who should we ask for?")
          name.remember("who_to_ask_for")
          if agree("Is there another number we should try?", false)
            better_number = ask("Please enter that number with an area code", 
                                 lambda { |p| p.delete("^0-9").
                                                sub(/\A(\d{3})/, '(\1) ').
                                                sub(/(\d{4})\Z/, '-\1') } ) do |q|
                              q.validate = lambda { |p| p.delete("^0-9").length == 10 }
                              q.responses[:not_valid] = "Enter a phone numer with area code."
                            end
             better_number.remember("better_number")
          end
        else
          puts("No problem at all.")
        end
    end
    puts ENV['SIGNATURE']
  }
rescue Timeout::Error  => e
  puts "If you want to restart this conversation, text us again!"
  puts ENV['SIGNATURE']
end

 
