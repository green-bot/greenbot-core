require 'rubygems'
require 'byebug'

if ENV['DEVELOPER'] == "true"
  FIVE_MINUTES = 5
  HALF_AN_HOUR = 30
  MESSAGE_PACE = 1
  at_exit byebug if $!
else
  FIVE_MINUTES = 5*60
  HALF_AN_HOUR = 30*60
  MESSAGE_PACE = 3.1415
end
require 'bundler/setup'
require 'highline/import'
require 'yaml'
require 'json'
require 'redis'
require 'uuidtools'
require 'airbrake'
require 'timeout'
require './lib/Bot'


# Handles the collection and remembering of data
class SessionData
  attr_accessor :collected_data
  def initialize(session_id = nil)
    session_data_path = "./session_data/"
    session_base_filname = (session_id || "session_data") + ".json"
    @filename = session_data_path + session_base_filname
    @filename = timestamp_filename(@filename) if session_id.nil?
    Dir.mkdir(session_data_path) unless Dir.exists?(session_data_path)
    @collected_data = {}
  end

  def timestamp_filename(file)
    dir  = File.dirname(file)
    base = File.basename(file, ".*")
    time = Time.now.to_i
    ext  = File.extname(file)
    File.join(dir, "#{base}_#{time}#{ext}")
  end

  def remember(key, value)
    return if key.empty?
    collected_data[key] = value
    update_record
  end

  def forget(key)
    @collected_data.delete(key) if @collected_data.keys.include?(key)
    update_record
  end

  def update_record
    File.open(@filename, "w") { |file| file.write(@collected_data.to_json) }
    puts @collected_data.to_json
  end
end

# Extends ruby object to remember and forget them
class Object
  def remember(label)
    $session.remember(label, self)
  end
  def forget(label)
    $session.forget(label)
  end
end

# Helper classes
def confirm(prompt)
  positives = %w(yes sure OK yep)
  negatives = %w(no nope noway)
  answer = ask(prompt+'( yes / no )').chomp.downcase
  answered = false
  while not answered
    positives.each do |p|
      return true if answer.include? p
    end
    negatives.each do |p|
      return false if answer.include? p
    end
    return true if answer == "y"
    return false if answer == "n"
    answer = ask("I'm sorry, we are looking for a yes or a no").chomp.downcase
  end
end

def select(prompt, choices)
  display_prompt = prompt + " (" + choices.sort.join(",") + ")"
  answer = ask(display_prompt)
  begin
    choices.each {|e|
      return e if e.downcase == answer.downcase
    }
    answer = ask("I'm sorry, please pick one : " + choices.join(","))
  end while true
end

def confirmed_gets(prompt)
  begin
    new_setting = ask(prompt)
    did_it_right = confirm("Did you send that correctly? Please check.")
    return new_setting if did_it_right
  end while not did_it_right
end

def listen
  $stdout.flush
  gets.chomp
end

def ask(prompt, first_timeout = FIVE_MINUTES, second_timeout = HALF_AN_HOUR)
  tell(prompt, 0)

  # Wait for the first timeout.
  # if the gets.chomp returns, we exit the block, return value, no worry
  # If not, we repeat the prompt
  answered = false
  answer = ''
  begin
    Timeout::timeout(first_timeout) do
      answer = gets.chomp
      answered = true
    end
  rescue Timeout::Error
    tell(prompt, 0)
  end
  return answer if answered

  begin
    Timeout::timeout(second_timeout) do
      answer = gets.chomp
      answered = true
    end
  rescue Timeout::Error
    tell('Thank you for contacting us. Closing this conversation, feel free to message us again to start again',0)
    exit
  end
  return answer if answered
end


def tell(prompt, pace = MESSAGE_PACE)
  puts prompt
  $stdout.flush
  sleep pace
end

def note(prompt)
  complete = false
  note = ""
  response = ask(prompt)
  begin
    if response.chomp.length == 1
      complete = true
      tell "Note taking mode complete."
    else
      note << response
      response = ask("Still listening here. Send as many messages as you like, send a Q to end. ")
    end
  end while not complete
  return note
end

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

def create_settings(bot)
  bot.env_settings.each {|k,v|
    bot.update_setting(k,confirmed_gets("Please give me the a value for #{k}."))
  }
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


bot_name = ENV['DST']
bot_id = ENV['BOT_OBJECT_ID']

session_id = ENV['SESSION_ID'] || UUIDTools::UUID.random_create.to_s
ENV['SESSION_ID'] = session_id
$session = SessionData.new(session_id)

%w(SRC DST SESSION_ID).each do |s|
  $session.remember(s,ENV[s])
end
