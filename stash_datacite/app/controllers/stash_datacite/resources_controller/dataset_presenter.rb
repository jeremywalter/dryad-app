# Why do things this way?
# http://vrybas.github.io/blog/2014/08/15/a-way-to-organize-poros-in-rails/
# http://www.jetthoughts.com/blog/tech/2014/08/14/cleaning-up-your-rails-views-with-view-objects.html
module StashDatacite
  class ResourcesController
    class DatasetPresenter
      attr_reader :resource

      delegate :updated_at, :user_id, to: :resource

      def initialize(resource)
        @resource = resource
        @completions = Resource::Completions.new(@resource)
      end

      def title
        return '[No title supplied]' if @resource.title.blank?
        @resource.title
      end

      def status
        @resource.current_state
      end

      # according to https://dash.ucop.edu/xtf/search?smode=metadataBasicsPage
      # required fields are Title, Institution, Data type, Data Author(s), Abstract
      def required_filled
        @completions.required_completed
      end

      def required_total
        @completions.required_total
      end

      # according to https://dash.ucop.edu/xtf/search?smode=metadataBasicsPage
      # optional fields are Date, Keywords, Methods, Citations
      def optional_filled
        @completions.optional_completed
      end

      def optional_total
        @completions.optional_total
      end

      def file_count
        @resource.current_file_uploads.count
      end

      def external_identifier
        id = @resource.identifier
        if id.blank?
          'bad_identifier'
        else
          "#{id.try(:identifier_type).try(:downcase)}:#{id.try(:identifier)}"
        end
      end

      def embargo_status
        return 'private' if @resource.embargoed?
        return 'published' if @resource.submitted?
        resource.current_state
      end

      def publication_date
        return @resource.publication_date if @resource.submitted?
        Time.new(1970)
      end

      def edited_by_id
        return @resource.user_id if @resource.current_editor_id.nil?
        @resource.current_editor_id
      end

      def edited_by_name
        users = StashEngine::User.where(id: edited_by_id)
        return '' if users.length < 1 || (users.first.first_name.blank? && users.first.last_name.blank?)
        "#{users.first.first_name} #{users.first.last_name}"
      end

      def created_at
        @resource.identifier.try(:created_at) || @resource.created_at
      end
    end
  end
end
