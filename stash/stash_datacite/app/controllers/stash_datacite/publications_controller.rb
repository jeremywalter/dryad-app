require_dependency 'stash_datacite/application_controller'
require 'httparty'
require 'stash/import/crossref'
require 'stash/import/dryad_manuscript'
require 'stash/link_out/pubmed_sequence_service'
require 'stash/link_out/pubmed_service'
require 'cgi'

# rubocop:disable Metrics/ClassLength
module StashDatacite
  class PublicationsController < ApplicationController
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    def update
      @se_id = StashEngine::Identifier.find(params[:internal_datum][:identifier_id])
      save_form_to_internal_data
      respond_to do |format|
        format.js do
          if params[:internal_datum][:do_import] == 'true'
            @error = 'Please fill in the form completely' if params[:internal_datum][:msid].blank? && params[:internal_datum][:doi].blank?
            @resource = @se_id.latest_resource
            update_manuscript_metadata if params[:import_type] == 'manuscript'
            update_doi_metadata if params[:internal_datum][:doi].present? && params[:import_type] == 'published'
            manage_pubmed_datum(identifier: @se_id, doi: @doi.related_identifier) if !@doi&.related_identifier.blank? &&
              params[:import_type] == 'published'
            params[:import_type] == 'published'
          else
            render template: 'stash_datacite/shared/update.js.erb'
          end
        end
      end
    end

    # GET /publications/autocomplete?term={query_term}
    def autocomplete
      partial_term = params['term']
      if partial_term.blank?
        render json: nil
      else
        # clean the partial_term of unwanted characters so it doesn't cause errors
        partial_term.gsub!(%r{[\/\-\\\(\)~!@%&"\[\]\^\:]}, ' ')

        matches = StashEngine::Journal.where('title like ?', "%#{partial_term}%").limit(40)

        render json: bubble_up_exact_matches(result_list: matches, term: partial_term)
      end
    end

    # GET /publications/issn/{id}
    def issn
      target_issn = params['id']
      return if target_issn.blank?
      return unless target_issn =~ /\d+-\w+/
      match = StashEngine::Journal.where(issn: target_issn).first
      render json: match
    end

    def save_form_to_internal_data
      @pub_issn = manage_internal_datum(identifier: @se_id, data_type: 'publicationISSN', value: params[:internal_datum][:publication_issn])
      @pub_name = manage_internal_datum(identifier: @se_id, data_type: 'publicationName', value: params[:internal_datum][:publication_name])
      parsed_msid = parse_msid(issn: params[:internal_datum][:publication_issn], msid: params[:internal_datum][:msid])
      @msid = manage_internal_datum(identifier: @se_id, data_type: 'manuscriptNumber', value: parsed_msid)
    end

    # parse out the "relevant" part of the manuscript ID, ignoring the parts that the journal changes for different versions of the same item
    def parse_msid(issn:, msid:)
      logger.debug("Parsing msid #{msid} for journal #{issn}")
      regex = @se_id.journal&.manuscript_number_regex
      return msid if regex.blank?
      logger.debug("- found regex /#{regex}/")
      return msid if msid.match(regex).blank?
      logger.debug("- after regex applied: #{msid.match(regex)[1]}")
      result = msid.match(regex)[1]
      if result.present?
        result
      else
        msid
      end
    end

    def update_manuscript_metadata
      if !params[:internal_datum][:publication].blank? && params[:internal_datum][:publication_issn].blank?
        @error = 'Please select your journal from the autocomplete drop-down list'
        return
      end
      return if params[:internal_datum][:publication].blank? # keeps the default fill-in message
      return if @pub_issn&.value.blank?
      return if @msid&.value.blank?
      my_url = "#{APP_CONFIG.old_dryad_url}/api/v1/organizations/#{CGI.escape(@pub_issn&.value)}/manuscripts/#{CGI.escape(@msid&.value)}"
      response = HTTParty.get(my_url,
                              query: { access_token: APP_CONFIG.old_dryad_access_token },
                              headers: { 'Content-Type' => 'application/json' })
      if response.code > 299
        @error = 'We could not find metadata to import for this manuscript. Please enter your metadata below.'
        return
      end
      dryad_import = Stash::Import::DryadManuscript.new(resource: @resource, httparty_response: response)
      dryad_import.populate
    rescue HTTParty::Error, SocketError => ex
      logger.error("Dryad manuscript API returned a HTTParty/Socket error for ISSN: #{@pub_issn.value}, MSID: #{@msid.value}\r\n #{ex}")
      @error = 'We could not find metadata to import for this manuscript. Please enter your metadata below.'
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

    def update_doi_metadata
      unless params[:internal_datum][:doi].present?
        @error = 'Please enter a DOI to import metadata'
        return
      end
      cr = Stash::Import::Crossref.query_by_doi(resource: @resource, doi: params[:internal_datum][:doi])
      unless cr.present?
        @error = "We couldn't obtain information from CrossRef about this DOI: #{params[:internal_datum][:doi]}"
        return
      end
      @resource = cr.populate_resource!
    rescue Serrano::NotFound, Serrano::BadGateway, Serrano::Error, Serrano::GatewayTimeout, Serrano::InternalServerError, Serrano::ServiceUnavailable
      @error = "We couldn't retrieve information from CrossRef about this DOI"
    end

    def manage_internal_datum(identifier:, data_type:, value:)
      datum = StashEngine::InternalDatum.where(stash_identifier: identifier, data_type: data_type).first
      if datum.present?
        datum.destroy unless value.present?
        datum.update(value: value) if value.present?
      elsif value.present?
        datum = StashEngine::InternalDatum.create(stash_identifier: identifier, data_type: data_type, value: value)
      end
      datum
    end

    def manage_pubmed_datum(identifier:, doi:)
      pubmed_service = LinkOut::PubmedService.new
      pmid = pubmed_service.lookup_pubmed_id(doi)
      return unless pmid.present?

      internal_datum = StashEngine::InternalDatum.find_or_initialize_by(identifier_id: identifier.id, data_type: 'pubmedID')
      internal_datum.value = pmid.to_s
      return unless internal_datum.value_changed?

      internal_datum.save
      manage_genbank_datum(identifier: identifier, pmid: pmid)
    end

    def manage_genbank_datum(identifier:, pmid:)
      pubmed_sequence_service = LinkOut::PubmedSequenceService.new
      sequences = pubmed_sequence_service.lookup_genbank_sequences(pmid)
      return unless sequences.any?

      sequences.each do |k, v|
        external_ref = StashEngine::ExternalReference.find_or_initialize_by(identifier_id: identifier.id, source: k)
        external_ref.value = v.to_s
        next unless external_ref.value_changed?

        external_ref.save
      end
    end

    def get_related_identifier(identifier:, related_identifier_type:, relation_type:)
      return nil unless identifier.present?
      @resource = StashEngine::Identifier.find(identifier.is_a?(String) ? identifier : identifier.id).latest_resource
      return nil unless @resource.present? && related_identifier_type.present? && relation_type.present?
      StashDatacite::RelatedIdentifier.where(resource_id: @resource.id, relation_type: relation_type,
                                             related_identifier_type: related_identifier_type).first
    end

    private

    # Re-order a journal list to prioritize exact matches at the beginning of the string, then
    # exact matches within the string, otherwise leaving the order unchanged
    def bubble_up_exact_matches(result_list:, term:)
      exact_match = []
      matches_at_beginning = []
      matches_within = []
      other_items = []
      match_term = term.downcase
      result_list.each do |result_item|
        name = result_item['title'].downcase
        if name == match_term
          exact_match << result_item
        elsif name.start_with?(match_term)
          matches_at_beginning << result_item
        elsif name.include?(match_term)
          matches_within << result_item
        else
          other_items << result_item
        end
      end
      exact_match + matches_at_beginning + matches_within + other_items
    end

  end
end
# rubocop:enable Metrics/ClassLength
