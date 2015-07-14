require 'spec_helper'

describe 'validations' do
  context "with additional validations" do
    context "with validates_inclusion_of" do
      it "validate inclusion of an attribute in an array" do
        category = Category.new(name: "other")
        category.save.should be false
      end

      it "add an error message" do
        category = Category.new(name: "other")
        category.valid?
        category.errors.full_messages.first.should match /is not included in the list/
      end

      it "allow blank" do
        category = Category.new(name: nil)
        category.should be_valid
      end
    end

    context "with validates_format_of" do
      class ValidatedUser
        include SimplyStored::Couch
        property :name
        validates_format_of :name, with: /Paul/
      end

      it 'validate the format and fail when not matched' do
        user = ValidatedUser.new(name: "John")
        user.should_not be_valid
      end

      it 'succeed when matched' do
        user = ValidatedUser.new(name: "Paul")
        user.should be_valid
      end

      it 'fail when empty' do
        user = ValidatedUser.new(name: nil)
        user.should_not be_valid
      end

      context "with allow_blank" do
        class ValidatedBlankUser
          include SimplyStored::Couch
          property :name
          validates_format_of :name, with: /Paul/, allow_blank: true
        end

        it 'not fail when nil' do
          user = ValidatedBlankUser.new(name: nil)
          user.should be_valid
        end

        it 'not fail when empty string' do
          user = ValidatedBlankUser.new(name: '')
          user.should be_valid
        end

        it 'fail when not matching' do
          user = ValidatedBlankUser.new(name: 'John')
          user.should_not be_valid
        end

        it 'not fail when matching' do
          user = ValidatedBlankUser.new(name: 'Paul')
          user.should be_valid
        end

      end
    end

    context "with validates_uniqueness_of" do
      #it "add a view on the unique attribute" do
        #UniqueUser.by_name
      #end

      it "set an error when a different with the same instance exists" do
        UniqueUser.create(name: "Host Master")
        user = nil
        expect{ user = UniqueUser.create(name: "Host Master") }.not_to change{ UniqueUser.count }
        user.should_not be_valid
      end

      it "not have an error when we're the only one around" do
        user = UniqueUser.create(name: "Host Master")
        user.should_not be_new_record
      end

      it "not have an error when it's the same instance" do
        user = UniqueUser.create(name: "Host Master")
        user = UniqueUser.find(user.id)
        user.should be_valid
      end

      it 'have a nice error message' do
        UniqueUser.create(name: "Host Master")
        user = nil
        expect{ user = UniqueUser.create(name: "Host Master") }.not_to change{ UniqueUser.count }
        user.errors[:name].should eq ["is already taken"]
      end

      it 'create a view to check with' do
        UniqueUser.should respond_to :by_name
        UniqueUser.by_name.send(:options)[:key].should eq :name
      end

      it 'not overwrite the view when a custom one already exists' do
        UniqueUserWithAView.by_name.send(:options)[:key].should eq :email
      end
    end

    context "equality" do
      it "know when two objects are equal" do
        user = UniqueUser.create(name: "Host Master")
        other_user = UniqueUser.create(name: "The other one")
        user.should_not eq other_user
      end

      it "not bail when comparing with non-SimplyStored objects" do
        user = UniqueUser.create(name: "Host Master")
        5.should_not eq user
        user.should_not eq 5
      end
    end

    context "containment" do
      it "not raise an error when no name is set" do
        expect{ Page.new.save }.not_to raise_error
      end

      it "be valid when argument is contained in specification" do
        page  = Page.new(categories: %w[one three])
        page.should be_valid
      end

      it "not be valid when attribute containes value not withing specified containment" do
        page  = Page.new(categories: %w[one four])
        page.should_not be_valid
      end
    end

  end
end
