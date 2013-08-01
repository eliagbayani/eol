require File.dirname(__FILE__) + '/../../spec_helper'

def media_do_index
  get :index, :taxon_id => @data[:taxon_concept].id
end

describe Taxa::MediaController do

  before(:all) do
    truncate_all_tables
    load_scenario_with_caching :media_heavy
    @data = EOL::TestInfo.load('media_heavy')
    @taxon_concept = @data[:taxon_concept]
    EOL::Solr::DataObjectsCoreRebuilder.begin_rebuild
  end

  describe 'GET index' do

    before(:all) do
      @taxon_concept.reload

      # we assume for tests that sort methods on models are working and we are just testing
      # that the controller handles parameters correctly and calls the right sort method

      # rank objects in order: 1 - oldest image; 2 - oldest video; 3 - oldest sound
      # assumes exemplar is nil
      taxon_media_parameters = {}
      taxon_media_parameters[:per_page] = 100
      taxon_media_parameters[:data_type_ids] = DataType.image_type_ids + DataType.video_type_ids + DataType.sound_type_ids
      taxon_media_parameters[:return_hierarchically_aggregated_objects] = true
      @trusted_count = @taxon_concept.data_objects_from_solr(taxon_media_parameters).select{ |item|
        item_vetted = item.vetted_by_taxon_concept(@taxon_concept)
        item_vetted.id == Vetted.trusted.id
      }.count

      @media = @taxon_concept.data_objects_from_solr(taxon_media_parameters).sort_by{|m| m.id}
      @newest_media = @media.last(10).reverse
      @oldest_media = @media.first(3)

      @newest_image_poorly_rated_trusted = @taxon_concept.images_from_solr(100).last
      @oldest_image_highly_rated_unreviewed = @taxon_concept.images_from_solr.first
      @highly_ranked_image = @taxon_concept.images_from_solr.second
      @newest_image_poorly_rated_trusted.data_rating = 0
      @newest_image_poorly_rated_trusted.vet_by_taxon_concept(@taxon_concept, Vetted.trusted)
      @newest_image_poorly_rated_trusted.save
      @oldest_image_highly_rated_unreviewed.data_rating = 20
      @oldest_image_highly_rated_unreviewed.vet_by_taxon_concept(@taxon_concept, Vetted.unknown)
      @oldest_image_highly_rated_unreviewed.save
      @highly_ranked_image.data_rating = 8
      @highly_ranked_image.vet_by_taxon_concept(@taxon_concept, Vetted.trusted)
      @highly_ranked_image.save

      @newest_video_poorly_rated_trusted = @taxon_concept.data_objects.select{ |d| d.is_video? }.last
      @oldest_video_highly_rated_unreviewed = @taxon_concept.data_objects.select{ |d| d.is_video? }.first
      @highly_ranked_video = @taxon_concept.data_objects.select{ |d| d.is_video? }.second
      @newest_video_poorly_rated_trusted.data_rating = 0
      @newest_video_poorly_rated_trusted.vet_by_taxon_concept(@taxon_concept, Vetted.trusted)
      @newest_video_poorly_rated_trusted.save
      @oldest_video_highly_rated_unreviewed.data_rating = 19
      @oldest_video_highly_rated_unreviewed.vet_by_taxon_concept(@taxon_concept, Vetted.unknown)
      @oldest_video_highly_rated_unreviewed.save
      @highly_ranked_video.data_rating = 7
      @highly_ranked_video.vet_by_taxon_concept(@taxon_concept, Vetted.trusted)
      @highly_ranked_video.save

      @newest_sound_poorly_rated_trusted = @taxon_concept.data_objects.select{ |d| d.is_sound? }.last
      @oldest_sound_highly_rated_unreviewed = @taxon_concept.data_objects.select{ |d| d.is_sound? }.first
      @highly_ranked_sound = @taxon_concept.data_objects.select{ |d| d.is_sound? }.second
      @newest_sound_poorly_rated_trusted.data_rating = 0
      @newest_sound_poorly_rated_trusted.vet_by_taxon_concept(@taxon_concept, Vetted.trusted)
      @newest_sound_poorly_rated_trusted.save
      @oldest_sound_highly_rated_unreviewed.data_rating = 18
      @oldest_sound_highly_rated_unreviewed.vet_by_taxon_concept(@taxon_concept, Vetted.unknown)
      @oldest_sound_highly_rated_unreviewed.save
      @highly_ranked_sound.data_rating = 6
      @highly_ranked_sound.vet_by_taxon_concept(@taxon_concept, Vetted.trusted)
      @highly_ranked_sound.save

      @highly_ranked_text = @taxon_concept.data_objects.detect{ |d| d.is_text? }
      @highly_ranked_text.data_rating = 21
      @highly_ranked_text.vet_by_taxon_concept(@taxon_concept, Vetted.trusted)
      @highly_ranked_text.save
      EOL::Solr::DataObjectsCoreRebuilder.begin_rebuild
    end

    it 'should instantiate the taxon concept' do
      media_do_index
      assigns[:taxon_concept].should be_a(TaxonConcept)
    end

    it 'should instantiate a TaxonMedia object' do
      media_do_index
      assigns[:taxon_media].should be_a(TaxonMedia)
    end

    it 'should instantiate an assistive header' do
      media_do_index
      assigns[:assistive_section_header].should be_a(String)
    end
  end

end
