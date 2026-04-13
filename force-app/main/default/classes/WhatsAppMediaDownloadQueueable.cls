public class WhatsAppMediaDownloadQueueable implements Queueable, Database.AllowsCallouts {

    private Id mediaRecordId;

    public WhatsAppMediaDownloadQueueable(Id mediaRecordId) {
        this.mediaRecordId = mediaRecordId;
    }

    public void execute(QueueableContext context) {
        try {
            WhatsAppMediaHandler.downloadAndStoreMedia(mediaRecordId);
            WhatsAppLogService.logInfo(
                'MEDIA_QUEUEABLE_COMPLETED',
                'WhatsAppMediaDownloadQueueable.execute',
                'Async media download queueable completed. jobId=' + context.getJobId() +
                ', mediaRecordId=' + mediaRecordId
            );
        } catch (Exception e) {
            WhatsAppLogService.logError(
                'MEDIA_QUEUEABLE_FAILED',
                'WhatsAppMediaDownloadQueueable.execute',
                'Async media download queueable failed: ' + e.getMessage(),
                null,
                null,
                e.getStackTraceString(),
                null
            );
            WhatsAppErrorLogger.logMediaError('Async media download failed', mediaRecordId, e);
        }
    }
}
