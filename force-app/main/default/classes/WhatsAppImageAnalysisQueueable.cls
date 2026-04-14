/**
 * @description Queueable for analyzing WhatsApp images via a loopback callout.
 *              ConnectApi.EinsteinLLM requires a licensed user context — it fails
 *              under the Automated Process user. This queueable calls the
 *              WhatsAppImageAnalysisEndpoint REST API using a JWT token from the
 *              Connected App, which runs the ConnectApi call as the Run-As user.
 *              After analysis, chains WhatsAppSendMessageQueueable to deliver the result.
 */
public class WhatsAppImageAnalysisQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> mediaRecordIds;

    public WhatsAppImageAnalysisQueueable(List<Id> mediaRecordIds) {
        this.mediaRecordIds = mediaRecordIds;
    }

    public void execute(QueueableContext context) {
        List<WhatsApp_Media__c> mediaRecords = [
            SELECT Id, ContentVersion_ID__c, Media_Type__c,
                   Message__c, Message__r.Conversation__c,
                   Message__r.Conversation__r.Customer_Phone__c
            FROM WhatsApp_Media__c
            WHERE Id IN :mediaRecordIds
              AND ContentVersion_ID__c != null
              AND Media_Type__c = 'Image'
        ];

        if (mediaRecords.isEmpty()) {
            return;
        }

        // Collect ContentVersion IDs to get ContentDocumentIds
        Set<Id> cvIds = new Set<Id>();
        for (WhatsApp_Media__c media : mediaRecords) {
            cvIds.add(media.ContentVersion_ID__c);
        }

        Map<Id, ContentVersion> cvMap = new Map<Id, ContentVersion>([
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :cvIds
        ]);

        // Get auth token once for all images
        String token = WhatsAppAuthService.getAgentforceAccessToken();
        String orgDomain = URL.getOrgDomainUrl().toExternalForm();

        for (WhatsApp_Media__c media : mediaRecords) {
            ContentVersion cv = cvMap.get(media.ContentVersion_ID__c);
            if (cv == null || cv.ContentDocumentId == null) {
                continue;
            }

            String customerPhone = media.Message__r.Conversation__r.Customer_Phone__c;
            String conversationId = media.Message__r.Conversation__c;

            try {
                // Loopback callout to REST endpoint (runs as Connected App Run-As user)
                String analysisResult = callImageAnalysisEndpoint(
                    orgDomain, token, cv.ContentDocumentId
                );

                String messageText;
                Boolean analysisSucceeded = String.isNotBlank(analysisResult) &&
                                            !analysisResult.startsWith('Error: ');
                if (analysisSucceeded) {
                    messageText = analysisResult;
                } else {
                    messageText = 'Desculpe, não consegui analisar a imagem neste momento. ' +
                                  'Por favor, tente enviar novamente.';
                }

                // Use System.debug between callouts to avoid DML-before-callout
                System.debug('IMAGE_ANALYSIS_RESULT: success=' + analysisSucceeded +
                             ', mediaRecordId=' + media.Id);

                // Send the result directly to WhatsApp (HTTP callout — no DML before this)
                String waMessageId = WhatsAppAPIService.sendTextMessage(customerPhone, messageText);

                // All callouts done — safe to do DML now
                if (analysisSucceeded) {
                    WhatsAppLogService.logInfo(
                        'IMAGE_ANALYSIS_COMPLETED',
                        'WhatsAppImageAnalysisQueueable.execute',
                        'Image analysis succeeded and sent. mediaRecordId=' + media.Id +
                        ', conversationId=' + conversationId +
                        ', resultLength=' + analysisResult.length()
                    );
                } else {
                    WhatsAppLogService.logError(
                        'IMAGE_ANALYSIS_ERROR',
                        'WhatsAppImageAnalysisQueueable.execute',
                        'Analysis failed. mediaRecordId=' + media.Id +
                        ', contentDocumentId=' + cv.ContentDocumentId +
                        ', result=' + analysisResult,
                        null, null, null, null
                    );
                }

                if (String.isNotBlank(waMessageId)) {
                    WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();
                    WhatsAppMessageService.createOutboundMessage(
                        conversationId, customerPhone, config.Phone_Number__c,
                        'Text', messageText, waMessageId
                    );
                    WhatsAppConversationService.updateConversationOnMessage(conversationId, false);
                }

            } catch (Exception e) {
                System.debug('IMAGE_ANALYSIS_QUEUEABLE_EXCEPTION: ' + e.getMessage());
                WhatsAppLogService.logError(
                    'IMAGE_ANALYSIS_QUEUEABLE_FAILED',
                    'WhatsAppImageAnalysisQueueable.execute',
                    'Image analysis failed: ' + e.getMessage(),
                    null, null, e.getStackTraceString(), null
                );
            }
        }
    }

    private static String callImageAnalysisEndpoint(String orgDomain, String token, String contentDocumentId) {
        String endpoint = orgDomain + '/services/apexrest/whatsapp/image-analysis';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setBody(JSON.serialize(new Map<String, String>{
            'contentDocumentId' => contentDocumentId
        }));
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) responseMap.get('result');
        } else {
            return 'Error: HTTP ' + res.getStatusCode() + ' - ' + res.getBody();
        }
    }
}
