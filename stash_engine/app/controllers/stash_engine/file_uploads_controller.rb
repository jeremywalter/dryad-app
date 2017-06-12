require_dependency 'stash_engine/application_controller'
require 'fileutils'

module StashEngine
  class FileUploadsController < ApplicationController
    before_action :require_login
    before_action :set_file_info, only: %i[destroy remove restore destroy_error destroy_manifest]
    # TODO: check that the following before action really should be ignored on these
    before_action :require_file_owner, except: %i[create destroy remove restore revert validate_urls destroy_error remove_unuploaded index]
    before_action :set_create_prerequisites, only: [:create]

    # show the list of files for resource
    def index
      respond_to do |format|
        format.js do
          @resource = Resource.find(params[:resource_id])
        end
      end
    end

    # this is a newly uploaded file and we're deleting it, for files
    # def destroy
    #  respond_to do |format|
    #    format.js do
    #      fn = @file.upload_file_name
    #      @resource = @file.resource
    #      temp_file_path = @file.temp_file_path
    #      if temp_file_path.present?
    #        File.delete(@file.temp_file_path)
    #      end
    #      @file_id = @file.id
    #      @file.destroy
    #      @extra_files = FileUpload.where(resource_id: @resource.id, upload_file_name: fn)
    #      # files that had a file overriding them, put the original copied file back
    #      @extra_files.each do |my_f|
    #        my_f.update_attribute(:file_state, 'deleted') if my_f.file_state == 'copied'
    #      end
    #      end
    # end
    # end

    # this is a validated manifest URI that doesn't pass validation and we're deleting it from the DB
    def destroy_error
      respond_to do |format|
        format.js do
          @url = @file.url
          @resource = @file.resource
          @file.destroy
        end
      end
    end

    # destroy a file from the manifest table deletion action
    def destroy_manifest
      respond_to do |format|
        format.js do
          @resource = @file.resource
          @file_id = @file.id
          if @file.file_state == 'copied'
            @file.file_state = 'deleted'
            @file.save!
          elsif @file.file_state == 'created'
            @file.destroy
          end
        end
      end
    end

    # this is a file from a previous version and we're marking it for deletion
    # def remove
    #  respond_to do |format|
    #    format.js do
    #      @file.update_attribute(:file_state, 'deleted')
    #      @file.reload
    #    end
    #  end
    # end

    # This is a file that hasn't been uploaded, but we might need to restore a previous version that was in the db.
    # note this is taking a resource_id instead of a file_id since there isn't one yet.
    # def remove_unuploaded
    #  respond_to do |format|
    #    format.js do
    #      @resource = Resource.find(params[:id])
    #      @fn = params[:filename]
    #      @row_id = params[:row_id]
    #      @dup_files = @resource.file_uploads.where(upload_file_name: @fn)
    #    end
    #  end
    # end

    # this is a file from a previous version marked as deleted and we're unmarking it for deletion
    # def restore
    #  respond_to do |format|
    #    format.js do
    #      @file.update_attribute(:file_state, 'copied')
    #      @file.reload
    #    end
    #  end
    # end

    # a file being uploaded (chunk by chunk)
    def create
      respond_to do |format|
        format.js do
          add_to_file(@accum_file, @file_upload) # this accumulates bytes into file for chunked uploads

          if File.size(@accum_file) < params[:hidden_bytes].to_i
            # do not render changes to page until full file uploads and is saved into db
            head :ok, content_type: 'application/javascript'
            return
          end

          @resource = Resource.find(params[:resource_id])

          unique_fn = make_unique(@file_upload.original_filename)

          new_path_and_fn = File.join(@upload_dir, unique_fn)
          # correct_existing_for_overwrite(params[:resource_id], @file_upload)

          FileUtils.mv(@accum_file, new_path_and_fn) # moves the file from the original unique_id fn to the final one
          create_db_file(path: new_path_and_fn, filename: unique_fn) # no files exist for this so new "created" file and sets some variables like @my_file

        end
      end
    end

    # def revert
    #   respond_to do |format|
    #     format.js do
    #       # in here we need to remove the files from filesystem and database except the 'copied' state files
    #       @resource = Resource.where(id: params[:resource_id])
    #       raise ActionController::RoutingError, 'Not Found' if @resource.empty? ||
    #                                                            @resource.first.user_id != session[:user_id]
    #       @resource = @resource.first
    #       @resource.file_uploads.each do |fu|
    #         if fu.file_state == 'created'
    #           File.delete(fu.temp_file_path) if File.exist?(fu.temp_file_path)
    #           fu.destroy
    #         else
    #           fu.update_attribute(:file_state, 'copied')
    #         end
    #       end
    #       @uploads = @resource.latest_file_states
    #     end
    #   end
    # end

    # #manifest workflow
    def validate_urls
      respond_to do |format|
        @resource = Resource.where(id: params[:resource_id]).first
        return if params[:url].strip.blank?
        urls_array = params[:url].split(/[\r\n]+/).map(&:strip).delete_if(&:blank?)
        urls_array.each do |url|
          validator =  StashEngine::UrlValidator.new(url: url)
          val_result = validator.validate

          @file = if val_result == true && validator.status_code == 200
                    if @resource.url_in_version?(validator.url)
                      # don't allow duplicate URLs that have already been put into this version this time
                      FileUpload.create(resource_id: @resource.id,
                                        url: validator.url,
                                        status_code: 498,
                                        file_state: 'created')
                    else
                      FileUpload.create(resource_id: @resource.id,
                                        url: validator.url,
                                        status_code: validator.status_code,
                                        upload_file_name: make_unique(validator.filename),
                                        upload_content_type: validator.mime_type,
                                        upload_file_size: validator.size,
                                        file_state: 'created')
                            end
                  else
                    FileUpload.create(resource_id: @resource.id,
                                      url: validator.url,
                                      status_code: validator.status_code,
                                      file_state: 'created')
                  end
        end
        format.js
      end
    end

    private

    def require_file_owner
      return if current_user.id == @file.resource.user_id
      redirect_to tenants_path && return
    end

    def set_create_prerequisites
      unless params[:resource_id] && params[:temp_id] && params[:upload]
        raise ActionController::RoutingError.new('Not Found'), 'Not Found'
      end
      @upload_dir = StashEngine::Resource.upload_dir_for(params[:resource_id])
      FileUtils.mkdir_p @upload_dir unless File.exist?(@upload_dir)
      @temp_id = params[:temp_id]
      @accum_file = File.join(@upload_dir, @temp_id)
      @file_upload = params[:upload][:upload]
    end

    def set_file_info
      @file = FileUpload.find(params[:id])
    end

    # write a chunk to the file.
    def add_to_file(fn, fileupload)
      File.open(fn, 'ab') { |f| f.write(fileupload.read) }
    end

    # for standard uploads, create standard file in DB before moving on to chunks.
    def create_db_file(path:, filename:)
      @my_file = FileUpload.new(
        upload_file_name: filename,
        temp_file_path: path,
        upload_content_type: @file_upload.content_type,
        upload_file_size: File.size(path),
        resource_id: params[:resource_id],
        upload_updated_at: Time.new.utc,
        file_state: 'created'
      )
      @my_file.save
    end

    def correct_existing_for_overwrite(resource_id, file_upload)
      existing_files = FileUpload
        .where(resource_id: resource_id)
        .where(upload_file_name: file_upload.original_filename)

      existing_files.each do |old_f|
        if old_f.file_state == 'created' || old_f.file_state.blank?
          # delete this old file before overwriting with this one, there can be only one current with same name
          File.delete(old_f.temp_file_path) if File.exist?(old_f.temp_file_path)
          old_f.destroy
        elsif old_f.file_state == 'deleted'
          # set back to 'copied' since this is really just a new version of this old file with same name
          old_f.update_attribute(:file_state, 'copied')
        end
      end
    end

    def make_unique(fn)
      dups = @resource.file_uploads.present_files.where(upload_file_name: fn)
      return fn unless dups.count > 0
      ext = File.extname(fn)
      core_name = File.basename(fn, ext)
      counter = 2
      while @resource.file_uploads.present_files.where(upload_file_name: "#{core_name}-#{counter}#{ext}").count > 0
        counter += 1
      end
      "#{core_name}-#{counter}#{ext}"
    end
  end
end
