require 'wikicloth'

module DiscourseMediaWikiImport
  class ImportController < ApplicationController

    ##
    # Parses the uploaded MediaWiki export file and imports each page under the chosen Discourse cateogory.
    #
    def import
      params.require([:uploadedMediaWikiExportUrl, :categoryId])

      start = Time.now

      upload = Upload.get_from_url(params[:uploadedMediaWikiExportUrl])
      local_path = Discourse.store.path_for(upload)

      processed_pages = 0
      new_pages = 0
      updated_pages = 0
      failed_pages = 0

      mwns = 'http://www.mediawiki.org/xml/export-0.10/'

      pages = Nokogiri::XML(File.open(local_path)).xpath('//mediawiki:page', 'mediawiki'=>mwns).reverse

      wiki_page_topic_map = Hash.new

      # first pass: find or create topics
      pages.each do |page|
        begin
          # get XML element values needed for import
          wiki_page_id = page.at('id').text
          wiki_page_title = page.at('title').text

          topic = find_or_create_topic(
              wiki_page_id: wiki_page_id, 
              category_id: params[:categoryId]
            )

          # store topic in the mapping for the second pass
          wiki_page_topic_map[wiki_page_title] = topic
        rescue => exception
            Rails.logger.error("Failed to convert MediaWiki page #{wiki_page_id}: #{exception.message}\n#{exception.backtrace.join("\n")}")
            failed_pages += 1
        end
      end

      # second pass: update topic content
      pages.each do |page|
        processed_pages += 1

        begin
          # get XML element values needed for import
          wiki_page_id = page.at('id').text
          wiki_page_title = page.at('title').text
          wiki_page_text = page.at('revision').at('text').text

          topic = wiki_page_topic_map[wiki_page_title]

          is_new_topic = topic.title.blank?

          wiki_page_text = convert_mediawiki_to_markdown(wiki_page_text: wiki_page_text, wiki_page_topic_map: wiki_page_topic_map)

          update_topic_content(topic: topic, wiki_page_title: wiki_page_title, wiki_page_text: wiki_page_text)

          # increase counter for new or updated pages
          if is_new_topic
            new_pages += 1
          else
            updated_pages += 1
          end
        rescue => exception
            Rails.logger.error("Failed to convert MediaWiki page #{wiki_page_id}: #{exception.message}\n#{exception.backtrace.join("\n")}")
            failed_pages += 1
        end
      end

      finish = Time.now
      duration = finish - start

      render_json_dump("Successfully imported #{processed_pages} MediaWiki articles (#{new_pages} new articles, #{updated_pages} updated articles, #{failed_pages} failed articles) - #{duration.to_i} seconds")
    end

    private

    ##
    # Finds an existing topic with the associated MediaWiki page ID, or creates a new one if it doesn't exist.
    #
    def find_or_create_topic(wiki_page_id:, category_id:)
      topic = Topic
                .where(id: TopicCustomField
                              .where(
                                  name: 'wiki_page_id',
                                  value: wiki_page_id,
                              )
                              .select(:topic_id)
                ).first
      
      unless topic
        # topic doesn't exist yet, so create a new one
        post = PostCreator.create!(
              current_user,
              category: category_id,
              title: '',
              skip_validations: true
            )

        TopicCustomField.create!(topic_id: post.topic_id, name: 'wiki_page_id', value: wiki_page_id)

        return post.topic
      else
        # return existing topic
        return topic
      end
    end

    ##
    # Converts the MediaWiki XML text to the Markdown format used in Discourse.
    #
    def convert_mediawiki_to_markdown(wiki_page_text:, wiki_page_topic_map:)
      parser = WikiCloth::Parser.new({ :data => wiki_page_text, :noedit => true })

      html = parser.to_html()

      html = convert_wiki_links(html: html, wiki_page_topic_map: wiki_page_topic_map)

      return html
    end

    ##
    # Converts any empty article links to a wiki link that will handle redirects to the corresponding Discourse topic.
    #
    def convert_wiki_links(html:, wiki_page_topic_map:)
      html_doc = Nokogiri::HTML(html)

      html_doc.css('a:not([href^="http"])').each do |anchor|
        # skip any named anchor tags (used for article nav)
        next if anchor['name']

        # use href value or link text when not set
        title ||= anchor['href']
        title ||= anchor.content

        # find topic URL in mapping
        topic_url = wiki_page_topic_map[title]&.url

        anchor['href'] = topic_url
      end

      return html_doc.to_html()
    end

    ##
    # Updates the topic's existing title and content with the new content.
    #
    def update_topic_content(topic:, wiki_page_title:, wiki_page_text:)
      topic.update_columns(title: wiki_page_title)
        
      topic.first_post.revise(
          current_user,
          {
            wiki: true,
            title: wiki_page_title,
            raw: wiki_page_text,
          },
          skip_jobs: true,
          skip_validations: true
        )
    end

  end
end