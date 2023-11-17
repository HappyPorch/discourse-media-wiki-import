# name: discourse-media-wiki-import
# about: Plugin that imports the articles from a MediaWiki export file as topics into a Discourse category. 
# version: 0.3.0
# authors: HappyPorch
# url: https://github.com/HappyPorch/discourse-media-wiki-import/

gem 'expression_parser', '0.9.0', {require: false}
gem 'idn-ruby', '0.1.0', {require: false}
gem 'twitter-text', '3.1.0', {require: false}

# install custom wikicloth gem from the plugin directory, as the latest working version is not on Rubygems
command = "gem install #{File.expand_path('gem-packages/wikicloth-0.8.4.gem', __dir__)} -v 0.8.4 -i #{File.expand_path("gems/#{RUBY_VERSION}", __dir__)} --no-document --ignore-dependencies --no-user-install"
puts `#{command}`

gem 'wikicloth', '0.8.4', {require: false}

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
  end

  add_admin_route 'media_wiki_import.title', 'media-wiki-import'

  Discourse::Application.routes.append do
    mount ::DiscourseMediaWikiImport::Engine, at: '/media-wiki-import'
    get '/admin/plugins/media-wiki-import' => 'admin/plugins#index', constraints: AdminConstraint.new
  end
end