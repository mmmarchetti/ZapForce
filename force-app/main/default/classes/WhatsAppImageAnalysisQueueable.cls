/**
 * @description Queueable for analyzing WhatsApp images via Flow-based configuration.
 *              Invokes the configured autolaunched Flow (specified in Image_Analysis_Flow_API_Name__c)
 *              to process the image. The Flow receives a contentDocumentId and returns analysis text.
 *              Creates an inbound message with the analysis result and routes it to Agentforce.
 */
public class WhatsAppImageAnalysisQueueable implements Queueable, Database.AllowsCallouts {
    private List<Id> mediaRecordIds;

    public WhatsAppImageAnalysisQueueable(List<Id> mediaRecordIds) {
        this.mediaRecordIds = mediaRecordIds;
    }

    public void execute(QueueableContext context) {
        List<WhatsApp_Media__c> mediaRecords = [
            SELECT
                Id,
                ContentVersion_ID__c,
                Media_Type__c,
                Media_ID__c,
                Message__c,
                Message__r.Conversation__c,
                Message__r.Conversation__r.Customer_Phone__c,
                Message__r.Sender_Phone__c,
                Message__r.Recipient_Phone__c
            FROM WhatsApp_Media__c
            WHERE Id IN :mediaRecordIds AND ContentVersion_ID__c != NULL AND Media_Type__c = 'Image'
        ];

        if (mediaRecords.isEmpty()) {
            return;
        }

        // Collect ContentVersion IDs to get ContentDocumentIds
        Set<Id> cvIds = new Set<Id>();
        for (WhatsApp_Media__c media : mediaRecords) {
            cvIds.add(media.ContentVersion_ID__c);
        }

        Map<Id, ContentVersion> cvMap = new Map<Id, ContentVersion>(
            [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE Id IN :cvIds
            ]
        );

        for (WhatsApp_Media__c media : mediaRecords) {
            ContentVersion cv = cvMap.get(media.ContentVersion_ID__c);
            if (cv == null || cv.ContentDocumentId == null) {
                continue;
            }

            String customerPhone = media.Message__r.Conversation__r.Customer_Phone__c;
            String conversationId = media.Message__r.Conversation__c;

            try {
                // Invoke Flow-based image analysis
                String analysisResult = WhatsAppImageAnalysisFlowService.analyzeImage(cv.ContentDocumentId);

                if (String.isBlank(analysisResult)) {
                    WhatsAppLogService.logError(
                        'IMAGE_ANALYSIS_EMPTY',
                        'WhatsAppImageAnalysisQueueable.execute',
                        'Analysis flow returned empty text. mediaRecordId=' + media.Id,
                        null,
                        null,
                        null,
                        null
                    );
                    return;
                }

                // Create inbound message with analysis result (similar to audio transcription)
                WhatsApp_Message__c analysisMessage = WhatsAppMessageService.createInboundTranscriptionMessage(
                    conversationId,
                    media.Message__r.Sender_Phone__c,
                    media.Message__r.Recipient_Phone__c,
                    analysisResult,
                    media.Media_ID__c
                );

                // Update conversation
                WhatsAppConversationService.updateConversationOnMessage(conversationId, true);

                // Route to Agentforce for processing
                if (!Test.isRunningTest()) {
                    String jobId = System.enqueueJob(
                        new WhatsAppAgentforceQueueable(conversationId, analysisMessage.Id)
                    );
                    WhatsAppLogService.logInfo(
                        'IMAGE_ANALYSIS_ROUTED_TO_AGENTFORCE',
                        'WhatsAppImageAnalysisQueueable.execute',
                        'Analysis message created and routed. analysisMessageId=' +
                            analysisMessage.Id +
                            ', queueableJobId=' +
                            jobId
                    );
                }
            } catch (Exception e) {
                System.debug('IMAGE_ANALYSIS_QUEUEABLE_EXCEPTION: ' + e.getMessage());
                WhatsAppLogService.logError(
                    'IMAGE_ANALYSIS_QUEUEABLE_FAILED',
                    'WhatsAppImageAnalysisQueueable.execute',
                    'Image analysis failed: ' + e.getMessage(),
                    null,
                    null,
                    e.getStackTraceString(),
                    null
                );
            }
        }
    }
}
