require "rubygems"
require "highline/import"
require "yaml"
require "json"
require 'redis'
require "uuidtools"
require 'awesome_print'

#
###########################################################
#
# Utility Classes
#
def puts(o)
  if o.is_a? Array
    super(o.to_s)
  else
    super(o)
  end
  $stdout.flush
end


#
###########################################################
#

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

class Object
  def remember(label)
    $session.remember(label, self)
  end
  def forget(label)
    $session.forget(label)
  end
end

$r = Redis.new

class Room
  def initialize(room_name)
    @room_name = room_name.downcase
    @redis = $r || Redis.new
    load
  end

  def room_key
    "room:#{@room_name}"
  end

  def set_test_mode
    @settings['TEST_MODE'] = "true"
    publish
  end

  def load
    raw = @redis.get(self.room_key)
    unless raw.nil?
      @settings = JSON.parse(raw)
      return @settings
    else
      null
    end
  end

  def env_settings
    @settings["settings"].reject{|k,v| %w(AWAY AUTO_CHARGE auto_charge).include?(k) }
  end

  def update_setting(key, value)
    @settings['settings'][key] = value
    publish
  end

  def get_setting(key)
    @settings['settings'][key]
  end

  def publish
    if @settings
      @redis.set(room_key, @settings.to_json)
    end
    load
  end

  def set_environment
    env_settings.each {|k,v| ENV[k]= v }
  end

end

def confirm(prompt)
  positives = %w(yes sure OK yep)
  negatives = %w(no nope noway)
  puts prompt+"(y/n)"
  answered = false
  while not answered
    answer = gets.chomp.downcase
    positives.each do |p|
      return true if answer.include? p
    end
    negatives.each do |p|
      return false if answer.include? p
    end
    return true if answer == "y"
    return false if answer == "n"
    puts ("I'm sorry, we are looking for a Y or an N")
  end
end

def select(prompt, choices)
  puts prompt + " (" + choices.sort.join(",") + ")"
  begin
    answer = gets.chomp.downcase
    choices.each {|e|
      return e if e.downcase == answer.downcase
    }
    puts "I'm sorry, please pick one : " + choices.join(",")
  end while true
end

def confirmed_gets(prompt)
  begin
    puts(prompt)
    new_setting = gets.chomp
    did_it_right = confirm("Did you send that correctly? Please check.")
    return new_setting if did_it_right
  end while not did_it_right
end


# Check to see if we are in a debugging environment.
# If we are, setup a dummy environment
room_name = ENV['DST']
$room = Room.new(room_name)
$room.set_environment

session_id = ENV['SESSION_ID'] || UUIDTools::UUID.random_create.to_s
ENV['SESSION_ID'] = session_id
$session = SessionData.new(session_id)

%w(SRC DST SESSION_ID).each do |s|
  $session.remember(s,ENV[s])
end
