module DiscourseMediaWikiImport
  class ImportController < ApplicationController

    def import
      params.require([:uploadedMediaWikiExportUrl, :categoryId])

      render_json_dump(params[:uploadedMediaWikiExportUrl])
    end

  end
end