/**
 * @description Handler for WhatsApp media operations
 * Downloads media from WhatsApp and stores in Salesforce Files
 */
public with sharing class WhatsAppMediaHandler {

    /**
     * @description Download media asynchronously
     * @param mediaRecordId WhatsApp_Media__c record ID
     */
    @future(callout=true)
    public static void downloadMediaAsync(String mediaRecordId) {
        try {
            WhatsApp_Media__c media = [
                SELECT Id, Media_ID__c, Media_Type__c, File_Name__c,
                       MIME_Type__c, Download_Status__c, Message__c
                FROM WhatsApp_Media__c
                WHERE Id = :mediaRecordId
                LIMIT 1
            ];

            if (media.Download_Status__c == 'Completed') {
                return;
            }

            // Update status to downloading
            media.Download_Status__c = 'Downloading';
            update media;

            // Download from WhatsApp
            Blob fileContent = WhatsAppAPIService.downloadMedia(media.Media_ID__c);

            // Store in Salesforce Files
            String fileName = media.File_Name__c != null ? media.File_Name__c : 'media_' + media.Media_ID__c;

            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = fileContent;
            cv.FirstPublishLocationId = media.Message__c;
            insert cv;

            // Update media record
            media.ContentVersion_ID__c = cv.Id;
            media.File_Size__c = fileContent.size();
            media.Download_Status__c = 'Completed';
            update media;

        } catch (Exception e) {
            System.debug('Error downloading media: ' + e.getMessage());
            updateMediaStatus(mediaRecordId, 'Failed');
        }
    }

    /**
     * @description Update media download status
     */
    private static void updateMediaStatus(String mediaRecordId, String status) {
        try {
            WhatsApp_Media__c media = new WhatsApp_Media__c(
                Id = mediaRecordId,
                Download_Status__c = status
            );
            update media;
        } catch (Exception e) {
            System.debug('Error updating media status: ' + e.getMessage());
        }
    }

    /**
     * @description Get media preview URL
     * @param mediaRecordId WhatsApp_Media__c record ID
     * @return String Preview URL
     */
    @AuraEnabled(cacheable=true)
    public static String getMediaPreviewUrl(String mediaRecordId) {
        try {
            WhatsApp_Media__c media = [
                SELECT Id, ContentVersion_ID__c
                FROM WhatsApp_Media__c
                WHERE Id = :mediaRecordId
                LIMIT 1
            ];

            if (media.ContentVersion_ID__c != null) {
                ContentVersion cv = [
                    SELECT Id, ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :media.ContentVersion_ID__c
                    LIMIT 1
                ];

                return '/sfc/servlet.shepherd/version/download/' + cv.Id;
            }

            return null;
        } catch (Exception e) {
            throw new AuraHandledException('Error getting media preview: ' + e.getMessage());
        }
    }

    /**
     * @description Upload media to WhatsApp for sending
     * @param contentVersionId Salesforce ContentVersion ID
     * @return String WhatsApp media ID
     */
    @future(callout=true)
    public static void uploadMediaToWhatsApp(String contentVersionId, String conversationId) {
        try {
            WhatsApp_Configuration__c config = WhatsAppAPIService.getActiveConfiguration();

            // Get file content
            ContentVersion cv = [
                SELECT Id, VersionData, Title, FileType, ContentSize
                FROM ContentVersion
                WHERE Id = :contentVersionId
                LIMIT 1
            ];

            String endpoint = config.API_Base_URL__c + '/' + config.Phone_Number__c + '/media';

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + config.API_Key__c);

            // Create multipart form data
            String boundary = '----WebKitFormBoundary' + String.valueOf(DateTime.now().getTime());
            req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);

            String bodyStart = '--' + boundary + '\r\n' +
                              'Content-Disposition: form-data; name="file"; filename="' + cv.Title + '"\r\n' +
                              'Content-Type: ' + getMimeType(cv.FileType) + '\r\n\r\n';

            String bodyEnd = '\r\n--' + boundary + '--';

            Blob bodyBlob = Blob.valueOf(bodyStart);
            bodyBlob = Blob.valueOf(EncodingUtil.base64Encode(bodyBlob) +
                                   EncodingUtil.base64Encode(cv.VersionData) +
                                   EncodingUtil.base64Encode(Blob.valueOf(bodyEnd)));

            req.setBodyAsBlob(bodyBlob);
            req.setTimeout(60000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String mediaId = (String) responseMap.get('id');

                // Now send the media message
                WhatsApp_Conversation__c conv = [
                    SELECT Id, Customer_Phone__c
                    FROM WhatsApp_Conversation__c
                    WHERE Id = :conversationId
                    LIMIT 1
                ];

                String mediaType = determineMediaType(cv.FileType);
                WhatsAppAPIService.sendMediaMessage(conv.Customer_Phone__c, mediaId, mediaType, cv.Title, conversationId);
            } else {
                throw new WhatsAppAPIService.WhatsAppException('Failed to upload media: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error uploading media to WhatsApp: ' + e.getMessage());
        }
    }

    /**
     * @description Get MIME type from file extension
     */
    private static String getMimeType(String fileType) {
        Map<String, String> mimeTypes = new Map<String, String>{
            'jpg' => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'gif' => 'image/gif',
            'mp4' => 'video/mp4',
            'mp3' => 'audio/mpeg',
            'pdf' => 'application/pdf',
            'doc' => 'application/msword',
            'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        };

        return mimeTypes.get(fileType.toLowerCase()) != null ?
               mimeTypes.get(fileType.toLowerCase()) : 'application/octet-stream';
    }

    /**
     * @description Determine media type for WhatsApp
     */
    private static String determineMediaType(String fileType) {
        fileType = fileType.toLowerCase();

        if (fileType == 'jpg' || fileType == 'jpeg' || fileType == 'png' || fileType == 'gif') {
            return 'image';
        } else if (fileType == 'mp4' || fileType == 'avi') {
            return 'video';
        } else if (fileType == 'mp3' || fileType == 'ogg' || fileType == 'amr') {
            return 'audio';
        } else {
            return 'document';
        }
    }
}
