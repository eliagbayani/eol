# Very stupid modle that just gives us a DataPointUri stored in the DB, for linking comments to. These are otherwise
# generated/stored in via SparQL.
class DataPointUri < ActiveRecord::Base

  include EOL::CuratableAssociation

  attr_accessible :string, :vetted_id, :visibility_id, :vetted, :visibility, :uri, :taxon_concept_id,
    :class_type, :predicate, :object, :unit_of_measure, :user_added_data_id, :resource_id,
    :predicate_known_uri_id, :object_known_uri_id, :unit_of_measure_known_uri_id

  belongs_to :taxon_concept
  belongs_to :vetted
  belongs_to :visibility
  belongs_to :resource
  belongs_to :user_added_data
  belongs_to :predicate_known_uri, :class_name => KnownUri.to_s, :foreign_key => :predicate_known_uri_id
  belongs_to :object_known_uri, :class_name => KnownUri.to_s, :foreign_key => :object_known_uri_id
  belongs_to :unit_of_measure_known_uri, :class_name => KnownUri.to_s, :foreign_key => :unit_of_measure_known_uri_id
  # this only applies to Associations, but is written as belongs_to to take advantage of preloading
  belongs_to :target_taxon_concept, :class_name => TaxonConcept.to_s, :foreign_key => :object

  has_many :comments, :as => :parent
  has_many :all_versions, :class_name => DataPointUri.to_s, :foreign_key => :uri, :primary_key => :uri
  has_many :all_comments, :class_name => Comment.to_s, :through => :all_versions, :primary_key => :uri, :source => :comments
  has_many :taxon_data_exemplars

  # Required for commentable items. NOTE - This requires four queries from the DB, unless you preload the
  # information.  TODO - preload these:
  # TaxonConcept Load (10.3ms)  SELECT `taxon_concepts`.* FROM `taxon_concepts` WHERE `taxon_concepts`.`id` = 17
  # LIMIT 1
  # TaxonConceptPreferredEntry Load (15.0ms)  SELECT `taxon_concept_preferred_entries`.* FROM
  # `taxon_concept_preferred_entries` WHERE `taxon_concept_preferred_entries`.`taxon_concept_id` = 17 LIMIT 1
  # HierarchyEntry Load (0.8ms)  SELECT `hierarchy_entries`.* FROM `hierarchy_entries` WHERE
  # `hierarchy_entries`.`id` = 12 LIMIT 1
  # Name Load (0.5ms)  SELECT `names`.* FROM `names` WHERE `names`.`id` = 25 LIMIT 1
  def summary_name
    I18n.t(:data_point_uri_summary_name, :taxon => taxon_concept.summary_name)
  end

  def anchor
    "data_point_#{id}"
  end

  def source
    return user_added_data.user if user_added_data
    return resource.content_partner if resource
  end

  def predicate_uri
    predicate_known_uri || predicate
  end

  def object_uri
    object_known_uri || object
  end

  def unit_of_measure_uri
    unit_of_measure_known_uri || unit_of_measure
  end

  def measurement?
    class_type == 'MeasurementOrFact'
  end

  def association?
    class_type == 'Association'
  end

  def get_metadata(language)
    query = "
      SELECT DISTINCT ?attribute ?value
      WHERE {
        GRAPH ?graph {
          {
            <#{uri}> ?attribute ?value .
          } UNION {
            <#{uri}> dwc:occurrenceID ?occurrence .
            ?occurrence ?attribute ?value .
          } UNION {
            ?measurement a <#{DataMeasurement::CLASS_URI}> .
            ?measurement <#{Rails.configuration.uri_parent_measurement_id}> <#{uri}> .
            ?measurement dwc:measurementType ?attribute .
            ?measurement dwc:measurementValue ?value .
          } UNION {
            <#{uri}> dwc:occurrenceID ?occurrence .
            ?measurement a <#{DataMeasurement::CLASS_URI}> .
            ?measurement dwc:occurrenceID ?occurrence .
            ?measurement dwc:measurementType ?attribute .
            ?measurement dwc:measurementValue ?value .
            OPTIONAL { ?measurement <#{Rails.configuration.uri_measurement_of_taxon}> ?measurementOfTaxon } .
            FILTER (?measurementOfTaxon != 'true')
          } UNION {
            ?measurement a <#{DataMeasurement::CLASS_URI}> .
            ?measurement <#{Rails.configuration.uri_association_id}> <#{uri}> .
            ?measurement dwc:measurementType ?attribute .
            ?measurement dwc:measurementValue ?value .
          } UNION {
            <#{uri}> dwc:occurrenceID ?occurrence .
            ?occurrence dwc:eventID ?event .
            ?event ?attribute ?value .
          }
          FILTER (?attribute NOT IN (rdf:type, dwc:taxonConceptID, dwc:measurementType, dwc:measurementValue,
                                     dwc:measurementID, <#{Rails.configuration.uri_reference_id}>,
                                     <#{Rails.configuration.uri_target_occurence}>, dwc:taxonID, dwc:eventID,
                                     <#{Rails.configuration.uri_association_type}>,
                                     dwc:measurementUnit, dwc:occurrenceID, <#{Rails.configuration.uri_measurement_of_taxon}>))
        }
      }"
    metadata_rows = EOL::Sparql.connection.query(query)
    metadata_rows = DataPointUri.replace_licenses_with_mock_known_uris(metadata_rows, language)
    KnownUri.add_to_data(metadata_rows)
    return nil if metadata_rows.empty?
    metadata_rows.map{ |row| DataPointUri.new(DataPointUri.attributes_from_virtuoso_response(row)) }
  end

  def get_other_occurrence_measurements(language)
    query = "
      SELECT DISTINCT ?attribute ?value ?unit_of_measure_uri
      WHERE {
        GRAPH ?graph {
          {
            <#{uri}> dwc:occurrenceID ?occurrence .
            ?measurement a <#{DataMeasurement::CLASS_URI}> .
            ?measurement dwc:occurrenceID ?occurrence .
            ?measurement dwc:measurementType ?attribute .
            ?measurement dwc:measurementValue ?value .
            ?measurement <#{Rails.configuration.uri_measurement_of_taxon}> ?measurementOfTaxon .
            FILTER ( ?measurementOfTaxon = 'true' ) .
            OPTIONAL {
              ?measurement dwc:measurementUnit ?unit_of_measure_uri
            }
          }
        }
      }"
    occurrence_measurement_rows = EOL::Sparql.connection.query(query)
    # if there is only one response, then it is the original measurement
    return nil if occurrence_measurement_rows.length <= 1
    KnownUri.add_to_data(occurrence_measurement_rows)
    occurrence_measurement_rows.map{ |row| DataPointUri.new(DataPointUri.attributes_from_virtuoso_response(row)) }
  end

  def get_references(language)
    options = []
    # TODO - no need to keep rebuilding this, put it in a class variable.
    Rails.configuration.optional_reference_uris.each do |var, url|
      options << "OPTIONAL { ?reference <#{url}> ?#{var} } ."
    end
    query = "
      SELECT DISTINCT ?identifier ?publicationType ?full_reference ?primaryTitle ?title ?pages ?pageStart ?pageEnd
         ?volume ?edition ?publisher ?authorList ?editorList ?created ?language ?uri ?doi ?localityName
      WHERE {
        GRAPH ?graph {
          {
            <#{uri}> <#{Rails.configuration.uri_reference_id}> ?reference .
            ?reference a <#{Rails.configuration.uri_reference}>
            #{options.join("\n")}
          }
        }
      }"
    reference_rows = EOL::Sparql.connection.query(query)
    return nil if reference_rows.empty?
    reference_rows
  end

  # Licenses are special (NOTE we also cache them here on a per-page basis...):
  def self.replace_licenses_with_mock_known_uris(metadata_rows, language)
    metadata_rows.each do |row|
      if row[:attribute] == UserAddedDataMetadata::LICENSE_URI && license = License.find_by_source_url(row[:value].to_s)
        row[:value] = KnownUri.new(:uri => row[:value],
          :translations => [ TranslatedKnownUri.new(:name => license.title, :language => language) ])
      end
    end
    metadata_rows
  end

  def update_with_virtuoso_response(row)
    new_attributes = DataPointUri.attributes_from_virtuoso_response(row)
    new_attributes.each do |k, v|
      send("#{k}=", v)
    end
    save if changed?
  end

  def self.create_from_virtuoso_response(row)
    new_attributes = DataPointUri.attributes_from_virtuoso_response(row)
    if data_point_uri = DataPointUri.find_by_uri(new_attributes[:uri])
      data_point_uri.update_with_virtuoso_response(row)
    else
      data_point_uri = DataPointUri.create(new_attributes)
    end
    data_point_uri
  end

  def self.attributes_from_virtuoso_response(row)
    attributes = { uri: row[:data_point_uri].to_s }
    # taxon_concept_id may come from solr as a URI, or set elsewhere as an Integer
    if row[:taxon_concept_id]
      if taxon_concept_id = KnownUri.taxon_concept_id(row[:taxon_concept_id])
        attributes[:taxon_concept_id] = taxon_concept_id
      elsif row[:taxon_concept_id].is_a?(Integer)
        attributes[:taxon_concept_id] = row[:taxon_concept_id]
      end
    end
    virtuoso_to_data_point_mapping = {
      :attribute => :predicate,
      :unit_of_measure_uri => :unit_of_measure,
      :value => :object }
    virtuoso_to_data_point_mapping.each do |virtuoso_response_key, data_point_uri_key|
      next if row[virtuoso_response_key].blank?
      # this requires that
      if row[virtuoso_response_key].is_a?(KnownUri)
        attributes[data_point_uri_key] = row[virtuoso_response_key].uri
        # each of these attributes has a corresponging known_uri_id (e.g. predicate_known_uri_id)
        attributes[(data_point_uri_key.to_s + "_known_uri_id").to_sym] = row[virtuoso_response_key].id
      else
        attributes[data_point_uri_key] = row[virtuoso_response_key].to_s
      end
    end

    if row[:target_taxon_concept_id]
      attributes[:class_type] = 'Association'
      attributes[:object] = row[:target_taxon_concept_id].to_s.split("/").last
    else
      attributes[:class_type] = 'MeasurementOrFact'
    end
    if row[:graph] == Rails.configuration.user_added_data_graph
      attributes[:user_added_data_id] = row[:data_point_uri].to_s.split("/").last
    else
      attributes[:resource_id] = row[:graph].to_s.split("/").last
    end
    attributes
  end

end