namespace :taxon_concepts do
  desc 'generate json'
  task :generate_json => :environment do
    puts "Started (#{Time.now})\n"
    # Cache the ranks so we're not constantly looking them up:
    ranks = []
    TranslatedRank.select("rank_id, label").
      where(language_id: Language.english.id).
      each { |rank| ranks[rank.rank_id] = rank.label}
    languages = []
    TranslatedLanguage.where(language_id: Language.english.id).each do |lang|
      iso = Language.find(lang.original_language_id).iso_639_1
      languages[lang.original_language_id] = iso.blank? ? 'UNKNOWN': iso  
    end
    File.open("public/taxon_concepts.json", "wb") do |file|
      # Headers:
      file.write("[")
      index = 0
      batch_size = 1000
      # A little weird, but faster to go through the preferred entry rather than
      # calculate it...
      batch = []
      TaxonConceptPreferredEntry.with_taxon_and_entry.
        includes(published_hierarchy_entry: [:name, :rank, :flattened_ancestors],
          published_taxon_concept: { preferred_names: [:name],
            preferred_common_names: [:name],
            published_hierarchy_entries: { hierarchy: [:resource] } }).
        find_each(batch_size: batch_size) do |tcpe|
        index += 1
        if index % batch_size == 0
          puts "  #{index}..."
          file.write(batch.join("\n"))
          batch = []
        end
        data = {}
        data[:taxon_concept_id] = tcpe.taxon_concept_id
        data[:rank] = ranks[tcpe.published_hierarchy_entry.rank_id]
        data[:ancestor_taxon_concepts_ids] = HierarchyEntry.select(:taxon_concept_id).
          where(['id IN (?)',
            tcpe.published_hierarchy_entry.flattened_ancestors.map(&:ancestor_id)]).
          map(&:taxon_concept_id)
          
        data[:preferred_scientific_names] =
          tcpe.published_taxon_concept.preferred_names.map { |pn| pn.name.try(:string) }.
          compact.sort.uniq
        data[:preferred_common_names] =
          tcpe.published_taxon_concept.preferred_common_names.
          map { |pn| { name: pn.name.try(:string) || '[MISSING]',
            language: languages[pn.language_id]} }
        data[:outlinks] = []
        tcpe.published_taxon_concept.published_hierarchy_entries.each do |entry|
          data[:outlinks] << {
            hierarchy_entry_id: entry.id,
            resource_id: entry.try(:hierarchy).try(:resource).try(:id),
            resource: entry.try(:hierarchy).try(:label),
            identifier: entry.identifier
          }
        end
        batch << data.to_json
      end
      if !batch.blank?
        file.write(batch.join("\n"))
      end
      file.write("]\n")
      print "\n Done \n"
    end
  end
end