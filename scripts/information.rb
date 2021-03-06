#!/usr/bin/env ruby
# The basic usage script from https://github.com/JEG2/highline.git
#
# basic_usage.rb
#
require './lib/greenbot.rb'

tell ENV['PROMPT_1']
tell ENV['PROMPT_2']
begin
  tasks = %w(hours specials address contact quit )
  my_task = select('How can I help?', tasks)

  case my_task
  when 'hours'
    tell ENV['HOURS']
  when 'specials'
    tell ENV['SPECIALS']
  when 'address'
    tell ENV['ADDRESS']
  when 'contact'
      if confirm('Would you like someone to contact you?')
        contact_me = true
        contact_me.remember('contact_me')
        name = ask('When we call, who should we ask for?')
        name.remember('who_to_ask_for')
        if confirm('Is there another number we should try?')
          better_number = ask('Please enter that number with an area code')
          better_number.remember('better_number')
        end
      else
        tell('No problem at all.')
        contact_me = false
        contact_me.remember('contact_me')
      end
  when 'quit'
    break
  end
end while true
tell ENV['SIGNATURE']
