# discourse-media-wiki-import

Plugin that imports the articles from a MediaWiki export file as topics into a Discourse category.

## How To Use

1. Go to your Discourse plugins page in the Admin section and click on the Media Wiki Import link in the left-hand menu.
2. Upload your MediaWiki XML export file (note that it should include the MediaWiki templates for best results).
3. Select the Discourse category under which you would like the MediaWiki pages to be imported as topics.
4. Click the Import button to start importing the articles.
5. Depending on the number of articles this might take a while to complete.
6. Subsequent imports in the same category will edit any topics that match the MediaWiki topic ID, and keep any replies to the existing topic.

## How To Install
1. Add the following to your `containers\app.yml` file to ensure that the right dependencies are installed for the plugin:
   ```
   hooks:
     before_code:
       - exec:
           cmd:
             - apt-get update
             - apt-get install -y libldap2-dev libidn11-dev
   ```
2. Follow the [default plugin installation guide](https://meta.discourse.org/t/install-plugins-in-discourse/19157) as provided by Discourse.
3. Once installed, make sure to add `XML` to the authorized staff extensions in your Discourse settings.
