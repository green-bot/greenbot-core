#!/usr/bin/env ruby
#
#
require "./lib/greenbot.rb"
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
tell ENV['SIGNATURE']
