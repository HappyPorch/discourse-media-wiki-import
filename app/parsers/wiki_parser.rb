require 'wikicloth'

module DiscourseMediaWikiImport
  class WikiParser < WikiCloth::Parser

    @@site_domain
    @@templates

    def initialize(options={})
      @@site_domain = options[:site_domain]
      @@templates = options[:templates]
      super
    end

    template do |template|
      # check if template exists and return its content
      if @@templates.key?(template)
        @@templates[template]
      end
    end

    image_url_for do |url|
      # prefix file URLs with origin domain and redirect path
      File.join(@@site_domain, 'index.php?title=Special:Redirect/file/', url)
    end

    def link_for_resource(prefix, resource, options=[])
      prefix.downcase!

      case
        when prefix == "category"
          return ""
        when prefix == "media"
          return wiki_image(resource,options,prefix)
        when prefix == "file"
          img = wiki_image(resource,options,prefix)

          unless img.include? "width:"
            # check for any size option without width and set height instead
            options.each do |x|
              case
              when x.strip =~ /^x([0-9]+)\s*px$/
                h = $1
                css = "height=\"#{h}px\""
                img.sub! "style=\"", "#{css} style=\""
                break
              when x.strip =~ /^\'\'<a (.+)<\/a>\'\'$/
                # include link as a separate element after the image
                l = $1
                img += "<a #{l}</a>"
                break
              end
            end
          end

          return img
        else
          super
      end
    end
  end
end