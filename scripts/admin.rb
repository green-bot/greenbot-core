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
require 'awesome_print'
require 'json'

HOUR = 60 * 60
timeout = ENV['CONVERSATION_TIMEOUT'].to_i || 4 * HOUR

class Account
    def initialize(key = ENV['NEXMO_KEY'], secret = ENV['NEXMO_SECRET'])
      @client = Nexmo::Client.new(key: key, secret: secret)
    end
    def fetch_numbers
      begin
        area_code = confirmed_gets("What pattern (like area code) should I search for?")
        available_numbers = @client.number_search("US", {
          pattern: area_code.to_i,
          search_pattern: 1,
          features: "SMS, VOICE"
          })
        tell "No numbers available with that pattern. Please try again." if available_numbers.empty?
      end while available_numbers.empty?
      return available_numbers["numbers"].map{|n| n["msisdn"]}
    end
    def purchase_number(number)
      @client.buy_number({
        country: "US",
        msisdn: number
        })
    end
    def account_numbers
      account_numbers = @client.get_account_numbers({})
      account_numbers["numbers"].map{|n| n["msisdn"]}
    end
    def point_voice(account_number, voice_number)
      @client.update_number({
        country: "US",
        msisdn: account_number,
        voiceCallbackType: "tel",
        voiceCallbackValue: voice_number
        })
    end
end

def get_script
  scripts = $r.keys("scripts:*").each {|s| s.gsub!("scripts:","")}
  scripts << "cancel"
  script = select("Please select which script you'd like to attach to this number", scripts)
  return script
end

def pick_bot
  rooms = $r.keys("room*").each {|k| k.gsub!("room:","")}
  number = ask "What number would you like to configure?"
  if number == "show" or not rooms.include? number
    number = select "Here are the current numbers you can configure. Pick one", rooms
  end
  bot = Room.new(number)
end

def create_redis_key(number_to_provision, script)
  template = $r.get "scripts:#{script}"
  settings = JSON.parse template
  settings["owners"] << confirmed_gets("Please give us the cell phone number of the owner, including the 1 and area code.")
  while confirm("Are there are any other cell phones that should be owners?")
    settings["owners"] << confirmed_gets("Please give us the cell phone number of the owner, including the 1 and area code")
  end
  settings["notification_emails"] << confirmed_gets("Please give us the email address that we should email conversations to.")
  while confirm("Are there are any other email addresses?")
    settings["notification_emails"] << confirmed_gets("Please give us the email address that we should email conversations to.")
  end
  $r.set("room:#{number_to_provision}",settings.to_json)
end

def manage_settings(bot)
  config_paths = %w(all one show)
  config_option = select("You can configure all of the prompts, just one, print out their current values.", config_paths)
  case config_option
  when "show"
    tell "Here are the current settings:"
    bot.env_settings.each {|k,v|
      tell "#{k}:#{v}"
      }
  when "all"
    bot.env_settings.each {|k,v|
    unless confirm("#{k} is currently #{v}. Keep it?")
      bot.update_setting(k,confirmed_gets("Please give me the new value for #{k}."))
    end
    }
  when "one"
    key_name = select("Please select a setting to change", bot.env_settings.keys)
    change_it = confirm("That setting is currently : #{bot.get_setting(key_name)}. Change it?")
    if change_it
      new_value = confirmed_gets("Please give me the new value for #{key_name}.")
      bot.update_setting(key_name, new_value)
      tell("Changed setting to #{new_value}")
    end
  end
end

