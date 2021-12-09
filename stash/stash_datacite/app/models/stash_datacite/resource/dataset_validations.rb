require 'addressable'

module StashDatacite
  module Resource

    # an error with a little information about page and id in addition to message, mostly a struct
    # Some items such as name may have more than one field so IDs array, but we probably just focus on first
    class ErrorItem
      attr_accessor :message, :page, :ids
      def initialize(message:, page:, ids:)
        @message = message
        @page = page
        @ids = ids
      end

      def display_message
        url = Addressable::URI.parse(@page)
        url.query_values = (url.query_values || {}).merge({display_validation: true})
        url_str = "#{url}##{@ids&.first}"
        @message.gsub('{', "<a href=\"#{url_str}\">").gsub('}', '</a>')
      end
    end

    class DatasetValidations
      # this page displays specific validation information
      # contains a message for each, a link for the page to look at and an id for the field with a problem when possible
      def initialize(resource: resource)
        @resource = resource
      end

      def url_help
        StashEngine::Engine.routes.url_helpers
      end

      def metadata_page(resource)
        url_help.metadata_entry_pages_find_or_create_path(resource_id: resource.id)
      end

      def files_page(resource)
        url_help.upload_resource_path(id: resource.id)
      end

      # the items being validated currently on the metadata page are:
      # title, abstract, article_id/doi for journal article, full_author name, author affiliation for all,
      # author email for the first author
      #
      # for the files page:
      # files that haven't validated, errors uploading, too many files, too big of size


      def errors
        err = []
        err << title

        err.flatten
      end

      def title
        if @resource.title.blank?
          return ErrorItem.new(message: 'Fill in a {dataset title}',
                    page: metadata_page(@resource),
                    ids: [ "title__#{@resource.id}"])
        end
        []
      end
    end
  end
end
