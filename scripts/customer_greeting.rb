#!/usr/bin/env ruby
#
#
require './lib/greenbot.rb'

EVENT_MESSAGE = ENV['EVENT_MESSAGE'] || '' 
GREETING = ENV['GREETING'] || "Thank you for texting Century Link."
NOTE_PROMPT = ENV['NOTE_PROMPT'] || 'How can we help? (Send a single Q when done)'
SIGNATURE = ENV['SIGNATURE'] || 'Stand by for help from one of my human helpers.'

tell GREETING
issue = note(NOTE_PROMPT)
issue.remember('note')

tell SIGNATURE
