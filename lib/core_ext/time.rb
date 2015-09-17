require 'active_support/time'
# use ISO8601 as timeformat
class Time
  def to_json(*a)
    %|"#{as_json}"|
  end

  def as_json(*args)
    getutc.iso8601
  end

  def self.json_create string
    return nil if string.nil?
    d = DateTime.parse(string.to_s).new_offset
    self.utc(d.year, d.month, d.day, d.hour, d.min, d.sec).in_time_zone
  end
end

ActiveSupport::TimeWithZone.class_eval do
  def as_json(*args)
    utc.iso8601
  end
end
