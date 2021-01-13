module DiscourseMediaWikiImport
  class ImportController < ApplicationController

    def import
      params.require([:uploadedMediaWikiExportUrl, :categoryId])

      upload = Upload.get_from_url(params[:uploadedMediaWikiExportUrl])
      local_path = Discourse.store.path_for(upload)

      processed_pages = 0

      mwns = "http://www.mediawiki.org/xml/export-0.10/"

      Nokogiri::XML(File.open(local_path)).xpath("//mediawiki:page", "mediawiki"=>mwns).each do |page|
        processed_pages += 1
      end

      render_json_dump("Successfully imported #{processed_pages} MediaWiki articles")
    end

  end
end