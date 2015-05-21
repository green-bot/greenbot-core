#!/usr/bin/env ruby
#
#
require "./lib/greenbot.rb"
require "timeout"

def number_or_nil(string)
  Integer(string || '')
rescue ArgumentError
  nil
end


HOUR = 60 * 60
timeout = ENV['CONVERSATION_TIMEOUT'].to_i || 4 * HOUR

qty_limited = ENV['MAX_REGISTER_ONE_TIME']
max_amount = ENV['MAX_REGISTER_ONE_TIME'].gsub(/[^0-9]/,'').to_i
max_amount = max_amount < 0 ? 0 : max_amount
spots_left = $room.qty
qty = 0

begin
  Timeout::timeout(timeout) {
    tell ENV['WELCOME_PROMPT']
    tell ENV['INFO_PROMPT']
    if spots_left < 1
      tell ENV['CLASS_FULL']
      return
    end

    if confirm(ENV['REGISTER_PROMPT'])
      name = ask(ENV['NAME_PROMPT'])
      name.remember("NAME_PROMPT")
      contact = ask(ENV['CONTACT_PROMPT'])
      contact.remember("CONTACT_PROMPT")
      if ENV['PAYMENT_PROMPT']
        tell ENV['PAYMENT_PROMPT']
      end
      if qty_limited && ENV['QTY_PROMPT']
        loop do
          qty_prompt = ENV['QTY_PROMPT'] || "How many people are you registering?"
          response = ask(qty_prompt)
          qty = number_or_nil(response)
          break unless qty.nil? || (qty < 1)
          tell "Sorry, we need a whole number greater than zero."
        end
      else
        qty = 1
      end
      $room.subtract_qty(qty)
      tell ENV['REGISTRATION_SUCCESS']
    end
  }
rescue Timeout::Error  => e
  tell "If you want to restart this conversation, text us again!"
end
tell ENV['SIGNATURE']
