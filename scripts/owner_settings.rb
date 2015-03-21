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
  tell("You have used #{used.to_int} out of #{package_amount} conversations.")
end

def offer_recharge
  if $room.env_settings["AUTO_CHARGE"] == "true"
    change = confirm("Would you like to turn auto charge off?")
    if change
      $room.env_settings["AUTO_CHARGE"] = "false"
      $room.publish
      tell("Auto recharge is now turned off. You will get a notification when your account balance goes low.")
    end
  else
    change = confirm("Would you like to turn auto charge on?")
    if change
      $room.env_settings["AUTO_CHARGE"] = "true"
      $room.publish
      tell("Auto recharge is now turned on. You will get a notification when your account recharges.")
    end
  end
end

def assign_bot
  tell "If you don't know what sort of job you want your bot to do, check this out first (http://www.bit.ly/AVDSfS)"
  scripts = Room.scripts
  sortof_bot = select("What sort of bot do you want to deploy?", scripts.collect{|s| s["name"] })
  script = scripts.detect{|s| s["name"] == sortof_bot}
  $room.assign(script["objectId"])
end

begin
  if $room.not_setup?
    tell "Hi! Welcome to your bot. If this is your first time, we've got a mobile site with videos and tutorials to get you started."
    assign_bot
    tell "From now on, when you text into your bot, you will be able to change settings, prompts, etc."
  else
    tell "Hello, #{ENV['SRC']} I can help you configure this number."
  end

  Timeout::timeout(timeout) {
    begin
      tasks = %w(away bot email help owner settings test quit)
      my_task = select("What would you like to do?", tasks)
      case my_task
        #code

      when 'email'
        email_choices = %w(add remove show)
        email_choice = select("Conversations are mailed when complete. You can add another recipient, remove one, or show them all.", email_choices)
        case email_choice
        when "show"
          tell("The current recipients are #{$room.notification_emails.join(",")}")

        when "add"
          new_notification_email = confirmed_gets("Please give me the email to add to the recipient list.")
          $room.notification_emails << new_notification_email.downcase
          $room.publish
        when "remove"
          deleted_email = confirmed_gets("Please give me the email of the recipient to remove.")
          $room.notification_emails.delete_if {|o| o.downcase == deleted_email.downcase}
          $room.publish
        end

      when 'help'
        tell "Online help is available right from your mobile browser at https://kisst.zendesk.com"

      when 'bot'
        if confirm("Do you want to change the sort of job your bot will do? You will lose your settings.")
          assign_bot
        end

      when 'test'
        $room.set_test_mode
        tell("The next time you text in, you will use the actual bot so you can test it.")
        break

      when "quit"
        tell "Thanks! See you later!"
        break
      when "away"
        if $room.get_setting("AWAY") == "true"
          $room.update_setting("AWAY","false")
          tell "Away mode disabled"
        else
          $room.update_setting("AWAY","true")
          tell "Away mode enabled"
        end
      when "owner"
        owner_choices = %w(add remove show)
        owner_choice = select("You can add a new owner, remove one, or show them all.", owner_choices)
        case owner_choice
        when "show"
          tell("The current owners are #{$room.owners.join(",")}")

        when "add"
          new_owner = confirmed_gets("Please give me the phone number of the new owner")
          $room.owners << new_owner.downcase
          $room.publish
        when "remove"
          deleted_owner = confirmed_gets("Please give me the phone number of the owner to remove")
          if deleted_owner.downcase == ENV['SRC'].downcase
            tell("Sorry, but you are not allowed to remove yourself.")
          else
            $room.owners.delete_if {|o| o.downcase == deleted_owner.downcase}
            $room.publish
          end
        end
      when "settings"
        config_paths = %w(all one show)
        config_option = select("You can configure all of the prompts, just one, print out their current values.", config_paths)
        case config_option
        when "show"
          tell "Here are the current settings:"
          $room.env_settings.each {|k,v|
            tell "#{k}:#{v}"
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
            tell("Changed setting to #{new_value}")
          end
        else
          say("Sorry, not quite sure what happend. Try again.")
        end
      end
    end while true
  }
rescue Timeout::Error  => e
  tell "If you want to restart this conversation, text us again!"
end
