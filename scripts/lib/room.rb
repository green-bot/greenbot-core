require 'parse-ruby-client'

class Room
  def initialize(room_name)
    Parse.init(application_id: "y9Bb9ovtjpM4cCgIesS5o2XVINBjHZunRF1Q8AoI", api_key: "C9s58yZZUqkAh1Yzfc2Ly9NKuAklqjAOhHq8G4v7", auiet: false)
    @room_name = room_name.downcase
    load
  end

  def key_name
    @room_name
  end

  def valid?
    @valid
  end

  def retarget(new_room_name)
    @room_name = new_room_name.downcase
    tell "Room name is now #{@room_name}"
  end

  def delete
    @room.parse_delete
  end


  def trace
  end

  def name
    @room_name
  end


  def set_test_mode
    @settings["test_mode"] = "true"
    publish
    trace
  end

  def load
    q = Parse::Query.new("Room")
    q.eq("name", @room_name)
    @room = q.get.first
    puts @room.inspect
    @settings = @room["settings"]
    @valid = @settings ? true : false
  end

  def env_settings
    @room["settings"].reject{|k,v| %w(AWAY AUTO_CHARGE auto_charge).include?(k) }
  end

  def update_setting(key, value)
    @room["settings"][key] = value
    publish
    trace
  end

  def get_setting(key)
    @room["settings"][key]
  end

  def publish
    @room.save
    trace
  end

  def set_environment
    env_settings.each {|k,v| ENV[k]= v }
  end

  def owners
    @room["owners"]
  end

  def notification_emails
    @room["notification_emails"]
  end

end
