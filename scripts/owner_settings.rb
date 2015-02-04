#!/usr/bin/env ruby
# The basic usage script from https://github.com/JEG2/highline.git
#
# basic_usage.rb
#
require "./lib/greenbot.rb"
require "timeout"
require 'open3'

HOUR = 60 * 60
timeout = ENV['CONVERSATION_TIMEOUT'].to_i || 4 * HOUR

def show_balance
  package_amount = 25
  used = rand()*25
  puts("You have used #{used.to_int} out of #{package_amount} conversations.")
end

def offer_recharge
  if $room.env_settings["AUTO_CHARGE"] == "true"
    change = confirm("Would you like to turn auto charge off?")
    if change
      $room.env_settings["AUTO_CHARGE"] = "false"
      $room.publish
      puts("Auto recharge is now turned off. You will get a notification when your account balance goes low.")
    end 
  else
    change = confirm("Would you like to turn auto charge on?")
    if change
      $room.env_settings["AUTO_CHARGE"] = "true"
      $room.publish
      puts("Auto recharge is now turned on. You will get a notification when your account recharges.")
    end
  end
end

begin
  puts "Welcome Master. I can help you configure this number."
  Timeout::timeout(timeout) {
    begin
      tasks = %w(away balance settings test quit)
      my_task = select("What would you like to do?", tasks)
      case my_task
      when 'clone'
        clone = confirm("Do you want this same bot to be attached to another number?")
        if clone
          puts("This bot will also answer on 617-#{rand(1000).to_i}-#{rand(10000).to_i}")
        end
        
        #code
      when 'test'
        $room.set_test_mode
        puts("The next time you text in, you will use the actual bot so you can test it.")
        break
      when 'balance'
        show_balance
      when 'recharge'
        charge = confirm("Would you like to recharge your account?")
        if charge
          puts("Your account has been re-filled.")
        end
        offer_recharge
        show_balance
        
      when "quit"
        puts "Thanks! See you later!"
        break
      when "away"
        if $room.get_setting("AWAY") == "true"
          $room.update_setting("AWAY","false")
          puts "Away mode disabled"
        else
          $room.update_setting("AWAY","true")
          puts "Away mode enabled"
        end
        
      when "settings"
        config_paths = %w(all one show)
        config_option = select("You can configure all of the prompts, just one, print out their current values.", config_paths)
        case config_option
        when "show"
          puts "Here are the current settings:"
          $room.env_settings.each {|k,v|
            puts "#{k}:#{v}"
            }
        when "all"
          $room.env_settings.each {|k,v|
          unless confirm("#{k} is currently #{v}. Keep it?")
            $room.update_setting(k,confirmed_gets("Please give me the new value for #{k}."))
          end
          }
        when "one"
          key_name = select("Please select a setting to change", $room.env_settings.keys)
          change_it = confirm("That setting is currently : #{$room.get_setting(key_name)}. Change it?")
          if change_it
            new_value = confirmed_gets("Please give me the new value for #{key_name}.")
            $room.update_setting(key_name, new_value)
            puts("Changed setting to #{new_value}")
          end
        else
          say("Sorry, not quite sure what happend. Try again.")
        end
      end
    end while true
  }
rescue Timeout::Error  => e
  puts "If you want to restart this conversation, text us again!"
end

 
