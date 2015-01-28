require 'spec_helper'

RSpec.describe 'Ancestry' do
  context "standard with hierarchy" do
    before do
      @d1 = Directory.create(name: 'dir1', position: 0)
      @d2 = Directory.create(name: 'dir2', position: 1)
      @d3 = Directory.create(name: 'dir3', position: 2)
      @d4 = Directory.create(name: 'dir4', position: 3)
      @a = [@d1, @d2, @d3, @d4]
    end

    it "is invalid if make_invalid is an option" do
      expect( @d1.update_attributes make_invalid: true ).to be false
    end

    describe '#path_ids' do
      it "includes the self.id in path_ids and is [self.id] when record has no parent" do
        expect( @a.map(&:id) ).to eq @a.map(&:path_ids).flatten
      end
    end

    it "sets valid children when mass assigned" do
      @d1.children = [@d2, @d3]
      expect( @d1.children.map(&:id) ).to match_array [@d2.id, @d3.id]
      expect( @d2.path_ids ).to eq [@d1.id, @d2.id]
      d1_reloaded = Directory.find(@d1.id)
      expect( d1_reloaded.children.map(&:name) ).to match_array [@d2.name, @d3.name]
      expect( d1_reloaded.children.sort_by(&:name).first.path_ids ).to eq [@d1.id, @d2.id]
    end

    it "is valid when parent is assigned" do
      @d1.children = [@d2, @d3] # See previous test for this one
      @d4.parent = @d2 # This is the functionality to be tested here

      expect( @d2.children ).to eq [@d4]
      expect( @d4.parent ).to eq @d2
      expect( @d4.path_ids ).to eq [@d1.id, @d2.id, @d4.id]

      # Also test database values
      d2_reloaded = Directory.find(@d2.id)
      d4_reloaded = Directory.find(@d4.id)
      expect( d2_reloaded.children ).to eq [@d4]
      expect( d4_reloaded.parent ).to eq @d2
      expect( d4_reloaded.path_ids ).to eq [@d1.id, @d2.id, @d4.id]
    end

    it "handles roots" do
      expect( Directory.roots.sort_by(&:id) ).to eq @a.sort_by(&:id)
      @d1.children = [@d2, @d3]
      expect( Directory.roots ).to match_array [@d1, @d4]
    end

    it "returns proper ancestors" do
      @d1.children = [@d2, @d3]
      @d3.add_child(@d4).save
      expect( @d1.ancestors ).to be_empty
      expect( @d2.ancestors ).to eq [@d1]
      expect( @d3.ancestors ).to eq [@d1]
      expect( @d4.ancestors ).to eq [@d1, @d3]
      d4_reloaded = Directory.find(@d4.id)
      expect( d4_reloaded.ancestors ).to eq [@d1, @d3]
    end

    it "returns proper descendants" do
      @d1.children = [@d2, @d3]
      @d2.children = [@d4]
      expect( @d1.descendants ).to match_array [@d2, @d3, @d4]
    end

    it "gives a proper subtree and does not change the subject" do
      # This is a relevant test since it failed in the past
      @d1.children = [@d2]
      @d2.children = [@d3, @d4]
      expect( @d2.subtree ).to eq [@d3, @d4]
      @d2.reload
      # This is what it is about
      expect( @d2.path_ids ).to eq [@d1.id, @d2.id]
    end

    it "updates path_ids on deeper nested elements using children=" do
      @d2.children = [@d3, @d4]
      @d1.children = [@d2]

      # Not for now, objects self are not updated
      #expect( @d3.path_ids ).to eq [@d1.id, @d2.id, @d3.id]
      #expect( @d4.path_ids ).to eq [@d1.id, @d2.id, @d4.id]
      @d3.reload
      @d4.reload
      expect( @d3.path_ids ).to eq [@d1.id, @d2.id, @d3.id]
      expect( @d4.path_ids ).to eq [@d1.id, @d2.id, @d4.id]
    end

    it "updates path_ids on deeper nested elements using parent_id=" do
      @d2.children = [@d3, @d4]
      [@d2, @d3, @d4].map(&:reload)
      @d2.parent_id = @d1.id

      # Not for now, objects self are not updated
      #expect( @d3.path_ids ).to eq [@d1.id, @d2.id, @d3.id]
      #expect( @d4.path_ids ).to eq [@d1.id, @d2.id, @d4.id]
      @d3.reload
      @d4.reload
      expect( @d3.path_ids ).to eq [@d1.id, @d2.id, @d3.id]
      expect( @d4.path_ids ).to eq [@d1.id, @d2.id, @d4.id]
    end

    it "updates path_ids on deeper nested elements using parent_id= nil" do
      # Copy of previous
      @d2.children = [@d3, @d4]
      [@d2, @d3, @d4].map(&:reload)
      @d2.parent_id = @d1.id

      # Not for now, objects self are not updated
      #expect( @d3.path_ids ).to eq [@d1.id, @d2.id, @d3.id]
      #expect( @d4.path_ids ).to eq [@d1.id, @d2.id, @d4.id]
      [@d2, @d3, @d4].map(&:reload)
      expect( @d3.path_ids ).to eq [@d1.id, @d2.id, @d3.id]
      expect( @d4.path_ids ).to eq [@d1.id, @d2.id, @d4.id]

      @d2.parent_id = ""
      [@d2, @d3, @d4].map(&:reload)
      expect( @d3.path_ids ).to eq [@d2.id, @d3.id]
      expect( @d4.path_ids ).to eq [@d2.id, @d4.id]
    end

    it "preserve children of parent when another is added through parent_id=" do
      # Yes, this one failed once

      # Copy of previous
      @d2.children = [@d3]
      [@d2, @d3, @d4].map(&:reload)
      @d4.parent_id = @d2.id
      [@d2, @d3, @d4].map(&:reload)
      expect( @d2.children ).to eq [@d3, @d4]
    end

    it "not update descendants when parent_id is set in update_attributes and save is not valid" do
      # Copy of previous
      @d2.children = [@d3, @d4]
      [@d2, @d3, @d4].map(&:reload)
      @d2.update_attributes(:parent_id => @d1.id, :make_invalid => true)

      [@d1, @d2, @d3, @d4].map(&:reload)
      expect( @d3.path_ids ).to eq [@d2.id, @d3.id]
      expect( @d4.path_ids ).to eq [@d2.id, @d4.id]

    end

    it 'build tree returning actual objects set in descendants' do
      @d1.children = [@d2, @d3]
      [@d1, @d2, @d3].map(&:reload)
      expect( @d1.descendants.map(&:object_id).sort ).to eq @d1.subtree.map(&:object_id).sort
    end

    context "initialization" do
      it "initializes a new record without an id" do
        expect( Directory.new(parent_id: @d3.id).id ).not_to be_present
      end
    end
  end

  context "namespaced with hierarchy" do
    before do
      @d1 = NamespacedDirectory.create(:name => 'dir1', :locale => 'en')
      @d2 = NamespacedDirectory.create(:name => 'dir2', :locale => 'en')
      @d3 = NamespacedDirectory.create(:name => 'dir3', :locale => 'nl')
      @d4 = NamespacedDirectory.create(:name => 'dir4', :locale => 'nl')
      @a = [@d1, @d2, @d3, @d4]
    end

    it "all have a path containing own id" do
      expect( @a.map(&:path_ids).flatten ).to eq @a.map(&:id)
    end

    it "set valid children when mass assigned" do
      @d1.children = [@d2, @d3]
      expect( @d1.children ).to match_array [@d2, @d3]
      expect( @d2.path_ids ).to eq [@d1.id, @d2.id]
      d1_reloaded = NamespacedDirectory.find(@d1.id)
      expect( d1_reloaded.children ).to match_array [@d2, @d3]
      expect( d1_reloaded.children.sort_by(&:name).first.path_ids ).to eq [@d1.id, @d2.id]
    end

    it "be valid when parent is assigned" do
      @d1.children = [@d2, @d3] # See previous test for this one
      @d4.parent = @d2 # This is the functionality to be tested here

      expect( @d2.children ).to eq [@d4]
      expect( @d4.parent ).to eq @d2
      expect( @d4.path_ids ).to eq [@d1.id, @d2.id, @d4.id]

      # Also test database values
      d2_reloaded = NamespacedDirectory.find(@d2.id)
      d4_reloaded = NamespacedDirectory.find(@d4.id)
      expect( d2_reloaded.children ).to eq [@d4]
      expect( d4_reloaded.parent ).to eq @d2
      expect( d4_reloaded.path_ids ).to eq [@d1.id, @d2.id, @d4.id]
    end

    it "return proper parents" do
      @d1.children = [@d2, @d3]
      @d2.children = [@d4]
      expect( @d4.parents ).to eq [@d1, @d2]
    end

    it "handle roots" do
      expect( NamespacedDirectory.roots ).to match_array @a
    end

    it "removes records as root when given as child argument"do
      @d1.children = [@d2, @d3]
      expect( NamespacedDirectory.roots ).to eq [@d1, @d4]
    end

    it "handle roots by property as symbol" do
      @d1.children = [@d2, @d3]
      expect( NamespacedDirectory.roots(:en) ).to eq [@d1]
      expect( NamespacedDirectory.roots(:nl) ).to eq [@d4]
    end

    it "handle roots by property as string" do
      @d1.children = [@d2, @d3]
      expect( NamespacedDirectory.roots('en') ).to eq [@d1]
      expect( NamespacedDirectory.roots('nl') ).to eq [@d4]
    end

    it "change by property to valid value when assigned as children" do
      expect( @d1.locale ).not_to eq @d3.locale
      @d1.children = [@d2, @d3]
      expect( @d1.locale ).to eq @d3.locale
      d3_reloaded = NamespacedDirectory.find(@d3.id)
      expect( @d1.locale ).to eq d3_reloaded.locale
    end

    it "change by property to valid value when assigned through add_child with save" do
      expect( @d1.locale ).not_to eq @d3.locale
      @d1.add_child(@d3).save
      expect( @d1.locale ).to eq @d3.locale
      d3_reloaded = NamespacedDirectory.find(@d3.id)
      expect( @d1.locale ).to eq d3_reloaded.locale
    end

    it "change by property to valid value when assigned through add_child without save" do
      expect( @d1.locale ).not_to eq @d3.locale
      @d1.add_child(@d3)
      expect( @d1.locale ).to eq @d3.locale
      d3_reloaded = NamespacedDirectory.find(@d3.id)
      expect( @d4.locale ).to eq d3_reloaded.locale
    end

    it "give a proper tree without namespace" do
      @d1.children = [@d2, @d3]
      full_tree = NamespacedDirectory.full_tree
      expect( full_tree ).to match_array [@d1, @d4]
      expect( full_tree.sort_by(&:id).map{|p| p.children.map(&:id).sort}.sort ).to eq [[@d2.id, @d3.id].sort, []].sort
    end

    it "give a proper tree with namespace as symbol" do
      @d1.children = [@d2, @d3]
      full_tree = NamespacedDirectory.full_tree(:en)
      expect( full_tree.map(&:id) ).to eq [@d1.id]
      expect( full_tree.map{|p| p.children.map(&:id).sort} ).to eq [[@d2.id, @d3.id].sort]
    end
    it "give a proper tree with namespace as string" do
      @d1.children = [@d2, @d3]
      full_tree = NamespacedDirectory.full_tree('en')
      expect( full_tree.map(&:id) ).to eq [@d1.id]
      expect( full_tree.map{|p| p.children.map(&:id).sort} ).to eq [[@d2.id, @d3.id].sort]
    end

    it "give a proper tree with namespace as property" do
      @d1.children = [@d2, @d3]
      full_tree = NamespacedDirectory.full_tree(:locale => 'en')
      expect( full_tree.map(&:id) ).to eq [@d1.id]
      expect( full_tree.map{|p| p.children.map(&:id).sort} ).to eq  [[@d2.id, @d3.id].sort]
    end

    it "give a proper tree with revisions" do
      @d1.children = [@d2, @d3, @d4]
      full_tree = NamespacedDirectory.full_tree(:locale => 'en')
      expect( full_tree ).to eq [@d1]
    end

  end
end
=begin
class AncestryTest < Test::Unit::TestCase
=end
