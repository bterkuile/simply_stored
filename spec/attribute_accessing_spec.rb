require 'spec_helper'

describe "Attribute accessing" do
  context "with brackets" do
    it "access with string argument" do
      user = User.new
      user.name = 'UTest'
      user['name'].should eq 'UTest'
    end
    it "access with symbol argument" do
      user = User.new
      user.name = 'UTest'
      user[:name].should eq 'UTest'
    end
  end
end
