#!/usr/bin/env ruby
# The basic usage script from https://github.com/JEG2/highline.git
#
require './lib/greenbot.rb'

tell ENV['PROMPT_1']
tell ENV['PROMPT_2']
begin
  tasks = ENV['MENU_CHOICES'].split(',').map(&:strip)
  tasks << 'quit'
  tasks << 'contactme'
  my_task = select(ENV['MENU_PROMPT'], tasks).downcase

  case my_task
  when 'contactme'
    if confirm(ENV['CONFIRM_CONTACT'])
      contact_me = true
      contact_me.remember('contact_me')
      name = ask(ENV['WHO_TO_ASK_FOR'])
      name.remember('who_to_ask_for')
      if confirm(ENV['PREFER_ALTERNATE_CONTACT'])
        better_number = ask(ENV['ALTERNATE_CONTACT_COLLECTION'])
        better_number.remember('better_number')
      end
    else
      tell(ENV['DONT_CONTACT_PROMPT'])
      contact_me = false
      contact_me.remember('contact_me')
    end
  when 'quit'
    break
  else
    case tasks.map(&:downcase).index(my_task)
    when 0
      tell ENV['FIRST_CHOICE']
    when 1
      tell ENV['SECOND_CHOICE']
    when 2
      tell ENV['THIRD_CHOICE']
    when 3
      tell ENV['FOURTH_CHOICE']
    end
  end
end while true
tell ENV['SIGNATURE']
