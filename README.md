# discourse-media-wiki-import

Plugin that imports the articles from a MediaWiki export file as topics into a Discourse category.

## How To Use

- Go to your Discourse plugins page in the Admin section and click on the Media Wiki Import link in the left-hand menu.
- Upload your MediaWiki XML export file (note that it should include the MediaWiki templates for best results).
- Select the Discourse category under which you would like the MediaWiki pages to be imported as topics.
- Click the Import button to start importing the articles.
- Depending on the number of articles this might take a while to complete.
- Subsequent imports in the same category will edit any topics that match the MediaWiki topic ID, and keep any replies to the existing topic.

## How To Install
Follow the [default plugin installation guide](https://meta.discourse.org/t/install-plugins-in-discourse/19157) as provided by Discourse.

Once installed, make sure to add `XML` to the authorized staff extensions in your Discourse settings.
