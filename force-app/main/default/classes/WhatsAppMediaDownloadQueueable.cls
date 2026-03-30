public class WhatsAppMediaDownloadQueueable implements Queueable, Database.AllowsCallouts {

    private Id mediaRecordId;

    public WhatsAppMediaDownloadQueueable(Id mediaRecordId) {
        this.mediaRecordId = mediaRecordId;
    }

    public void execute(QueueableContext context) {
        try {
            WhatsAppMediaHandler.downloadAndStoreMedia(mediaRecordId);
        } catch (Exception e) {
            WhatsAppErrorLogger.logMediaError('Async media download failed', mediaRecordId, e);
        }
    }
}
