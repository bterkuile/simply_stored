require 'spec_helper'
describe "Instance methods" do
  describe '#serializable_hash' do
    it 'returns a proper hash'do
      User.new(title: 'Include relation posts user').serializable_hash.should eq(
        'id'         => nil,
        "created_at" => nil,
        "updated_at" => nil,
        "name"       => nil,
        "title"      => "Include relation posts user",
        "homepage"   => nil
      )
    end
  end
end
