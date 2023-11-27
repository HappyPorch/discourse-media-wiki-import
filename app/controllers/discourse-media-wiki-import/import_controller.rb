module DiscourseMediaWikiImport
  class ImportController < ApplicationController

    ##
    # Parses the uploaded MediaWiki export file and imports each page under the chosen Discourse cateogory.
    #
    def import
      params.require([:uploadedMediaWikiExportUrl, :categoryId])

      Rails.logger.info('MediaWiki Import - Scheduling import')

      Jobs.enqueue(
        :discourse_media_wiki_import_process_import,
        uploadedMediaWikiExportUrl: params[:uploadedMediaWikiExportUrl],
        categoryId: params[:categoryId],
        currentUserId: current_user.id
      )

      render_json_dump("Scheduled job for import. Import duration depends on the amount of wiki entries that will be imported.")
    end

    ##
    # Checks if import job is already running or scheduled to run.
    #
    def import_running
      is_import_running = false

      Sidekiq::Workers.new.each do |_process_id, _thread_id, work|
        if work['payload']['class'] == Jobs::DiscourseMediaWikiImportProcessImport.to_s
          is_import_running = true
        end
      end

      unless is_import_running
        Sidekiq::Queue.new('default').each do |job|
          if job.klass == Jobs::DiscourseMediaWikiImportProcessImport.to_s
            is_import_running = true
          end
        end
      end

      render_json_dump(is_import_running)
    end

  end
end