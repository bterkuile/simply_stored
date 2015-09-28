$performed_queries = []
CouchRest.class_eval do
  class << self
    alias_method :old_get, :get
    def get(uri, options={})
      $performed_queries << {url: uri, options: options} if is_query_uri?(uri)
      old_get(uri, options)
    end

    def is_query_uri?(uri)
      return false if uri =~ /\/_design\/\w+$/ # request design doc
      return false if uri =~ /\/_uuids/
      true
    end
  end
end
# taken from: http://stackoverflow.com/questions/5490411/counting-the-number-of-queries-performed
RSpec::Matchers.define :exceed_query_limit do |expected|

  match do |block|
    query_count(&block) > expected
  end

  failure_message_when_negated do |actual|
    #extra_queries = $performed_queries[expected..-1].map{|q| q[:url]}.map do |q|
    extra_queries = $performed_queries.map{|q| q[:url]}.map do |q|
      if q =~ /5984\/\w+\/[0-9a-f]{32}$/
        info = q
        begin
          record = CouchRest.get(q)
          if record.is_a?(SimplyStored::Couch)
            info += " #{record.class.name}"
          end
        rescue
        end
        info
      else
        q
      end
    end
    "Expected to run maximum #{expected} queries, got #{@executed_queries}\nqueries:\n - #{extra_queries.join("\n - ")}"
  end

  def query_count(&block)
    $performed_queries = []
    block.call
    @executed_queries = $performed_queries.size
  end

  def supports_block_expectations?
    true
  end

end

RSpec::Matchers.define :perform_any_queries do |expected|
  match do |block|
    query_count(&block) > 0
  end

  failure_message_when_negated do |actual|
    extra_queries = $performed_queries.map{|q| q[:url]}.map do |q|
      if q =~ /5984\/\w+\/[0-9a-f]{32}$/
        info = q
        begin
          record = CouchRest.get(q)
          if record.is_a?(SimplyStored::Couch)
            info += " #{record.class.name}"
          end
        rescue
        end
        info
      else
        q
      end
    end
    "Expected to run no queries, got #{@executed_queries}\nExtra queries:\n - #{extra_queries.join("\n - ")}"
  end

  def query_count(&block)
    $performed_queries = []
    block.call
    @executed_queries = $performed_queries.size
  end

  def supports_block_expectations?
    true
  end
end
