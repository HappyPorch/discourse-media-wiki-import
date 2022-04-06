import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import UppyUploadMixin from "discourse/mixins/uppy-upload";

export default Component.extend(UppyUploadMixin, {
  type: "mediawiki-export",
  tagName: "span",

  validateUploadedFilesOptions() {
    return { skipValidation: true };
  },

  uploadDone(upload) {
    this.setProperties({
      uploadedMediaWikiExportUrl: upload.url,
      uploadedMediaWikiExportId: upload.id,
      uploadedMediaWikiExportDisplayName: `${upload.original_filename} (${upload.human_filesize})`
    });

    this.done();
  },

  @discourseComputed("user_id")
  data(user_id) {
    return { user_id };
  }
});