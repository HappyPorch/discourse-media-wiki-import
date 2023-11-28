# name: discourse-media-wiki-import
# about: Plugin that imports the articles from a MediaWiki export file as topics into a Discourse category. 
# version: 0.4.4
# authors: HappyPorch
# url: https://github.com/HappyPorch/discourse-media-wiki-import/

register_asset 'stylesheets/media-wiki-import.scss'

after_initialize do
  module ::DiscourseMediaWikiImport
    class Engine < ::Rails::Engine
      isolate_namespace DiscourseMediaWikiImport
    end
  end

  require File.expand_path('app/controllers/discourse-media-wiki-import/import_controller', __dir__)

  DiscourseMediaWikiImport::Engine.routes.draw do
    post 'import' => 'import#import'
    get 'import-running' => 'import#import_running'
  end

  add_admin_route 'media_wiki_import.title', 'media-wiki-import'

  Discourse::Application.routes.append do
    mount ::DiscourseMediaWikiImport::Engine, at: '/media-wiki-import'
    get '/admin/plugins/media-wiki-import' => 'admin/plugins#index', constraints: AdminConstraint.new
  end

  load File.expand_path('../app/jobs/process_import.rb', __FILE__)
end