begin
  nexmo = Account.new
  begin
    passcode = ask "Passcode required"
  end until passcode == "6578"
  Timeout::timeout(timeout) {
    begin
      tasks = %w(describe email new bots owner assign settings voice quit help)
      my_task = select("What would you like to do?", tasks)
      case my_task
      when "help"
        tell "assign: assigns an existing network connection to a new type of bot"
        tell "bots: shows the active bots on this account, and refreshes the number database"
        tell "describe: describes a bot"
        tell "emails: sets the notification_emails for a bot"
        tell "new: creates a new bot and connects it to the network."
        tell "owner: manages the owners for a bot"
        tell "quit: ends this conversation"
        tell "settings: manages the settings for a bot"
        tell "voice: sets what phone rings when somebody calls this bot."

      when "describe"
        numbers = nexmo.account_numbers
        begin
          number = confirmed_gets("Which bot do you want to know about? Text cancel if you'd like to go back")
          valid = numbers.include?(number) || number.downcase == "cancel"
          tell "That is not a valid choice" unless valid
        end until valid
        unless number.downcase == "cancel"
          bot = Room.new(number)
          tell "Owners: #{bot.owners}"
          tell "Emails: #{bot.notification_emails}"
        else
          tell "Transaction cancelled"
        end

      when "voice"
        numbers = nexmo.account_numbers
        begin
          number = confirmed_gets("What number should I assign the voice for? Text cancel if you'd like to go back")
          valid = numbers.include?(number) || number.downcase == "cancel"
          tell "That is not a valid number" unless valid
        end unless valid
        unless number == "cancel"
          voice_number = confirmed_gets("When somebody calls #{number}, what other number should ring?")
          nexmo.point_voice(number, voice_number)
        else
          tell "Transaction cancelled."
        end

      when "bots"
        numbers = nexmo.account_numbers
        numbers.each{|n| $r.sadd("NEXMO_NUMBERS", n)}
        unless numbers.empty?
          tell numbers.join(",")
        else
          tell "This account has no numbers"
        end
      when "assign"
        numbers = nexmo.account_numbers
        begin
          number = confirmed_gets("Which bot should I assign? Text cancel if you'd like to go back")
          valid = numbers.include?(number) || number.downcase == "cancel"
          tell "That is not a valid choice" unless valid
        end unless valid
        unless number.downcase == "cancel"
          script = get_script
          create_redis_key(number, script)
          bot = Room.new(number)
          manage_settings(bot)
        else
          tell "Transaction cancelled"
        end
      when "quit"
        tell "Thanks! See you later!"
        break
      when "new"
        if confirm("Would you like to create a new bot?")
          available_numbers = nexmo.fetch_numbers()
          available_numbers << "cancel"
          number_to_provision = select("Please pick which you would like", available_numbers)
          unless (number_to_provision == "cancel")
            script = get_script
            unless(script == "cancel")
              nexmo.purchase_number(number_to_provision)
              create_redis_key(number_to_provision, script)
              bot = Room.new(number_to_provision)
              manage_settings(bot)
            else
              tell "No problem."
            end
          else
            tell "No problem."
          end
        end
      when "owner"
        bot = pick_bot
        owner_choices = %w(add remove show)
        owner_choice = select("You can add a new owner, remove one, or show them all.", owner_choices)
        case owner_choice
        when "show"
          tell("The current owners are #{bot.owners.join(',')}")

        when "add"
          new_owner = confirmed_gets("Please give me the phone number of the new owner")
          bot.owners << new_owner.downcase
          bot.publish
        when "remove"
          deleted_owner = confirmed_gets("Please give me the phone number of the owner to remove")
          if deleted_owner.downcase == ENV['SRC'].downcase
            tell("Sorry, but you are not allowed to remove yourself.")
          else
            bot.owners.delete_if {|o| o.downcase == deleted_owner.downcase}
            bot.publish
          end
        end
      when "email"
        bot = pick_bot
        email_choices = %w(add remove show)
        emails = bot.notification_emails
        email_choice = select("You can add a new email, remove one, or show them all.", email_choices)
        case email_choice
        when "show"
          tell("The current emails are #{emails.join(',')}")

        when "add"
          new_email = confirmed_gets("Please give me the new email")
          emails << new_email.downcase
          bot.publish
        when "remove"
          deleted_email = confirmed_gets("Please give me the email to remove")
          emails.delete_if {|e| e.downcase == deleted_email.downcase}
          bot.publish
        end

      when "settings"
        bot = pick_bot
        manage_settings(bot)
      end
    end while true
  }
rescue Timeout::Error  => e
  tell "If you want to restart this conversation, text us again!"
end
