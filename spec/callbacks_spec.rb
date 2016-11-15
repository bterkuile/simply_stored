require 'spec_helper'

describe 'callbacks' do

  describe ".before_save" do
    let(:subject) { Callbacker.new name: 'Cally' }
    it "increments the counter" do
      subject.save
      subject.reload.counter.should be 1
    end
  end

  describe "with raising callback #after_safe" do
    let(:subject) { Callbacker.new name: 'Cally', raise_on_save: true }

    it "raise_error on normal save" do
      expect{ subject.save }.to raise_error StandardError
    end

    it "raises error on save with false, validations are not run only" do
      expect{ subject.save(false) }.to raise_error StandardError
    end

    it "raises error on save with validate: false, validations are not run only" do
      expect{ subject.save(validate: false) }.to raise_error StandardError
    end

    it "raise error on save with validate: true" do
      expect{ subject.save(validate: true) }.to raise_error StandardError
    end
  end

  describe "with validation error" do
    let(:subject) { Callbacker.new name: 'Cally', with_validation_error: true }

    it "should not save the record" do
      subject.save.should be false
      subject.id.should_not be_present
    end

    it "should save the record on save with false" do
      subject.save(false).should be true
      subject.id.should be_present
    end

    it "should save the record on save with validate: false" do
      subject.save(validate: false).should be true
      subject.id.should be_present
    end

    it "should not save the record on save with validate: true" do
      subject.save(validate: true).should be false
      subject.id.should_not be_present
    end
  end
end
