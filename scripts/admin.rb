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

def fetch_passcode()
  $r.get("PASSCODE") || "6578"
end

def set_passcode(passcode)
  $r.set("PASSCODE",  passcode)
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



HOUR = 60 * 60
timeout = ENV['CONVERSATION_TIMEOUT'].to_i || 4 * HOUR

begin
  nexmo = Account.new
  begin
    passcode = ask "Passcode required"
  end until passcode == fetch_passcode()
  Timeout::timeout(timeout) {
    begin
      tasks = %w(clone describe email new bots orphaned owner passcode assign settings voice quit help)
      my_task = select("What would you like to do?", tasks)
      case my_task
      when "help"
        tell "assign: assigns an existing network connection to a new type of bot"
        tell "bots: shows the active bots on this account, and refreshes the number database"
        tell "clone: create a copy of a bot with a new network connection"
        tell "describe: describes a bot"
        tell "emails: sets the notification_emails for a bot"
        tell "new: creates a new bot and connects it to the network."
        tell "orphaned: lists bots without brains"
        tell "owner: manages the owners for a bot"
        tell "passcode: changes the passcode on the account"
        tell "quit: ends this conversation"
        tell "repair: checks active numbers and checks their setup"
        tell "settings: manages the settings for a bot"
        tell "voice: sets what phone rings when somebody calls this bot."

      when "clone"
        existing_number = confirmed_gets("Please give me the existing number to use as a template.")
        new_number = confirmed_gets("What is the new number?")
        if confirm("All set here. Clone the number?")
          bot = Room.new(existing_number)
          settings = bot.load
          unless settings
            tell "Failed to load settings."
            next
          end
          bot.retarget(new_number)
          bot.publish
        end

      when "passcode"
        new_passcode = confirmed_gets("Please provide a new passcode")
        set_passcode(new_passcode)
        tell "Passcode set."

      when "assign"
        numbers = nexmo.account_numbers
        begin
          number = confirmed_gets("Which bot should I assign? I'll search for partial matches.
          Text cancel if you'd like to go back")
          valid = numbers.include?(number) || number.downcase == "cancel"
          tell "That is not a valid choice" unless valid
        end unless valid
        unless number.downcase == "cancel"
          script = get_script
          create_redis_key(number, script)
          bot = Room.new(number)
          create_settings(bot)
        else
          tell "Transaction cancelled"
        end

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

      when "orphaned"
        numbers = nexmo.account_numbers
        orphaned_numbers = [ ]
        numbers.each do |n|
          room = Room.new(n)
          orphaned_numbers << n unless room.valid?
        end
        tell "Orphans: #{orphaned_numbers.join(',')}"

      when "bots"
        numbers = nexmo.account_numbers
        current_members = $r.smembers "NEXMO_NUMBERS"
        $r.srem("NEXMO_NUMBERS", current_members.join(" "))
        numbers.each{|n| $r.sadd("NEXMO_NUMBERS", n)}
        unless numbers.empty?
          tell numbers.join(",")
        else
          tell "This account has no numbers"
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
