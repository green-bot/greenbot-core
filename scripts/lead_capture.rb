#!/usr/bin/env ruby
#
#
require './lib/greenbot.rb'

# Extend string to include the opposite of empty
def ptell(prompt)
  return if prompt.empty?
  tell prompt
end

def pask(prompt, name)
  return if prompt.empty?
  answer = ask(prompt)
  answer.remember(name)
end

WAIT_TIMER = 20

tell ENV['PROMPT_1']
sleep WAIT_TIMER
ptell ENV['PROMPT_2']
sleep WAIT_TIMER

pask ENV['NAME_PROMPT'], 'name'
pask ENV['ZIP_PROMPT'], 'zip'
pask ENV['EMAIL_PROMPT'], 'email'

ptell ENV['THANK_YOU_PROMPT']
sleep WAIT_TIMER

unless ENV['ADDITIONAL_PROMPT_Q'].empty?
  additional_answer = false
  if confirm(ENV['ADDITIONAL_PROMPT_Q'])
    additional_answer = true
    tell ENV['ADDITIONAL_PROMPT_Y']
  else
    tell ENV['ADDITIONAL_PROMPT_N']
  end
  additional_answer.remember('additional_answer')
  sleep WAIT_TIMER
end

ptell ENV['SIGNATURE']
