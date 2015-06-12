

class Room

  def initialize(room_name)
    @room_name = room_name.downcase
    load
  end

  def load
    q = Parse::Query.new("Room")
    q.eq("name", @room_name)
    @room = q.get.first
    @settings = @room["settings"]
    @valid = @settings ? true : false
  end

  def self.create(room_name, options)
    new_room = Parse::Object.new("Room")
    options.each{|k,v| new_room[k] = v}
    new_room["name"] = room_name
    new_room.save
  end

  def self.scripts
    scripts = Parse::Query.new("Script").get
  end

  def assign(script_object_id)
    q = Parse::Query.new("Script")
    q.eq("objectId", script_object_id)
    script = q.get.first
    @room['default_cmd'] = script['default_cmd']
    @room['settings'] = script['default_settings']
    @room['owner_cmd'] = script['owner_cmd']
    @room['default_path'] = script['default_path']
    publish
  end

  def not_setup?
    @room["default_cmd"] == "ruby default.rb"
  end


  def options
    interesting_fields = %w(default_cmd default_path notification_emails owner_cmd owners settings mail_user mail_pass test_mode)
    options = {}
    interesting_fields.each do |f|
      options[f] = @room[f]
    end
    options
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

  def add_qty(amount)
    @room["qty"] = Parse::Increment.new(amount)
    @room.save
  end

  def subtract_qty(amount)
    @room["qty"] = Parse::Increment.new(-amount)
    @room.save
  end

  def qty
    if @room["qty"].nil?
      @room["qty"] = 0
      @room.save
    end
    @room["qty"]
  end
  
  def trace
    puts $room.inspect if ENV['DEVELOPER'] == "true"
  end

  def name
    @room_name
  end


  def set_test_mode
    @room["test_mode"] = true
    publish
    trace
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
