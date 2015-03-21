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
  tell "If you don't know what sort of job you want your bot to do, check out our knowledge base at http://kisst.zendesk.com."
  tell "Changing bot types is really simple. To change it after initial setup, text into this number and choose bot from the main menu."
  scripts = Room.scripts
  sortof_bot = select("What sort of bot do you want to deploy?", scripts.collect{|s| s["name"] })
  script = scripts.detect{|s| s["name"] == sortof_bot}
  $room.assign(script["objectId"])
end

begin
  if $room.not_setup?
    tell "Hi! Welcome to your brand-new bot. First time? We've got a mobile site with videos and tutorials to get you started at http://kisst.zendesk.com"
    assign_bot
    tell "From now on, when you text into this bot from this cell phone, you will be able to change settings, prompts, etc. Everyone else has the normal conversation."
    tell "You can add other cell phones as owners by selecting owner from the main menu."
  else
    tell "Hello, #{ENV['SRC']}. Because this cell phone is on the owners list, when you text in you can configure this bot."
    tell "If you want to test your changes, text test to turn this script off for one conversation."
  end

  Timeout::timeout(timeout) {
    begin
      tasks = %w(away bot email help owner settings test quit)
      my_task = select("Main Menu: What would you like to configure?", tasks)
      case my_task
        #code

      when 'email'
        email_choices = %w(add remove show)
        email_choice = select("Email: Conversations are mailed when complete. You can add another recipient, remove one, or show them all.", email_choices)
        case email_choice
        when "show"
          tell("Email: The current recipients are #{$room.notification_emails.join(",")}")

        when "add"
          new_notification_email = confirmed_gets("Email: Please give me the email to add to the recipient list.")
          $room.notification_emails << new_notification_email.downcase
          $room.publish
        when "remove"
          deleted_email = confirmed_gets("Email: Please give me the email of the recipient to remove.")
          $room.notification_emails.delete_if {|o| o.downcase == deleted_email.downcase}
          $room.publish
        end

      when 'help'
        tell "Help: Online help is available right from your mobile browser at https://kisst.zendesk.com"

      when 'bot'
        if confirm("Bot: Do you want to change the sort of job your bot will do? You will lose your settings.")
          assign_bot
        end

      when 'test'
        $room.set_test_mode
        tell("Test: The next time you text in, you will have the public conversation so you can test your settings.")
        tell("Test: To end a conversation at anytime, send /quit. To start a new conversation, just text me again.")
        break

      when "quit"
        tell "Thanks! See you later!"
        break
      when "away"
        if $room.get_setting("AWAY") == "true"
          $room.update_setting("AWAY","false")
          tell "Away: Away mode disabled"
        else
          $room.update_setting("AWAY","true")
          tell "Away: Away mode enabled"
        end
      when "owner"
        owner_choices = %w(add remove show)
        owner_choice = select("Owner: You can add the cell phone of a new owner, remove one, or show them all.", owner_choices)
        case owner_choice
        when "show"
          tell("Owner: The current owners are #{$room.owners.join(",")}")

        when "add"
          new_owner = confirmed_gets("Owner: Please give me the phone number of the new owner")
          $room.owners << new_owner.downcase
          $room.publish
        when "remove"
          deleted_owner = confirmed_gets("Owner: Please give me the phone number of the owner to remove")
          if deleted_owner.downcase == ENV['SRC'].downcase
            tell("Sorry, but you are not allowed to remove yourself.")
          else
            $room.owners.delete_if {|o| o.downcase == deleted_owner.downcase}
            $room.publish
          end
        end
      when "settings"
        config_paths = %w(all one show)
        config_option = select("Settings: You can configure all of the prompts, just one, or show their current values.", config_paths)
        case config_option
        when "show"
          tell "Settings: Here are the current settings:"
          $room.env_settings.each {|k,v|
            tell "#{k}:#{v}"
            }
        when "all"
          $room.env_settings.each {|k,v|
          unless confirm("Settings: #{k} is currently #{v}. Keep it?")
            $room.update_setting(k,confirmed_gets("Settings: Please give me the new value for #{k}."))
          end
          }
        when "one"
          key_name = select("Settings: Please select a setting to change", $room.env_settings.keys)
          change_it = confirm("Settings: That setting is currently : #{$room.get_setting(key_name)}. Change it?")
          if change_it
            new_value = confirmed_gets("Settings: Please give me the new value for #{key_name}.")
            $room.update_setting(key_name, new_value)
            tell("Settings: Changed setting to #{new_value}")
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
