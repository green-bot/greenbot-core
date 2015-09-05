#!/usr/bin/env ruby
# The basic usage script from https://github.com/JEG2/highline.git
#
# basic_usage.rb
#
require './lib/greenbot.rb'
require 'timeout'


def ask_and_remember(prompt, desc)
  response = ask(prompt)
  response.remember(desc)
  response
end

def confirm_and_remember(prompt, desc)
  response = confirm(prompt)
  response.remember(desc)
  response
end

def collect_contact(prompt)
  if confirm_and_remember(prompt, 'contact_me')
    ask_and_remember('When we call, who should we ask for?', 'who_to_ask_for')
    better = confirm_and_remember('Is there a better number?', 'try_alt_num')
    ask_and_remember('What number should I call?', 'alt_number') if better
    tell 'Thank you! We will have somebody contact you right away.'
  else
    tell('No problem at all.')
  end
end

tell ENV['PROMPT_1']
tell ENV['PROMPT_2']
collect_contact('Would you like someone to contact you?')
tell ENV['PURCHASE_PROMPT']
loop do
  tasks = %w(demos docs purchase contact reseller quit pricing )
  my_task = select('How can I help?', tasks)
  case my_task
  when 'demos'
    tell ENV['DEMOS_PROMPT']
  when 'docs'
    tell ENV['DOCS_PROMPT']
  when 'purchase'
    tell ENV['PURCHASE_PROMPT']
  when 'pricing'
    tell ENV['PRICING_PROMPT']
  when 'reseller'
    tell ENV['RESELLER_PROMPT']
    collect_contact('Would you like to become a KISST reseller?')
  when 'contact'
    collect_contact('Would you like someone to contact you?')
  when 'quit'
    break
  end
end
end
tell ENV['SIGNATURE']
