#!/usr/bin/env ruby
#
#
require "./lib/greenbot.rb"
require "timeout"

HOUR = 60 * 60
timeout = ENV['CONVERSATION_TIMEOUT'].to_i || 4 * HOUR

WELCOME_PROMPT = ENV['WELCOME_PROMPT'] || 'Thank you for reaching out to Liz Bone. Visit bit.ly/1NBjaUe to connect to my current listings'
HELP_PROMPT = ENV['HELP_PROMPT'] || 'I hope you find this automated service helpful, it will email me when the conversation is complete.'
NOTE_PROMPT = ENV['NOTE_PROMPT'] || 'How can I help you? Please send as many messages as you need.'
OTHER_CONTACT_PROMPT = ENV['FOLLOWUP_PROMPT'] || 'I will follow up with you promptly. Is there another number I should try?'
SIGNATURE = ENV['SIGNATURE'] || 'Thank you for texting Liz Bone. I will followup as soon as possible. This conversation is complete.'

begin
  Timeout::timeout(timeout) {
    tell WELCOME_PROMPT
    tell HELP_PROMPT
    sleep 5
    issue = note(NOTE_PROMPT)
    issue.remember('issue')
    if confirm(OTHER_CONTACT_PROMPT)
      better_number = ask("Please enter that number with an area code")
      better_number.remember("better_number")
    end
  }
rescue Timeout::Error  => e
  tell "If you want to restart this conversation, text us again!"
end
tell SIGNATURE
