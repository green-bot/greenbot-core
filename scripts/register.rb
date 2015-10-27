#!/usr/bin/env ruby
#
#
require './lib/greenbot.rb'

def number_or_nil(string)
  Integer(string || '')
rescue ArgumentError
  nil
end

qty_limited = ENV['MAX_REGISTER_ONE_TIME']
qty = 0

tell ENV['WELCOME_PROMPT']
tell ENV['INFO_PROMPT']

if confirm(ENV['REGISTER_PROMPT'])
  name = ask(ENV['NAME_PROMPT'])
  name.remember('NAME_PROMPT')
  contact = ask(ENV['CONTACT_PROMPT'])
  contact.remember('CONTACT_PROMPT')
  tell ENV['PAYMENT_PROMPT'] if ENV['PAYMENT_PROMPT']
  if qty_limited && ENV['QTY_PROMPT']
    loop do
      qty_prompt = ENV['QTY_PROMPT'] || 'How many people are you registering?'
      response = ask(qty_prompt)
      qty = number_or_nil(response)
      break unless qty.nil? || (qty < 1)
      tell 'Sorry, we need a whole number greater than zero.'
    end
  else
    qty = 1
  end
  tell ENV['REGISTRATION_SUCCESS']
end
