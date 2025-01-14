require_dependency 'stash_engine/application_controller'

module StashEngine
  class GmailAuthController < ApplicationController
    before_action :require_superuser

    include SharedSecurityController

    def index
      params.permit(:format)

      respond_to do |format|
        format.html
      end
    end
  end
end
