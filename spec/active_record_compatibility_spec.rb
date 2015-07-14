require 'spec_helper'

describe 'Active record compatibility' do
  it "had a proper primary key definition" do
    Post.primary_key.should eq 'id'
  end
end
