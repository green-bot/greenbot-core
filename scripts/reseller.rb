
#!/usr/bin/env ruby
# The script for resellers, allowing outsiders to order new services.
#
# reseller.rb
#
require "./lib/greenbot.rb"
require 'json'
require 'open3'
require 'pry'
require 'nexmo'
require "redis"
require "timeout"

#   Ask noah: would you like to order a new service, or become a dealer?
options = %w(new dealer)
choice = select("Welcome! Thanks for your interest in GreenBot. You can order a new bot, or become a dealer.")
case choice
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

#   if new service
#     Script: Please select script - information, leadgen, text2email, complaint, etc.
#     Customer: information
#
#     Script: May I please have a four digit passcode. You'll need it to configure your system.
#     Customer: 1234
#
#     Script. Please take a look at our terms and conditions : http://lawyers.com
#     Script: Do you accept these terms? (y/n)
#     User: Y
#
#     Script: May we please have a credit card to pay for this account?  Please click this link to add it.
#     Script: Heres your link: stripe.com/pay/1234afasfd
#     Customer: clicks link, pays for account.
#     Script: Thank you! your number: 212-555-1212
#
#     (Note that we might be able to get email from merchant)
#     Script: Can we please have an email address to send results to?
#     Customer: Noah@tsgglobal.com
#     Script. Conversations will be mailed to noah@tsgglobal.com. Correct? (y/n)
#     User: Y
#
#     Script:  If you don't have experience with this script, you can try our demo script at 212-121-1222 to see what it looks like.
#
#
#     Script: Please give us what you'd like for your first prompt.
#     User: Thank you for texting us at Longfellows!
#     Script: Thank you. PROMPT1 is now  set to be: "Thank you for texting us at Longfellows". Correct? (y/n)
#     User: Y
#     Script: Please give us what you'd like for your second prompt.
#     User: Longfellows have long fellows.
#     Script: Thank you. PROMPT2 is now  set to be: "Longfellows have long fellows". Correct? (y/n)
#     User: N
#     Script: Please give us what you'd like for your second prompt.
#     User: Longfellows have very long fellows.
#     Script: Thank you. PROMPT2 is now  set to be: "Longfellows have very long fellows". Correct? (y/n)
#     User: Y
#
#     Ad nauseum...
#
#     Script: Your script is now setup for use.
#
#     Thanks!
#     Script: emails notification to user with instructions for new account, same for distributor
#



# else if Noah is already a customer, he can sign up for new numbers, or to become a dealer.
#
#     Script: May I please have your four digit passcode. You'll need it to configure your system.
#     Customer: 1234
#
#     Script: Please select script - information, leadgen, text2email, complaint, etc.
#     Customer: information
#
#     Script: Thank you! your number: 212-555-1212
#
#     Script: We are currently sending emails to noah@. Is there a different one you want to use?
#     Customer : N
#
#     Script:  If you don't have experience with this script, you can try our demo script at 212-121-1222 to see what it looks like.
#
#     Script: Please give us what you'd like for your first prompt.
#     User: Thank you for texting us at Longfellows!
#     Script: Thank you. PROMPT1 is now  set to be: "Thank you for texting us at Longfellows". Correct? (y/n)
#     User: Y
#     Script: Please give us what you'd like for your second prompt.
#     User: Longfellows have long fellows.
#     Script: Thank you. PROMPT2 is now  set to be: "Longfellows have long fellows". Correct? (y/n)
#     User: N
#     Script: Please give us what you'd like for your second prompt.
#     User: Longfellows have very long fellows.
#     Script: Thank you. PROMPT2 is now  set to be: "Longfellows have very long fellows". Correct? (y/n)
#     User: Y
#
#     Ad nauseum...
#
#     Script: Your script is now setup for use.
#     Thanks!
#
#     Script: emails notification to user with instructions for new account, same for distributor
#
# Noah wants to be a dealer:
#     Script: Welcome to the Kisst Family!
#     Script: May we please have your email addrss?
#     User: noah@
#     Script: May we please have your full name?
#     User: Noah Rafalko
#     Script: May we please have your mailing address?
#     User: 77 Barnhill, W barn, 02668
#
#     Script. Please take a look at our terms and conditions : http://lawyers.com
#     Script: Do you accept these terms? (y/n)
#     User: Y
#
#     Script: Dealers commit to a minimum of "8" paid accounts, at "$20" a month each. We need a credit card to guarantee this.
#     Script: Heres your link: stripe.com/pay/1234afasfd
#     Customer: clicks link, pays for dealer monthly.
#     Script: Thank you! your number: 212-555-1212. Please have your customers use that number to order new services.
#     Script: WHen they do, they will be part of your customer base.
#
#     if not passcode, collect it.
#
#     Script: Would you like to setup your own script on a different number?
#     User: Y
#
#    <Start the number ordering process, don't collect credit card.>
#     Script: emails notification to user for new account, same for distributor
#
#
#

































HOUR = 60 * 60
timeout = ENV['CONVERSATION_TIMEOUT'].to_i || 4 * HOUR

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
