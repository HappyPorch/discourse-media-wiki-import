module Jobs
    class DiscourseMediaWikiImportProcessImport < ::Jobs::Base
        def execute(args)
            begin
                Rails.logger.info('MediaWiki Import - Starting import')
        
                start = Time.now
        
                upload = Upload.get_from_url(args[:uploadedMediaWikiExportUrl])
                local_path = Discourse.store.path_for(upload)

                current_user = User.find_by(id: args[:currentUserId])
        
                processed_pages = 0
                new_pages = 0
                updated_pages = 0
                failed_pages = 0
        
                xml_doc = Nokogiri::XML(File.open(local_path))
        
                site_url = URI.parse(xml_doc.xpath('//*[local-name()="siteinfo"]').first.at('base').text)
                site_domain = "#{site_url.scheme}://#{site_url.host}/"
        
                pages = xml_doc.xpath('//*[local-name()="page"]').reverse

                wiki_page_topic_map = Hash.new
        
                # first pass: find or create topics
                pages.each do |page|
                    begin
                        # get XML element values needed for import
                        wiki_page_id = page.at('id').text
                        wiki_page_title = page.at('title').text
            
                        unless wiki_page_title.start_with?('Template:')
                            topic = find_or_create_topic(
                                wiki_page_id: wiki_page_id, 
                                category_id: args[:categoryId],
                                current_user: current_user
                            )
            
                            # store topic in the mapping for the second pass
                            wiki_page_topic_map[wiki_page_title] = topic
                        end
            
                        Rails.logger.info("MediaWiki Import - First pass completed for: #{wiki_page_title}")
                    rescue => exception
                        Rails.logger.error("MediaWiki Import - Failed to convert MediaWiki page #{wiki_page_id}: #{exception.message}\n#{exception.backtrace.join("\n")}")
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
            
                        if wiki_page_title.start_with?('Template:')
                            # ignore any template pages as they aren't content
                            processed_pages -= 1
                            next
                        end

                        Rails.logger.info("MediaWiki Import - Second pass started for: #{wiki_page_title}")
            
                        topic = wiki_page_topic_map[wiki_page_title]
            
                        is_new_topic = topic.title.blank?
            
                        wiki_page_text = convert_mediawiki_to_html(wiki_page_id: wiki_page_id, wiki_page_topic_map: wiki_page_topic_map, site_domain: site_domain)
            
                        update_topic_content(topic: topic, wiki_page_title: wiki_page_title, wiki_page_text: wiki_page_text, current_user: current_user)
            
                        # increase counter for new or updated pages
                        if is_new_topic
                            new_pages += 1
                        else
                            updated_pages += 1
                        end
            
                        Rails.logger.info("MediaWiki Import - Second pass completed for: #{wiki_page_title} (is new: #{is_new_topic}, topic ID: #{topic.id})")
                    rescue => exception
                        Rails.logger.error("MediaWiki Import - Failed to convert MediaWiki page #{wiki_page_id}: #{exception.message}\n#{exception.backtrace.join("\n")}")
                        failed_pages += 1
                    end
                end
        
                finish = Time.now
                duration = finish - start
        
                result_msg = "Successfully imported #{processed_pages} MediaWiki articles (#{new_pages} new articles, #{updated_pages} updated articles, #{failed_pages} failed articles) - #{duration.to_i} seconds"
                Rails.logger.info("MediaWiki Import - #{result_msg}")
            rescue => exception
                Rails.logger.error("MediaWiki Import - Failed to complete import: #{exception.message}\n#{exception.backtrace.join("\n")}")
            end
        end

        private

        ##
        # Finds an existing topic with the associated MediaWiki page ID, or creates a new one if it doesn't exist.
        #
        def find_or_create_topic(wiki_page_id:, category_id:, current_user:)
            topic = Topic
                        .where(id: TopicCustomField
                                    .where(
                                        name: 'wiki_page_id',
                                        value: wiki_page_id,
                                    )
                                    .select(:topic_id),
                            category_id: category_id
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
        # Converts the MediaWiki XML text to the HTML format used in Discourse.
        #
        def convert_mediawiki_to_html(wiki_page_id:, wiki_page_topic_map:, site_domain:)
            html_file = FileHelper.download(
                "#{site_domain}?curid=#{wiki_page_id}&action=render",
                max_file_size: 100000,
                tmp_file_name: "MediaWikiImport_#{wiki_page_id}",
                read_timeout: 30
            )

            return '' if html_file.nil?

            html = html_file.read
            html_file.close
            html_file.unlink

            html = convert_wiki_links(html: html, wiki_page_topic_map: wiki_page_topic_map, site_domain: site_domain)

            return html
        end

        ##
        # Converts any article links to a wiki link that will handle redirects to the corresponding Discourse topic.
        #
        def convert_wiki_links(html:, wiki_page_topic_map:, site_domain:)
            html_doc = Nokogiri::HTML::DocumentFragment.parse(html)

            # convert article links
            html_doc.css("a[href^=\"#{site_domain}index.php?title=\"]").each do |anchor|
                title = anchor['title']

                # use href value or link text when not set
                title ||= anchor['href']
                title ||= anchor.content

                # find topic URL in mapping
                topic_url = wiki_page_topic_map[title]&.url

                next if topic_url.nil?

                # fix any URLs without a topic title
                topic_url.sub! '/t//', '/t/'

                anchor['href'] = topic_url
            end

            # convert relative images
            html_doc.css('img:not([src^="http"])').each do |anchor|
                # turn relative URLs into absolute URLs
                src = anchor['src']

                anchor['src'] = "#{site_domain}#{src}"
            end

            return html_doc.to_html()
        end

        ##
        # Updates the topic's existing title and content with the new content.
        #
        def update_topic_content(topic:, wiki_page_title:, wiki_page_text:, current_user:)
            topic.update_columns(title: wiki_page_title)
                
            topic.first_post.revise(
                current_user,
                {
                    wiki: true,
                    title: wiki_page_title,
                    raw: wiki_page_text,
                    cooked: wiki_page_text
                },
                skip_jobs: true,
                skip_validations: true
            )
        end
    end
end