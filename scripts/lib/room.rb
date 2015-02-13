class Room
  def initialize(room_name)
    @room_name = room_name.downcase
    @redis = $r || Redis.new
    settings = load
    @valid = settings ? true : false
  end

  def valid?
    @valid
  end

  def trace
    ap $room if ENV['DEVELOPER'] == "true"
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
    raw = @redis.get("room:#{@room_name}")
    unless raw.nil?
      @settings = JSON.parse(raw)
      trace
      return @settings
    else
      nil
    end
  end

  def env_settings
    @settings["settings"].reject{|k,v| %w(AWAY AUTO_CHARGE auto_charge).include?(k) }
  end

  def update_setting(key, value)
    @settings['settings'][key] = value
    publish
    trace
  end

  def get_setting(key)
    @settings['settings'][key]
  end

  def publish
    if @settings
      @redis.set(room_key, @settings.to_json)
    end
    load
    trace
  end

  def set_environment
    env_settings.each {|k,v| ENV[k]= v }
  end

  def owners
    @settings["owners"]
  end

  def notification_emails
    @settings["notification_emails"]
  end

end
