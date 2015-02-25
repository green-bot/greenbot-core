#!/usr/bin/env ruby
# The basic usage script from https://github.com/JEG2/highline.git
#
# admin.rb
#
require "./lib/greenbot.rb"
require "timeout"
require 'open3'
require 'pry'
require 'nexmo'
require 'json'

HOUR = 60 * 60
timeout = ENV['CONVERSATION_TIMEOUT'].to_i || 4 * HOUR

begin
  nexmo = Account.new
  Timeout::timeout(timeout) {
    tell "Thank you for being our customer! Let's configure your bot."
    script = get_script
    create_redis_key(ENV["DST"], script)
    bot = Room.new(number)
    manage_settings(bot)
    create_settings(bot)
    emails = bot.notification_emails
    new_email = confirmed_gets("Please give me the email to send the results to.")
    emails << new_email.downcase
    bot.publish
    tell "Thanks! Your bot is now setup for you. When you text in again, you'll be able to configure this number."
    tell "If you would like to test this number, text from a different cell phone, or text me again to start, and select test. Bye!"
rescue Timeout::Error  => e
  tell "If you want to restart this conversation, text us again!"
end
