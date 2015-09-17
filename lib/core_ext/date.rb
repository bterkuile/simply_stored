# use ISO8601 as timeformat
class Date
  def to_json(*a)
    %|"#{as_json}"|
  end

  def as_json(*args)
    iso8601
  end

  def self.json_create string
    return nil if string.nil?
    Date.parse(string)
  end
end
