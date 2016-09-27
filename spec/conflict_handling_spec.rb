require 'spec_helper'

describe "ConflictHandling" do
  let(:original) { User.create name: 'Mickey Mouse', title: "Dr.", homepage: 'www.gmx.de'}
  let!(:copy)     { User.find(original.id) }

  context "when handling conflicts" do
    before do
      User.auto_conflict_resolution_on_save = true
    end

    it "should be able to save without modifications" do
      copy.save.should be true
    end

    it "be able to save when modification happen on different attributes" do
      original.name = "Pluto"
      original.save.should be true

      copy.title = 'Prof.'
      expect { copy.save }.not_to raise_error

      copy.reload.name.should     eq "Pluto"
      copy.reload.title.should    eq "Prof."
      copy.reload.homepage.should eq "www.gmx.de"
    end

    it "be able to save when modification happen on different, multiple attributes - remote" do
      original.name = "Pluto"
      original.homepage = 'www.google.com'
      original.save.should be true

      copy.title = 'Prof.'
      expect { copy.save }.not_to raise_error

      copy.reload.name.should     eq "Pluto"
      copy.reload.title.should    eq "Prof."
      copy.reload.homepage.should eq "www.google.com"
    end

    it "be able to save when modification happen on different, multiple attributes locally" do
      original.name = "Pluto"
      original.save.should be true

      copy.title = 'Prof.'
      copy.homepage = 'www.google.com'
      expect { copy.save }.not_to raise_error

      copy.reload.name.should     eq "Pluto"
      copy.reload.title.should    eq "Prof."
      copy.reload.homepage.should eq "www.google.com"
    end

    it "re-raise the conflict if there is no merge possible" do
      original.name = "Pluto"
      original.save.should be true

      copy.name = 'Prof.'
      expect { copy.save }.to raise_error CouchPotato::Conflict

      copy.name.should eq "Prof."
      copy.reload.name.should eq "Pluto"
    end

    it "re-raise the conflict if retried several times" do
      exception = CouchPotato::Conflict.new
      #CouchPotato.database.expects(:save_document).raises(exception).times(3)
      expect( CouchPotato.database ).to receive(:save_document).exactly(3).times.and_raise exception

      copy.name = 'Prof.'
      expect { copy.save }.to raise_error CouchPotato::Conflict
    end

    it "not try to merge and re-save if auto_conflict_resolution_on_save is disabled" do
      User.auto_conflict_resolution_on_save = false
      exception = CouchPotato::Conflict.new
      #CouchPotato.database.expects(:save_document).raises(exception).times(1)
      expect( CouchPotato.database ).to receive(:save_document).once.and_raise exception

      copy.name = 'Prof.'
      expect { copy.save }.to raise_error CouchPotato::Conflict
    end

    context "with conflict information" do

      it "add information about the conflict to the exception" do
        original.name = "Pluto"
        original.save.should be true

        copy.name = 'Prof.'
        begin
          copy.save
        rescue CouchPotato::Conflict => e
          e.message.should eq '409 Conflict - conflict on attributes: ["name"]'
        end
      end

      it "only add the conflict information to one exception" do
        other_copy = User.find(original.id)

        original.name = "Pluto"
        original.title = "Frau"
        original.save.should be true

        copy.name = 'Prof.'
        begin
          copy.save.should be true
        rescue CouchPotato::Conflict => e
          e.message.should eq '409 Conflict - conflict on attributes: ["name"]'
        end

        other_copy.title = 'Prof.'
        begin
          other_copy.save
        rescue CouchPotato::Conflict => e
          e.message.should eq '409 Conflict - conflict on attributes: ["title"]'
        end
      end
    end

  end
end
