# taken from: http://stackoverflow.com/questions/5490411/counting-the-number-of-queries-performed
RSpec::Matchers.define :exceed_query_limit do |expected|

  match do |block|
    query_count(&block) > expected
  end

  failure_message_when_negated do |actual|
    "Expected to run maximum #{expected} queries, got #{@executed_queries}"
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
