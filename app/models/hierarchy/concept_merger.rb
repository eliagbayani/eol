class Hierarchy
  class ConceptMerger
    def self.merges_for_hierarchy(hierarchy)
      assigner = self.new(hierarchy)
      assigner.merges_for_hierarchy
    end

    def initialize(hierarchy)
      @hierarchy = hierarchy
      @compared = []
      @confirmed_exclusions = {}
      @entries_matched = []
      @superceded = {}
      @visible_id = Visibility.get_visible.id
      @preview_id = Visibility.get_preview.id
      @rel_page_size = Rails.configuration.solr_relationships_page_size
      @solr = SolrCore::HierarchyEntryRelationships.new
    end

    # NOTE: this used to use DB transactions, but A) it was doing it wrong
    # (nested), and B) it did them "every 50 batches", which is awkward and...
    # well... useless anyway. I am going to do this WITHOUT A TRANSACTION. Deal
    # with it. NOTE: this relies on hierarchy_entries_counts being correct. ...I
    # am making that assumption because I just saw the code in harvesting that
    # sets it, so I think it's there. :) However, you may still wish TODO to fix
    # counts periodically (say, once a month).
    def merges_for_hierarchy
      EOL.log_call
      fix_entry_counts if fix_entry_counts_needed?
      lookup_preview_harvests
      get_confirmed_exclusions
      # TODO: DON'T hard-code this (this is GBIF Nub Taxonomy). Instead, add an
      # attribute to hierarchies called "never_merge_concepts" and check that.
      # Also make sure curators can set that value from the resource page.
      @hierarchies = Hierarchy.where(["id NOT in (?)", 129]).
        order("hierarchy_entries_count DESC")
      @hierarchies.each do |other_hierarchy|
        # "Incomplete" hierarchies (e.g.: Flickr) actually can have multiple
        # entries that are actuall the "same", so we need to compare those to
        # themselves; otherwise, skip:
        next if @hierarchy.id == other_hierarchy.id && @hierarchy.complete?
        # TODO: this shouldn't even be required.
        next if already_compared?(@hierarchy.id, other_hierarchy.id)
        compare_hierarchies(@hierarchy, other_hierarchy)
      end
    end

    private

    # This is not the greatest way to check accuracy, but catches most problem
    # scenarios and is faster than always fixing:
    def fix_entry_counts_needed?
      Hierarchy.where(hierarchy_entries_count: 0).find_each do |hier|
        return true if hier.hierarchy_entries.count > 0
      end
      false
    end

    def fix_entry_counts
      HierarchyEntry.counter_culture_fix_counts
    end

    def compare_hierarchies(h1, h2)
      (hierarchy1, hierarchy2) = fewer_entries_first(h1, h2)
      EOL.log("Comparing hierarchy #{hierarchy1.id} (#{hierarchy1.label}; "\
        "#{hierarchy1.hierarchy_entries_count} entries) to #{hierarchy2.id} "\
        "(#{hierarchy2.label}; #{hierarchy2.hierarchy_entries_count} "\
        "entries)")
      # TODO: add (relationship:name OR confidence:[0.25 TO *]) [see below]
      # TODO: Set?
      entries = [] # Just to prevent weird infinite loops below. :\
      begin
        page ||= 0
        page += 1
        get_page_of_relationships_from_solr(hierarchy1, hierarchy2, page).
          each do |relationship|
          merge_matching_concepts(relationship)
        end
      end while entries.count > 0
    end

    # NOTE: This is a REALLY slow query. ...Which sucks. :\ Yes, even for
    # Solr... it takes a VERY long time.
    def get_page_of_relationships_from_solr(hierarchy1, hierarchy2, page)
      EOL.log_call
      response = @solr.paginate(compare_hierarchies_query(hierarchy1,
        hierarchy2), compare_hierarchies_options(page))
      rhead = response["responseHeader"]
      if rhead["QTime"] && rhead["QTime"].to_i > 1000
        EOL.log("gporfs query: #{rhead["q"]}", prefix: ".")
        EOL.log("gporfs Request took #{rhead["QTime"]}ms", prefix: ".")
      end
      response["response"]["docs"]
    end

    def compare_hierarchies_query(hierarchy1, hierarchy2)
      query = "hierarchy_id_1:#{hierarchy1.id} AND "\
        "(visibility_id_1:#{@visible_id} OR visibility_id_1:#{@preview_id}) "\
        "AND hierarchy_id_2:#{hierarchy2.id} AND "\
        "(visibility_id_2:#{@visible_id} OR visibility_id_2:#{@preview_id}) "\
        "AND same_concept:false"
      query
    end

    def compare_hierarchies_options(page)
      { sort: "relationship asc, visibility_id_1 asc, "\
        "visibility_id_2 asc, confidence desc, hierarchy_entry_id_1 asc, "\
        "hierarchy_entry_id_2 asc"}.merge(page: page, per_page: @rel_page_size)
    end

    def merge_matching_concepts(relationship)
      # Sample "relationship": { "hierarchy_entry_id_1"=>47111837,
      # "taxon_concept_id_1"=>71511, "hierarchy_id_1"=>949,
      # "visibility_id_1"=>1, "hierarchy_entry_id_2"=>20466468,
      # "taxon_concept_id_2"=>71511, "hierarchy_id_2"=>107,
      # "visibility_id_2"=>0, "same_concept"=>true, "relationship"=>"name",
      # "confidence"=>1.0 }
      # TODO: move this criterion to the solr query (see above):
      return(nil) if relationship["relationship"] == 'syn' &&
        relationship["confidence"] < 0.25
      (id1, tc_id1, hierarchy1, id2, tc_id2, hierarchy2) =
        *assign_local_vars_from_relationship(relationship)
      # skip if the node in the hierarchy has already been matched:
      return(nil) if hierarchy1.complete? && @entries_matched.include?(id2)
      return(nil) if hierarchy2.complete? && @entries_matched.include?(id1)
      @entries_matched += [id1, id2]
      # PHP: "this comparison happens here instead of the query to ensure the
      # sorting is always the same if this happened in the query and the entry
      # was related to more than one taxa, and this function is run more than
      # once then we'll start to get huge groups of concepts - all transitively
      # related to one another" ...Sounds to me like we're doing something
      # wrong, if this is true. :\
      return(nil) if tc_id1 == tc_id2
      tc_id1 = follow_supercedure_cached(tc_id1)
      tc_id2 = follow_supercedure_cached(tc_id2)
      return(nil) if tc_id1 == tc_id2
      EOL.log("Comparing entry #{tc_id1} (hierarchy #{hierarchy1.id}) "\
        "with #{id2} (hierarchy #{hierarchy2.id})", prefix: "?")
      return(nil) if concepts_of_one_already_in_other?(relationship)
      if curators_denied_relationship?(relationship)
        EOL.log("SKIP: merge of relationship #{id1} (concept #{tc_id1}) with "\
          " #{id2} (concept #{tc_id2}) rejected by curator", prefix: ".")
        return(nil)
      end
      if affected = additional_hierarchy_affected_by_merge(tc_id1, tc_id2)
        EOL.log("SKIP: A merge of #{id1} (concept #{tc_id1}) and #{id2} "\
          "(concept #{tc_id2}) is not allowed by complete hierarchy "\
          "#{affected.label} (#{affected.id})", prefix: ".")
        return(nil)
      end
      EOL.log("MATCH: Concept #{tc_id1} = #{tc_id2}")
      # TODO: store the supercedure somewhere so that we can use it later to
      # know what to clean up, e.g.: in CollectionItem.remove_superceded_taxa
      tc = TaxonConcept.merge_ids(tc_id1, tc_id2)
      @superceded[tc.id] = tc.supercedure_id
    end

    def assign_local_vars_from_relationship(relationship)
      [ relationship["hierarchy_entry_id_1"],
        relationship["taxon_concept_id_1"],
        find_hierarchy(relationship["hierarchy_id_1"]),
        relationship["hierarchy_entry_id_2"],
        relationship["taxon_concept_id_2"],
        find_hierarchy(relationship["hierarchy_id_2"]) ]
    end

    def find_hierarchy(id)
      @hierarchies.find { |h| h.id == id }
    end

    def lookup_preview_harvests
      @latest_preview_events_by_hierarchy = {}
      resources = Resource.select("resources.id, resources.hierarchy_id, "\
        "MAX(harvest_events.id) max").
        joins(:harvest_events).
        group(:hierarchy_id)
      HarvestEvent.unpublished.where(id: resources.map { |r| r["max"] }).
        each do |event|
        resource = resources.find { |r| r["max"] == event.id }
        @latest_preview_events_by_hierarchy[resource.hierarchy_id] = event
      end
    end

    def get_confirmed_exclusions
      CuratedHierarchyEntryRelationship.not_equivalent.
        includes(:from_hierarchy_entry, :to_hierarchy_entry).
        # Some of the entries have gone missing! Skip those:
        select { |ce| ce.from_hierarchy_entry && ce.to_hierarchy_entry }.
        each do |cher|
        from_entry = cher.from_hierarchy_entry.id
        from_tc = cher.from_hierarchy_entry.taxon_concept_id
        to_entry = cher.to_hierarchy_entry.id
        to_tc = cher.to_hierarchy_entry.taxon_concept_id
        @confirmed_exclusions[from_entry] ||= []
        @confirmed_exclusions[from_entry] << to_tc
        @confirmed_exclusions[to_entry] ||= []
        @confirmed_exclusions[to_entry] << from_tc
      end
    end

    def concepts_of_one_already_in_other?(relationship)
      (id1, tc_id1, hierarchy1, id2, tc_id2, hierarchy2) =
        *assign_local_vars_from_relationship(relationship)
      if entry_published_in_hierarchy?(1, relationship, hierarchy1)
        EOL.log("SKIP: concept #{tc_id2} published in hierarchy of #{id1}",
          prefix: ".")
        return true
      end
      if entry_published_in_hierarchy?(2, relationship, hierarchy2)
        EOL.log("SKIP: concept #{tc_id1} published in hierarchy "\
          "#{hierarchy2.id}", prefix: ".")
        return true
      end
      if entry_preview_in_hierarchy?(1, relationship, hierarchy1)
        EOL.log("SKIP: concept #{tc_id2} previewing in hierarchy "\
          "#{hierarchy1.id}", prefix: ".")
        return true
      end
      if entry_preview_in_hierarchy?(2, relationship, hierarchy2)
        EOL.log("SKIP: concept #{tc_id1} previewing in hierarchy "\
          "#{hierarchy2.id}", prefix: ".")
        return true
      end
      false
    end

    # NOTE: we could query the DB to buld this full list, using
    # TaxonConcept.superceded. It takes about 30 seconds, and returns 32M
    # results (as of this writing). ...We don't need all of them, though, so
    # doing this does potentially save us a bit of time.... I think. I guess it
    # depends on how many TaxonConcepts we call #find for. TODO: we could just
    # have a "supercedure" table. ...That would actually be pretty handy, though
    # it would be another case of having to pay attention to a denormalized
    # table, and I'm not sure it's worth that, either. Worth checking, I
    # suppose.
    def follow_supercedure_cached(id)
      new_id = if @superceded.has_key?(id)
        @superceded[id]
      else
        follow_supercedure(id)
      end
      while @superceded.has_key?(new_id)
        new_id = @superceded[new_id]
      end
      new_id
    end

    def follow_supercedure(id)
      tc = TaxonConcept.find(id)
      unless tc.id == id
        @superceded[id] = tc.id
      end
      tc.id
    end

    def fewer_entries_first(h1, h2)
      [h1, h2].sort_by(&:hierarchy_entries_count).reverse
    end

    def already_compared?(id1, id2)
      @compared.include?(compared_key(id1, id2))
    end

    # This doesn't actually matter, just needs to be consistent.
    def compared_key(id1, id2)
      [id1, id2].sort.join("&")
    end

    def mark_as_compared(id1, id2)
      @compared << compared_key(id1, id2)
    end

    def entry_published_in_hierarchy?(which, relationship, hierarchy)
      entry_has_vis_id_in_hierarchy?(which, relationship, @visible_id,
        hierarchy)
    end

    def entry_preview_in_hierarchy?(which, relationship, hierarchy)
      # TODO: I'm not sure this actually saves us much time. Worth it?
      return false unless
        @latest_preview_events_by_hierarchy.has_key?(hierarchy.id)
      entry_has_vis_id_in_hierarchy?(which, relationship, @preview_id,
        hierarchy)
    end

    def entry_has_vis_id_in_hierarchy?(which, relationship, vis_id, hierarchy)
      other = which == 1 ? 2 : 1
      hierarchy.complete &&
        relationship["visibility_id_#{which}"] == vis_id &&
        concept_has_vis_id_in_hierarchy(relationship["taxon_concept_id_#{other}"],
          vis_id, hierarchy)
    end

    def concept_has_vis_id_in_hierarchy?(taxon_concept_id, vis_id, hierarchy)
      HierarchyEntry.exists?(taxon_concept_id: taxon_concept_id,
        hierarchy_id: hierarchy.id, visibility_id: vis_id)
    end

    def curators_denied_relationship?(relationship)
      if @confirmed_exclusions.has_key?(relationship["hierarchy_entry_id_1"])
        return confirmed_exclusions_matches?(relationship["hierarchy_entry_id_1"],
          relationship["taxon_concept_id_2"])
      elsif @confirmed_exclusions.has_key?(relationship["hierarchy_entry_id_2"])
        return confirmed_exclusions_matches?(relationship["hierarchy_entry_id_2"],
          relationship["taxon_concept_id_1"])
      end
      false
    end

    def confirmed_exclusions_matches?(id, other_tc_id)
      @confirmed_exclusions[id1].each do |tc_id|
        tc_id = follow_supercedure_cached(tc_id)
        return true if tc_id == other_tc_id
      end
      false
    end

    # One taxon concept has an entry in a complete hierarchy and the other taxon
    # concept also has an entry in that hierarchy. ...Merging them would violate
    # the other hierarchy's assertion that they are different entities.
    def additional_hierarchy_affected_by_merge(tc_id1, tc_id2)
      from_first = HierarchyEntry.visible.
        joins(:hierarchy).
        where(taxon_concept_id: tc_id1, hierarchy: { complete: true }).
        pluck(&:hierarchy_id)
      entry = HierarchyEntry.visible.
        includes(:hierarchy).
        where(taxon_concept_id: tc_id2, hierarchy_id: from_first).
        first
      return entry && entry.hierarchy
    end
  end
end