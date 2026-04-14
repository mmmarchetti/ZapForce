/**
 * @description Invocable action to analyze the most recent image shared
 *              by a customer in a WhatsApp conversation using AI vision.
 *              Returns a detailed description of the image contents.
 */
public with sharing class WhatsAppAnalyzeImageAction {

    public class AnalyzeImageRequest {
        @InvocableVariable(required=true label='Conversation ID' description='The WhatsApp Conversation record ID')
        public String conversationId;
    }

    public class AnalyzeImageResult {
        @InvocableVariable public Boolean imageFound;
        @InvocableVariable public String description;
        @InvocableVariable public String imageMimeType;
        @InvocableVariable public String imageFileName;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Analyze WhatsApp Image'
                     description='Analyzes the most recent image shared by the customer using AI vision'
                     category='WhatsApp')
    public static List<AnalyzeImageResult> analyzeImage(List<AnalyzeImageRequest> requests) {
        List<AnalyzeImageResult> results = new List<AnalyzeImageResult>();
        for (AnalyzeImageRequest req : requests) {
            AnalyzeImageResult result = new AnalyzeImageResult();
            try {
                if (String.isBlank(req.conversationId)) {
                    result.imageFound = false;
                    result.errorMessage = 'Conversation ID is required.';
                    results.add(result);
                    continue;
                }

                // Find the most recent inbound image media record
                List<WhatsApp_Media__c> mediaRecords = [
                    SELECT Id, Media_Type__c, MIME_Type__c, File_Name__c,
                           Download_Status__c, ContentVersion_ID__c
                    FROM WhatsApp_Media__c
                    WHERE Message__r.Conversation__c = :req.conversationId
                      AND Media_Type__c = 'Image'
                      AND Message__r.Direction__c = :WhatsAppConstants.DIRECTION_INBOUND
                    ORDER BY CreatedDate DESC, Id DESC
                    LIMIT 1
                ];

                if (mediaRecords.isEmpty()) {
                    result.imageFound = false;
                    result.errorMessage = 'No image has been shared in this conversation yet. Please ask the customer to send an image.';
                    results.add(result);
                    continue;
                }

                WhatsApp_Media__c media = mediaRecords[0];
                result.imageMimeType = media.MIME_Type__c;
                result.imageFileName = media.File_Name__c;

                // Check download status
                if (media.Download_Status__c == WhatsAppConstants.DOWNLOAD_PENDING ||
                    media.Download_Status__c == WhatsAppConstants.DOWNLOAD_DOWNLOADING) {
                    result.imageFound = true;
                    result.errorMessage = 'The image is still being downloaded. Please wait a moment and try again.';
                    results.add(result);
                    continue;
                }

                if (media.Download_Status__c == WhatsAppConstants.DOWNLOAD_FAILED) {
                    result.imageFound = true;
                    result.errorMessage = 'The image download failed. Please ask the customer to resend the image.';
                    results.add(result);
                    continue;
                }

                if (String.isBlank(media.ContentVersion_ID__c)) {
                    result.imageFound = true;
                    result.errorMessage = 'The image file is not available. Please ask the customer to resend the image.';
                    results.add(result);
                    continue;
                }

                // Get the ContentDocumentId from the ContentVersion
                ContentVersion cv = [
                    SELECT Id, ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :media.ContentVersion_ID__c
                    LIMIT 1
                ];

                result.imageFound = true;

                // Analyze the image using the Prompt Template with ContentDocument reference
                String analysisResult = WhatsAppImageAnalysisService.analyzeImageByDocument(
                    cv.ContentDocumentId
                );

                if (analysisResult != null && analysisResult.startsWith('Error: ')) {
                    result.errorMessage = analysisResult.substringAfter('Error: ');
                } else {
                    result.description = analysisResult;
                }

            } catch (Exception e) {
                result.imageFound = false;
                result.errorMessage = e.getMessage();
            }
            results.add(result);
        }
        return results;
    }
}
