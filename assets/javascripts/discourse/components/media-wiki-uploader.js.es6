import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import UppyUpload from "discourse/lib/uppy/uppy-upload";

export default Component.extend(UppyUpload, {
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