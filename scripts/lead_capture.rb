#!/usr/bin/env ruby
#
#
require './lib/greenbot.rb'

tell ENV['PROMPT_1']
tell ENV['PROMPT_2'] if ENV['PROMPT_2']

name = ask(ENV['NAME_PROMPT'])
name.remember('name')
zip_prompt = ask(ENV['ZIP_PROMPT'])
zip_prompt.remember('zip_prompt')
email_prompt = ask(ENV['EMAIL_PROMPT'])
email_prompt.remember('email_prompt')

tell ENV['THANK_YOU_PROMPT']

additional_answer = false
if confirm(ENV['ADDITIONAL_PROMPT_Q'])
  additional_answer = true
  tell ENV['ADDITIONAL_PROMPT_Y']
else
  tell ENV['ADDITIONAL_PROMPT_N']
end
additional_answer.remember('additional_answer')

tell ENV['SIGNATURE']
