require File.dirname(__FILE__) + '/../spec_helper'

def build_secondary_iucn_hierarchy_and_resource
  another_iucn_resource  = Resource.gen(:title  => 'Another IUCN')
  another_iucn_hierarchy = Hierarchy.gen(:label => 'Another IUCN')
  AgentsResource.gen(:agent => Agent.iucn, :resource => another_iucn_resource)
  return [another_iucn_hierarchy, another_iucn_resource]
end

describe TaxonConcept do

  # Why am I loading scenarios in a model spec?  ...Because TaxonConcept is unlike other models: there is
  # really nothing to it: just an ID and a wee bit of ancillary data. At the same time, TC is *so* vital to
  # everything we do, that I wanted to construct tests that really jog the model through all of its
  # relationships.
  #
  # If you want to think of this as more of a "black-box" test, that's fine.  I chose to put it in the
  # models directory because, well, it isn't testing a website, and it IS testing a *model*, so it seemed a
  # "better" fit here, even if it isn't perfect.

  before :all do
    truncate_all_tables
    load_foundation_cache
    @overview        = TocItem.overview
    @overview_text   = 'This is a test Overview, in all its glory'
    $CACHE.clear
    @toc_item_2      = TocItem.gen_if_not_exists(:view_order => 2, :label => "test toc item 2")
    $CACHE.clear
    @toc_item_3      = TocItem.gen_if_not_exists(:view_order => 3, :label => "test toc item 3")
    @canonical_form  = Factory.next(:species)
    @attribution     = Faker::Eol.attribution
    @common_name     = Faker::Eol.common_name.firstcap
    @scientific_name = "#{@canonical_form} #{@attribution}"
    @italicized      = "<i>#{@canonical_form}</i> #{@attribution}"
    @gbif_map_id     = '424242'
    @image_1         = Factory.next(:image)
    @image_2         = Factory.next(:image)
    @image_3         = Factory.next(:image)
    @image_unknown_trust = Factory.next(:image)
    @image_untrusted = Factory.next(:image)
    @video_1_text    = 'First Test Video'
    @video_2_text    = 'Second Test Video'
    @video_3_text    = 'YouTube Test Video'
    @comment_1       = 'This is totally awesome'
    @comment_bad     = 'This is totally inappropriate'
    @comment_2       = 'And I can comment multiple times'
    tc = build_taxon_concept(
      :rank            => 'species',
      :canonical_form  => @canonical_form,
      :attribution     => @attribution,
      :scientific_name => @scientific_name,
      :italicized      => @italicized,
      :gbif_map_id     => @gbif_map_id,
      :flash           => [{:description => @video_1_text}, {:description => @video_2_text}],
      :youtube         => [{:description => @video_3_text}],
      :comments        => [{:body => @comment_1}, {:body => @comment_bad}, {:body => @comment_2}],
      :images          => [{:object_cache_url => @image_1, :data_rating => 2},
                           {:object_cache_url => @image_2, :data_rating => 3},
                           {:object_cache_url => @image_untrusted, :vetted => Vetted.untrusted},
                           {:object_cache_url => @image_3, :data_rating => 4},
                           {:object_cache_url => @image_unknown_trust, :vetted => Vetted.unknown}],
      :toc             => [{:toc_item => @overview, :description => @overview_text}, 
                           {:toc_item => @toc_item_2}, {:toc_item => @toc_item_3}]
    )
    @id            = tc.id
    @taxon_concept = TaxonConcept.find(@id)
    # The curator factory cleverly hides a lot of stuff that User.gen can't handle:
    @curator       = build_curator(@taxon_concept)
    # TODO - I am slowly trying to convert all of the above options to methods to make testing clearer:
    (@common_name_obj, @synonym_for_common_name, @tcn_for_common_name) =
      tc.add_common_name_synonym(@common_name, :agent => @curator.agent, :language => Language.english)
    # Curators aren't recognized until they actually DO something, which is here:
    LastCuratedDate.gen(:user => @curator, :taxon_concept => @taxon_concept)
    # And we want one comment that the world cannot see:
    Comment.find_by_body(@comment_bad).hide User.last
    @user = User.gen
    
    
    @tcn_count = TaxonConceptName.count
    @syn_count = Synonym.count
    @name_count = Name.count
    @name_string = "Piping plover"
    @agent = @curator.agent
    @synonym = @taxon_concept.add_common_name_synonym(@name_string, :agent => @agent, :language => Language.english)
    @name = @synonym.name
    @tcn = @synonym.taxon_concept_name
    
    @taxon_concept.current_user = @curator
    @syn1 = @taxon_concept.add_common_name_synonym('Some unused name', :agent => @agent, :language => Language.english)
    @tcn1 = TaxonConceptName.find_by_synonym_id(@syn1.id)
    @name_obj ||= Name.last
    @he2  ||= build_hierarchy_entry(1, @taxon_concept, @name_obj)
    # Slightly different method, in order to attach it to a different HE:
    @syn2 = Synonym.generate_from_name(@name_obj, :entry => @he2, :language => Language.english, :agent => @agent)
    @tcn2 = TaxonConceptName.find_by_synonym_id(@syn2.id)
  end
  # after :all do
  #   truncate_all_tables
  # end
  
  it 'should capitalize the title (even if the name starts with a quote)' do
    good_title = %Q{"Good title"}
    bad_title = good_title.downcase
    tc = build_taxon_concept(:canonical_form => bad_title)
    tc.title.should =~ /#{good_title}/
  end
  
  it 'should have curators' do
    @taxon_concept.curators.map(&:id).should include(@curator.id)
  end
  
  it 'should have a scientific name (italicized for species)' do
    @taxon_concept.scientific_name.should == @italicized
  end
  
  it 'should have a common name' do
    @taxon_concept.common_name.should == @common_name
  end
  
  it 'should show the common name from the current users language' do
    lang = Language.gen_if_not_exists(:label => 'Ancient Egyptian')
    user = User.gen(:language => lang)
    str  = 'Frebblebup'
    @taxon_concept.add_common_name_synonym(str, :agent => user.agent, :language => lang)
    @taxon_concept.current_user = user
    @taxon_concept.common_name.should == str
  end
  
  it 'should let you get/set the current user' do
    user = User.gen
    @taxon_concept.current_user = user
    @taxon_concept.current_user.should == user
    @taxon_concept.current_user = nil
  end
  
  it 'should have a default IUCN conservation status of NOT EVALUATED' do
    @taxon_concept.iucn_conservation_status.should == 'NOT EVALUATED'
  end
  
  it 'should have an IUCN conservation status' do
    @taxon_concept = TaxonConcept.find(@taxon_concept.id)
    iucn_status = Factory.next(:iucn)
    he = build_iucn_entry(@taxon_concept, iucn_status)
    @taxon_concept.iucn_conservation_status.should == iucn_status
    he.delete
  end
  
  it 'should NOT have an IUCN conservation status even if it comes from another IUCN resource' do
    @taxon_concept = TaxonConcept.find(@taxon_concept.id)
    iucn_status = Factory.next(:iucn)
    (hierarchy, resource) = build_secondary_iucn_hierarchy_and_resource
    he = build_iucn_entry(@taxon_concept, iucn_status, :hierarchy => hierarchy,
                                                  :event => HarvestEvent.gen(:resource => resource))
    @taxon_concept.iucn_conservation_status.should == 'NOT EVALUATED'
    he.delete
  end
  
  it 'should have only one IUCN conservation status when there could have been many (doesnt matter which)' do
    @taxon_concept = TaxonConcept.find(@taxon_concept.id)
    he1 = build_iucn_entry(@taxon_concept, Factory.next(:iucn))
    he2 = build_iucn_entry(@taxon_concept, Factory.next(:iucn))
    result = @taxon_concept.iucn
    result.should be_an_instance_of DataObject # (not an Array, mind you.)
    he1.delete
    he2.delete
  end
  
  it 'should not use an unpublished IUCN status' do
    @taxon_concept = TaxonConcept.find(@taxon_concept.id)
    bad_iucn = build_iucn_entry(@taxon_concept, 'bad value')
    @taxon_concept.iucn_conservation_status.should == 'bad value'
    bad_iucn.delete
    
    # We *must* know that it would have worked if it *were* published, otherwise the test proves nothing:
    bad_iucn2 = build_iucn_entry(@taxon_concept, 'bad value')
    bad_iucn2.published = 0
    bad_iucn2.save
    @taxon_concept = TaxonConcept.find(@taxon_concept.id)
    @taxon_concept.iucn_conservation_status.should == 'NOT EVALUATED'
  end
  
  it 'should be able to list its ancestors (by convention, ending with itself)' do
    he = @taxon_concept.entry
    kingdom = HierarchyEntry.gen(:hierarchy => he.hierarchy, :parent_id => 0)
    phylum = HierarchyEntry.gen(:hierarchy => he.hierarchy, :parent_id => kingdom.id)
    order = HierarchyEntry.gen(:hierarchy => he.hierarchy, :parent_id => phylum.id)
    he.parent_id = order.id
    he.save
    # # @phylum  = build_taxon_concept(:rank => 'phylum',  :depth => 1, :parent_hierarchy_entry_id => @kingdom.entry.id)
    # # @order   = build_taxon_concept(:rank => 'order',   :depth => 2, :parent_hierarchy_entry_id => @phylum.entry.id)
    # # Now we attach our TC to those:
    # he = @taxon_concept.entry
    # he.parent_id = @order.entry.id
    # he.save
    make_all_nested_sets
    flatten_hierarchies
    @taxon_concept.reload
    @taxon_concept.ancestors.map(&:id).should == [kingdom.taxon_concept_id, phylum.taxon_concept_id, order.taxon_concept_id, @taxon_concept.id]
  end
  
  it 'should be able to list its children (NOT descendants, JUST children--animalia would be a disaster!)' do
    he = @taxon_concept.entry
    subspecies1 = HierarchyEntry.gen(:hierarchy => he.hierarchy, :parent_id => he.id)
    subspecies2 = HierarchyEntry.gen(:hierarchy => he.hierarchy, :parent_id => he.id)
    subspecies3 = HierarchyEntry.gen(:hierarchy => he.hierarchy, :parent_id => he.id)
    infraspecies = HierarchyEntry.gen(:hierarchy => he.hierarchy, :parent_id => subspecies1.id)
    @taxon_concept.reload
    @taxon_concept.children.map(&:id).should only_include subspecies1.taxon_concept_id, subspecies2.taxon_concept_id, subspecies3.taxon_concept_id
  end
  
  it 'should find its GBIF map ID' do
    @taxon_concept.gbif_map_id.should == @gbif_map_id
  end
  
  it 'should be able to show videos' do
    @taxon_concept.video_data_objects.should_not be_nil
    @taxon_concept.video_data_objects.map(&:description).should only_include @video_1_text, @video_2_text, @video_3_text
  end
  
  it 'should have visible comments that don\'t show invisible comments' do
    user = User.gen
    @taxon_concept.visible_comments.should_not be_nil
    @taxon_concept.visible_comments.map(&:body).should == [@comment_1, @comment_2] # Order DOES matter, now.
  end
  
  it 'should be able to show a table of contents' do
    # Tricky, tricky. See, we add special things to the TOC like "Common Names" and "Search the Web", when they are appropriate.  I
    # could test for those here, but that seems the perview of TocItem.  So, I'm only checking the first three elements:
    @taxon_concept.toc[0..2].should == [@overview, @toc_item_2, @toc_item_3]
  end
  
  # TODO - this is failing, but low-priority, I added a bug for it: EOLINFRASTRUCTURE-657
  # This was related to a bug (EOLINFRASTRUCTURE-598)
  #it 'should return the table of contents with unpublished items when a content partner is specified' do
    #cp   = ContentPartner.gen
    #toci = TocItem.gen
    #dato = build_data_object('Text', 'This is our target text',
                             #:hierarchy_entry => @taxon_concept.hierarchy_entries.first, :content_partner => cp,
                             #:published => false, :vetted => Vetted.unknown, :toc_item => toci)
    #@taxon_concept.toc.map(&:id).should_not include(toci.id)
    #@taxon_concept.current_agent = cp.agent
    #@taxon_concept.toc.map(&:id).should include(toci.id)
  #end
  
  it 'should show its untrusted images, by default' do
    @taxon_concept.current_user = User.create_new # It's okay if this one "sticks", so no cleanup code
    @taxon_concept.images.map(&:object_cache_url).should include(@image_unknown_trust)
  end
  
  it 'should show only trusted images if the user prefers' do
    old_user = @taxon_concept.current_user
    @taxon_concept.current_user = User.gen(:vetted => true)
    @taxon_concept.images.map(&:object_cache_url).should only_include(@image_1, @image_2, @image_3)
    @taxon_concept.current_user = old_user  # Cleaning up so as not to affect other tests
  end
  
  it 'should be able to get an overview' do
    results = @taxon_concept.overview
    results.length.should == 1
    results.first.description.should == @overview_text
  end
  
  # TODO - creating the CP -> Dato relationship is tricky. This should be made available elsewhere:
  it 'should show content partners THEIR preview items, but not OTHER content partner\'s preview items' do
    @taxon_concept.reload
    @taxon_concept.current_user = nil
    original_cp    = Agent.gen
    another_cp     = Agent.gen
    cp_hierarchy   = Hierarchy.gen(:agent => original_cp)
    resource       = Resource.gen(:hierarchy => cp_hierarchy)
    # Note this doesn't work without the ResourceAgentRole setting.  :\
    agent_resource = AgentsResource.gen(:agent_id => original_cp.id, :resource_id => resource.id,
                       :resource_agent_role_id => ResourceAgentRole.content_partner_upload_role.id)
    event          = HarvestEvent.gen(:resource => resource)
    # Note this *totally* doesn't work if you don't add it to top_unpublished_images!
    TopUnpublishedImage.gen(:hierarchy_entry => @taxon_concept.entry,
                            :data_object     => @taxon_concept.images.last)
    TopUnpublishedConceptImage.gen(:taxon_concept => @taxon_concept,
                            :data_object     => @taxon_concept.images.last)
    how_many = @taxon_concept.images.length
    how_many.should > 2
    dato            = @taxon_concept.images.last  # Let's grab the last one...
    # ... And remove it from top images:
    TopImage.delete_all(:hierarchy_entry_id => @taxon_concept.entry.id,
                        :data_object_id => @taxon_concept.images.last.id)
    TopConceptImage.delete_all(:taxon_concept_id => @taxon_concept.id,
                        :data_object_id => @taxon_concept.images.last.id)
    
    @taxon_concept.reload
    @taxon_concept.images.length.should == how_many - 1 # Ensuring that we removed it...
    
    dato.visibility = Visibility.preview
    dato.save!
    
    DataObjectsHarvestEvent.delete_all(:data_object_id => dato.id)
    DataObjectsHierarchyEntry.delete_all(:data_object_id => dato.id)
    he = HierarchyEntry.gen(:hierarchy => cp_hierarchy, :taxon_concept => @taxon_concept)
    DataObjectsHierarchyEntry.gen(:hierarchy_entry => he, :data_object => dato)
    DataObjectsHarvestEvent.gen(:harvest_event => event, :data_object => dato)
    HierarchyEntry.connection.execute("COMMIT")
    
    # Original should see it:
    @taxon_concept.reload
    @taxon_concept.current_agent = original_cp
    @taxon_concept.images(:agent => original_cp).map {|i| i.id }.should include(dato.id)
  
    # Another CP should not:
    tc = TaxonConcept.find(@taxon_concept.id) # hack to reload the object and delete instance variables
    tc.current_agent = another_cp
    tc.images.map {|i| i.id }.should_not include(dato.id)
  
  end
  
  it "should have common names" do
    TaxonConcept.common_names_for?(@taxon_concept.id).should == true
  end
  
  it "should not have common names" do
    tc = build_taxon_concept(:toc=> [
      {:toc_item => TocItem.common_names}
    ])  
    TaxonConcept.common_names_for?(tc.id).should == false
  end
  
  it 'should return images sorted by trusted, unknown, untrusted' do
    @taxon_concept.reload
    @taxon_concept.current_user = @user
    trusted   = Vetted.trusted.id
    unknown   = Vetted.unknown.id
    untrusted = Vetted.untrusted.id
    @taxon_concept.images.map {|i| i.vetted_id }.should == [trusted, trusted, trusted, unknown, untrusted]
  end
  
  it 'should sort the vetted images by data rating' do
    @taxon_concept.current_user = @user
    @taxon_concept.images[0..2].map(&:object_cache_url).should == [@image_3, @image_2, @image_1]
  end
  
  it 'should create a common name as a preferred common name, if there are no other common names for the taxon' do
    tc = build_taxon_concept(:common_names => [])
    agent = Agent.last # TODO - I don't like this.  We shouldn't need it for tests.  Overload the method for testing?
    tc.add_common_name_synonym('A name', :agent => agent, :language => Language.english)
    tc.quick_common_name.should == "A name"
    tc.add_common_name_synonym("Another name", :agent => agent, :language => Language.english)
    tc.quick_common_name.should == "A name"
  end
  
  it 'should determine and cache curation authorization' do
    @curator.can_curate?(@taxon_concept).should == true
    @curator.should_receive('can_curate?').and_return(true)
    @taxon_concept.show_curator_controls?(@curator).should == true
    @curator.should_not_receive('can_curate?')
    @taxon_concept.show_curator_controls?(@curator).should == true
  end
  
  it 'should return a toc item which accepts user submitted text' do
    @taxon_concept.tocitem_for_new_text.class.should == TocItem
    tc = build_taxon_concept(:images => [], :toc => [], :flash => [], :youtube => [], :comments => [], :bhl => [])
    tc.tocitem_for_new_text.class.should == TocItem
  end
  
  it 'should return description as first toc item which accepts user submitted text' do
    description_toc = TocItem.find_by_translated(:label, 'Description')
    InfoItem.gen(:toc_id => @overview.id)
    InfoItem.gen(:toc_id => description_toc.id)
    tc = build_taxon_concept(:images => [], :flash => [], :youtube => [], :comments => [], :bhl => [],
                             :toc => [{:toc_item => description_toc, :description => 'huh?'}])
    tc.tocitem_for_new_text.label.should == description_toc.label
  end
  
  it 'should include the LigerCat TocItem when the TaxonConcept has one'
  
  it 'should NOT include the LigerCat TocItem when the TaxonConcept does NOT have one'
  
  it 'should have a canonical form' do
    @taxon_concept.entry.name.canonical_form.string.should == @canonical_form
  end
  
  it 'should cite a vetted source for the page when there are both vetted and unvetted sources' do
    h_vetted = Hierarchy.gen()
    h_unvetted = Hierarchy.gen()
    concept = TaxonConcept.gen(:published => 1, :vetted => Vetted.trusted)
    concept.entry.should be_nil
    
    # adding an unvetted name and testing
    unvetted_name = Name.gen(:canonical_form => cf = CanonicalForm.gen(:string => 'Annnvettedname'),
                      :string => 'Annnvettedname',
                      :italicized => '<i>Annnvettedname</i>')
    he_unvetted = build_hierarchy_entry(0, concept, unvetted_name,
                                :hierarchy => h_unvetted,
                                :vetted_id => Vetted.unknown.id,
                                :published => 1)
    concept = TaxonConcept.find(concept.id) # cheating so I can flush all the instance variables
    concept.entry.should_not be_nil
    concept.entry.id.should == he_unvetted.id
    concept.entry.name.string.should == unvetted_name.string
    
    # adding a vetted name and testing
    vetted_name = Name.gen(:canonical_form => cf = CanonicalForm.gen(:string => 'Avettedname'),
                      :string => 'Avettedname',
                      :italicized => '<i>Avettedname</i>')
    he_vetted = build_hierarchy_entry(0, concept, vetted_name,
                                :hierarchy => h_vetted,
                                :vetted_id => Vetted.trusted.id,
                                :published => 1)
    concept = TaxonConcept.find(concept.id) # cheating so I can flush all the instance variables
    concept.entry.id.should == he_vetted.id
    concept.entry.name.string.should == vetted_name.string
    
    # adding another unvetted name to test the vetted name remains
    another_unvetted_name = Name.gen(:canonical_form => cf = CanonicalForm.gen(:string => 'Anotherunvettedname'),
                      :string => 'Anotherunvettedname',
                      :italicized => '<i>Anotherunvettedname</i>')
    he_anotherunvetted = build_hierarchy_entry(0, concept, another_unvetted_name,
                                :hierarchy => h_vetted,
                                :vetted_id => Vetted.unknown.id,
                                :published => 1)
    concept = TaxonConcept.find(concept.id) # cheating so I can flush all the instance variables
    concept.entry.id.should == he_vetted.id
    concept.entry.name.string.should == vetted_name.string
    
    # now remove the vetted hierarchy entry and make sure the first entry is the chosen one
    he_vetted.destroy
    concept = TaxonConcept.find(concept.id) # cheating so I can flush all the instance variables
    concept.entry.id.should == he_unvetted.id
    concept.entry.name.string.should == unvetted_name.string
  end
  
  # TODO - this is failing, but low-priority, I added a bug for it: EOLINFRASTRUCTURE-657
  # This was related to a bug (EOLINFRASTRUCTURE-598)
  #it 'should return the table of contents with unpublished items when a content partner is specified' do
    #cp   = ContentPartner.gen
    #toci = TocItem.gen
    #dato = build_data_object('Text', 'This is our target text',
                             #:hierarchy_entry => @taxon_concept.hierarchy_entries.first, :content_partner => cp,
                             #:published => false, :vetted => Vetted.unknown, :toc_item => toci)
    #@taxon_concept.toc.map(&:id).should_not include(toci.id)
    #@taxon_concept.current_agent = cp.agent
    #@taxon_concept.toc.map(&:id).should include(toci.id)
  #end
  
  it "add common name should increase name count, taxon name count, synonym count" do
    tcn_count = TaxonConceptName.count
    syn_count = Synonym.count
    name_count = Name.count
    
    @taxon_concept.add_common_name_synonym('any name', :agent => @agent, :language => Language.english)
    
    TaxonConceptName.count.should == tcn_count + 1
    Synonym.count.should == syn_count + 1
    Name.count.should == name_count + 1
  end
  
  it "add common name should mark first created name for a language as preferred automatically" do
    language = Language.gen_if_not_exists(:label => "Russian") 
    weird_name = "Саблезубая сосиска"
    s = @taxon_concept.add_common_name_synonym(weird_name, :agent => @agent, :language => language)
    TaxonConceptName.find_all_by_taxon_concept_id_and_language_id(@taxon_concept, language).size.should == 1
    TaxonConceptName.find_by_synonym_id(s.id).preferred?.should be_true
    weird_name = "Голый землекоп"
    s = @taxon_concept.add_common_name_synonym(weird_name, :agent => @agent, :language => language)
    TaxonConceptName.find_all_by_taxon_concept_id_and_language_id(@taxon_concept, language).size.should == 2
    TaxonConceptName.find_by_synonym_id(s.id).preferred?.should be_false
  end
  
  it "add common name should not mark first created name as preffered for unknown language" do
    language = Language.unknown
    weird_name = "Саблезубая сосискаasdfasd"
    s = @taxon_concept.add_common_name_synonym(weird_name, :agent => @agent, :language => language)
    TaxonConceptName.find_all_by_taxon_concept_id_and_language_id(@taxon_concept, language).size.should == 1
    TaxonConceptName.find_by_synonym_id(s.id).preferred?.should be_false
  end
  
  it "add common name should create new name object" do
    @name.class.should == Name
    @name.string.should == @name_string
  end
  
  it "add common name should create synonym" do
    @synonym.class.should == Synonym
    @synonym.name.should == @name
    @synonym.agents.should == [@curator.agent]
  end
  
  it "add common name should create taxon_concept_name" do
    @tcn.should_not be_nil
  end
  
  it "add common name should be able to create a common name with the same name string but different language" do
    tcn_count = TaxonConceptName.count
    syn_count = Synonym.count
    name_count = Name.count
    
    syn = @taxon_concept.add_common_name_synonym(@name_string, :agent => Agent.find(@curator.agent_id), :language => Language.gen_if_not_exists(:label => "French"))
    TaxonConceptName.count.should == tcn_count + 1
    Synonym.count.should == syn_count + 1
    Name.count.should == name_count  # name wasn't new
  end
  
  it "delete common name should delete a common name" do
    tcn_count = TaxonConceptName.count
    syn_count = Synonym.count
    name_count = Name.count
    
    @taxon_concept.delete_common_name(@tcn)
    TaxonConceptName.count.should == tcn_count - 1
    Synonym.count.should == syn_count - 1
    Name.count.should == name_count  # name is not deleted
  end
  
  it "delete common name should delete preferred common names, should mark last common name for a language as preferred" do
    # remove all existing English common names
    TaxonConceptName.find_all_by_taxon_concept_id_and_language_id(@taxon_concept, Language.english).each do |tcn|
      tcn.delete
    end
    
    # first one should go in as preferred
    first_syn = @taxon_concept.add_common_name_synonym('First english name', :agent => @agent, :language => Language.english)
    first_tcn = TaxonConceptName.find_by_synonym_id(first_syn.id)
    first_tcn.preferred?.should be_true
    
    # second should not be preferred
    second_syn = @taxon_concept.add_common_name_synonym('Second english name', :agent => @agent, :language => Language.english)
    second_tcn = TaxonConceptName.find_by_synonym_id(second_syn.id)
    second_tcn.preferred?.should be_false
    
    # after removing the first, the last one should change to preferred
    @taxon_concept.delete_common_name(first_tcn)
    second_tcn.reload
    second_tcn.preferred?.should be_true
  end
  
  it 'should untrust all synonyms and TCNs related to a TC when untrusted' do
    # Make them all "trusted" first:
    [@syn1, @syn2, @tcn1, @tcn2].each {|obj| obj.update_attributes!(:vetted => Vetted.trusted) }
    @taxon_concept.vet_common_name(:vetted => Vetted.untrusted, :language_id => Language.english.id, :name_id => @name_obj.id)
    @syn1.reload.vetted_id.should == Vetted.untrusted.id
    @syn2.reload.vetted_id.should == Vetted.untrusted.id
    @tcn1.reload.vetted_id.should == Vetted.untrusted.id
    @tcn2.reload.vetted_id.should == Vetted.untrusted.id
  end
  
  it 'should "unreview" all synonyms and TCNs related to a TC when unreviewed' do
    # Make them all "trusted" first:
    [@syn1, @syn2, @tcn1, @tcn2].each {|obj| obj.update_attributes!(:vetted => Vetted.trusted) }
    @taxon_concept.vet_common_name(:vetted => Vetted.unknown, :language_id => Language.english.id, :name_id => @name_obj.id)
    @syn1.reload.vetted_id.should == Vetted.unknown.id
    @syn2.reload.vetted_id.should == Vetted.unknown.id
    @tcn1.reload.vetted_id.should == Vetted.unknown.id
    @tcn2.reload.vetted_id.should == Vetted.unknown.id
  end
  
  it 'should trust all synonyms and TCNs related to a TC when trusted' do
    # Make them all "unknown" first:
    [@syn1, @syn2, @tcn1, @tcn2].each {|obj| obj.update_attributes!(:vetted => Vetted.unknown) }
    @taxon_concept.vet_common_name(:vetted => Vetted.trusted, :language_id => Language.english.id, :name_id => @name_obj.id)
    @syn1.reload.vetted_id.should == Vetted.trusted.id
    @syn2.reload.vetted_id.should == Vetted.trusted.id
    @tcn1.reload.vetted_id.should == Vetted.trusted.id
    @tcn2.reload.vetted_id.should == Vetted.trusted.id
  end
  
  it 'should have a feed' do
    tc = TaxonConcept.gen
    tc.respond_to?(:feed).should be_true
    tc.feed.should be_a EOL::Feed
  end
  
  #
  # I'm all for pending tests, but in this case, they run SLOWLY, so it's best to comment them out:
  #
  
  # Medium Priority:
  #
  # it 'should be able to list whom the species is recognized by' do
  # it 'should be able to add a comment' do
  # it 'should be able to list exemplars' do
  #
  # Lower priority (at least for me!)
  #
  # it 'should know which hosts to ping' do
  # it 'should be able to set a current agent' # This is only worthwhile if we know what it should change... do
  # it 'should follow supercedure' do
  # it 'should be able to show a thumbnail' do
  # it 'should be able to show a single image' do

end
