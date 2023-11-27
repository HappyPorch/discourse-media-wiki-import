import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Controller.extend({
  importing: false,

  init() {
    this._super(...arguments);

    this.importRunning();
  },

  importRunning(isImporting) {
    ajax("/media-wiki-import/import-running", {
      type: "GET"
    })
      .then((result) => {
        this.set("importing", result);

        if (result) {
          // check again in 10 seconds
          setTimeout(() => this.importRunning(), 10000)
        }
        else if (isImporting) {
          // import completed
          this.set("successMessage", "Import finished");
        }

        isImporting = result;
      })
      .catch(popupAjaxError);
  },

  actions: {
    uploadComplete() {
    },

    import() {
      this.setProperties({
        errorMessageExportFile: null,
        errorMessageCategory: null,
        successMessage: null
      });

      if (!this.uploadedMediaWikiExportUrl) {
        this.setProperties({
          errorMessageExportFile: I18n.t("media_wiki_import.import.error_missing_export_file")
        });

        return;
      }

      if (!this.categoryId) {
        this.setProperties({
          errorMessageCategory: I18n.t("media_wiki_import.import.error_missing_category")
        });

        return;
      }

      this.set("importing", true);

      ajax("/media-wiki-import/import", {
        type: "POST",
        data: {
          uploadedMediaWikiExportUrl: this.uploadedMediaWikiExportUrl,
          categoryId: this.categoryId
        }
      })
        .then((result) => {
          this.setProperties({ 
            successMessage: result,
          });

          // check if import is still running
          setTimeout(() => this.importRunning(), 5000)
        })
        .catch(popupAjaxError);
    }
  }
});