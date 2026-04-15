/**
 * @description Handler for WhatsApp media operations.
 *              Creates media records, downloads media from WhatsApp and stores
 *              in Salesforce Files, and uploads local files to WhatsApp.
 *              All methods are synchronous (no @future) to allow flexible
 *              invocation from Queueable, Batch, or Platform Event triggers.
 */
public with sharing class WhatsAppMediaHandler {
    /**
     * @description Creates a WhatsApp_Media__c record with Download_Status = Pending.
     * @param messageId  The parent WhatsApp_Message__c record Id
     * @param mediaId    The WhatsApp media ID
     * @param mediaType  The media type (image, video, audio, document, sticker)
     * @param mimeType   The MIME type string
     * @param fileName   The original file name (may be null)
     * @param caption    Optional caption text
     * @param sha256Hash Optional SHA-256 hash from WhatsApp
     * @return The inserted WhatsApp_Media__c record
     */
    public static WhatsApp_Media__c createMediaRecord(
        Id messageId,
        String mediaId,
        String mediaType,
        String mimeType,
        String fileName,
        String caption,
        String sha256Hash
    ) {
        WhatsApp_Media__c media = new WhatsApp_Media__c(
            Message__c = messageId,
            Media_ID__c = mediaId,
            Media_Type__c = mediaType,
            MIME_Type__c = mimeType,
            File_Name__c = fileName,
            SHA256_Hash__c = sha256Hash,
            Download_Status__c = WhatsAppConstants.DOWNLOAD_PENDING
        );
        insert media;
        return media;
    }

    /**
     * @description Downloads media from WhatsApp servers and stores it as a
     *              Salesforce ContentVersion/File linked to the parent message.
     *              Updates the media record with file metadata on success or
     *              marks it as Failed on error.
     * @param mediaRecordId The WhatsApp_Media__c record Id
     */
    public static void downloadAndStoreMedia(Id mediaRecordId) {
        WhatsApp_Media__c media;
        try {
            media = [
                SELECT Id, Media_ID__c, Media_Type__c, File_Name__c, MIME_Type__c, Download_Status__c, Message__c
                FROM WhatsApp_Media__c
                WHERE Id = :mediaRecordId
                LIMIT 1
            ];

            // Skip if already downloaded
            if (media.Download_Status__c == WhatsAppConstants.DOWNLOAD_COMPLETED) {
                return;
            }

            // Download the binary content from WhatsApp
            Blob fileContent = WhatsAppAPIService.downloadMedia(media.Media_ID__c);

            // Determine file name
            String fileName = String.isNotBlank(media.File_Name__c) ? media.File_Name__c : 'media_' + media.Media_ID__c;
            fileName = ensureFileExtension(fileName, media.MIME_Type__c);

            // Store as Salesforce ContentVersion
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = fileContent;
            insert cv;

            // Query to get the auto-created ContentDocumentId
            cv = [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
                LIMIT 1
            ];

            // Link the file to the parent message record
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.LinkedEntityId = media.Message__c;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;

            // Update media record with file references
            media.ContentVersion_ID__c = cv.Id;
            media.ContentDocumentId__c = cv.ContentDocumentId;
            media.File_Size__c = fileContent.size();
            media.Download_Status__c = WhatsAppConstants.DOWNLOAD_COMPLETED;
            update media;

            String mediaTypeLower = String.valueOf(media.Media_Type__c).toLowerCase();
            if (mediaTypeLower == 'audio') {
                processAudioTranscription(media, cv.Id, cv.ContentDocumentId);
            } else if (mediaTypeLower == 'document') {
                processFileContent(media, cv.Id, cv.ContentDocumentId);
            }
            WhatsAppLogService.logInfo(
                'MEDIA_DOWNLOAD_COMPLETED',
                'WhatsAppMediaHandler.downloadAndStoreMedia',
                'Downloaded and stored media successfully. mediaRecordId=' +
                    mediaRecordId +
                    ', mediaId=' +
                    media.Media_ID__c +
                    ', contentVersionId=' +
                    cv.Id
            );
        } catch (Exception e) {
            // Mark as failed and log the error
            if (mediaRecordId != null) {
                try {
                    WhatsApp_Media__c failedMedia = new WhatsApp_Media__c(
                        Id = mediaRecordId,
                        Download_Status__c = WhatsAppConstants.DOWNLOAD_FAILED
                    );
                    update failedMedia;
                } catch (Exception updateEx) {
                    System.debug('Failed to update media status to Failed: ' + updateEx.getMessage());
                }
            }

            WhatsAppLogService.logError(
                'MEDIA_DOWNLOAD_FAILED',
                'WhatsAppMediaHandler.downloadAndStoreMedia',
                'Failed to download/store media: ' + e.getMessage(),
                null,
                null,
                e.getStackTraceString(),
                null
            );
            Id relatedMessageId = (media != null) ? media.Message__c : null;
            WhatsAppErrorLogger.logMediaError('Error downloading media', relatedMessageId, e);
        }
    }

    /**
     * @description Uploads a Salesforce file to WhatsApp and returns the
     *              WhatsApp media ID. Uses hex-encoding approach to correctly
     *              build a multipart/form-data request with binary data in Apex.
     * @param contentVersionId The Salesforce ContentVersion Id
     * @param conversationId   The WhatsApp_Conversation__c Id (for context)
     * @param recipientPhone   The recipient phone number
     * @return The WhatsApp media ID returned by the API
     */
    public static String uploadMediaToWhatsApp(Id contentVersionId, String conversationId, String recipientPhone) {
        try {
            WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();

            // Get file content from Salesforce
            ContentVersion cv = [
                SELECT Id, VersionData, Title, FileType, ContentSize, FileExtension
                FROM ContentVersion
                WHERE Id = :contentVersionId
                LIMIT 1
            ];

            String endpoint = WhatsAppConfigService.getMediaEndpoint();
            String mimeType = getMimeType(cv.FileType);
            String fileName = cv.Title;

            // Build multipart/form-data using hex encoding for correct binary handling
            String boundary = '----FormBoundary' + String.valueOf(DateTime.now().getTime());

            // Part 1: messaging_product field
            String productPart =
                '--' +
                boundary +
                '\r\n' +
                'Content-Disposition: form-data; name="messaging_product"\r\n\r\n' +
                WhatsAppConstants.MESSAGE_PRODUCT +
                '\r\n';

            // Part 2: type field
            String mediaType = determineMediaType(cv.FileType);
            String typePart =
                '--' +
                boundary +
                '\r\n' +
                'Content-Disposition: form-data; name="type"\r\n\r\n' +
                mimeType +
                '\r\n';

            // Part 3: file data header
            String fileHeader =
                '--' +
                boundary +
                '\r\n' +
                'Content-Disposition: form-data; name="file"; filename="' +
                fileName +
                '"\r\n' +
                'Content-Type: ' +
                mimeType +
                '\r\n\r\n';

            // Part 4: closing boundary
            String fileFooter = '\r\n--' + boundary + '--';

            // Convert each part to hex and concatenate to preserve binary fidelity
            String headerHex = EncodingUtil.convertToHex(Blob.valueOf(productPart + typePart + fileHeader));
            String bodyHex = EncodingUtil.convertToHex(cv.VersionData);
            String footerHex = EncodingUtil.convertToHex(Blob.valueOf(fileFooter));

            Blob requestBlob = EncodingUtil.convertFromHex(headerHex + bodyHex + footerHex);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + config.API_Key__c);
            req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
            req.setBodyAsBlob(requestBlob);
            req.setTimeout(WhatsAppConstants.DEFAULT_TIMEOUT);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String whatsAppMediaId = (String) responseMap.get('id');
                return whatsAppMediaId;
            } else {
                throw new WhatsAppAPIService.WhatsAppException(
                    'Failed to upload media: HTTP ' + res.getStatusCode() + ' - ' + res.getBody()
                );
            }
        } catch (Exception e) {
            WhatsAppErrorLogger.logMediaError('Error uploading media to WhatsApp', null, e);
            throw new WhatsAppAPIService.WhatsAppException('Error uploading media: ' + e.getMessage());
        }
    }

    /**
     * @description Returns a Salesforce download URL for the media file.
     * @param mediaRecordId The WhatsApp_Media__c record Id
     * @return The ContentVersion download URL, or null if not available
     */
    @AuraEnabled(cacheable=true)
    public static String getMediaPreviewUrl(Id mediaRecordId) {
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
     * @description Maps file extensions to MIME types, including WhatsApp-specific formats.
     * @param fileType The file extension (e.g., 'jpg', 'webp', 'ogg')
     * @return The corresponding MIME type string
     */
    private static String getMimeType(String fileType) {
        if (String.isBlank(fileType)) {
            return 'application/octet-stream';
        }

        Map<String, String> mimeTypes = new Map<String, String>{
            // Images
            'jpg' => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'gif' => 'image/gif',
            'webp' => 'image/webp',
            'bmp' => 'image/bmp',
            'svg' => 'image/svg+xml',
            // Video
            'mp4' => 'video/mp4',
            'avi' => 'video/x-msvideo',
            '3gp' => 'video/3gpp',
            'mkv' => 'video/x-matroska',
            'mov' => 'video/quicktime',
            // Audio
            'mp3' => 'audio/mpeg',
            'ogg' => 'audio/ogg',
            'amr' => 'audio/amr',
            'opus' => 'audio/opus',
            'aac' => 'audio/aac',
            'wav' => 'audio/wav',
            'm4a' => 'audio/mp4',
            // Documents
            'pdf' => 'application/pdf',
            'doc' => 'application/msword',
            'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'xls' => 'application/vnd.ms-excel',
            'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'ppt' => 'application/vnd.ms-powerpoint',
            'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            'txt' => 'text/plain',
            'csv' => 'text/csv',
            'zip' => 'application/zip',
            'json' => 'application/json',
            'xml' => 'application/xml'
        };

        String key = fileType.toLowerCase();
        return mimeTypes.containsKey(key) ? mimeTypes.get(key) : 'application/octet-stream';
    }

    /**
     * @description Determines the WhatsApp media category from a file extension.
     * @param fileType The file extension
     * @return One of: image, video, audio, document, sticker
     */
    private static String determineMediaType(String fileType) {
        if (String.isBlank(fileType)) {
            return WhatsAppConstants.MEDIA_DOCUMENT;
        }

        fileType = fileType.toLowerCase();

        Set<String> imageTypes = new Set<String>{ 'jpg', 'jpeg', 'png', 'gif', 'bmp', 'svg' };
        Set<String> videoTypes = new Set<String>{ 'mp4', 'avi', '3gp', 'mkv', 'mov' };
        Set<String> audioTypes = new Set<String>{ 'mp3', 'ogg', 'amr', 'opus', 'aac', 'wav', 'm4a' };
        Set<String> stickerTypes = new Set<String>{ 'webp' };

        if (imageTypes.contains(fileType)) {
            return WhatsAppConstants.MEDIA_IMAGE;
        } else if (videoTypes.contains(fileType)) {
            return WhatsAppConstants.MEDIA_VIDEO;
        } else if (audioTypes.contains(fileType)) {
            return WhatsAppConstants.MEDIA_AUDIO;
        } else if (stickerTypes.contains(fileType)) {
            return WhatsAppConstants.MEDIA_STICKER;
        } else {
            return WhatsAppConstants.MEDIA_DOCUMENT;
        }
    }

    private static String ensureFileExtension(String fileName, String mimeType) {
        if (String.isBlank(fileName)) {
            fileName = 'media_file';
        }
        if (fileName.contains('.')) {
            return fileName;
        }

        String ext = getExtensionFromMimeType(mimeType);
        if (String.isBlank(ext)) {
            return fileName;
        }
        return fileName + '.' + ext;
    }

    private static String getExtensionFromMimeType(String mimeType) {
        if (String.isBlank(mimeType)) {
            return null;
        }
        String normalized = mimeType.toLowerCase().trim();
        Integer semicolonIndex = normalized.indexOf(';');
        if (semicolonIndex > -1) {
            normalized = normalized.substring(0, semicolonIndex).trim();
        }
        Map<String, String> mimeToExt = new Map<String, String>{
            'audio/ogg' => 'ogg',
            'audio/mpeg' => 'mp3',
            'audio/mp3' => 'mp3',
            'audio/mp4' => 'm4a',
            'audio/x-m4a' => 'm4a',
            'audio/wav' => 'wav',
            'audio/x-wav' => 'wav',
            'audio/amr' => 'amr',
            'audio/webm' => 'webm',
            'audio/flac' => 'flac',
            'audio/x-flac' => 'flac',
            'video/mp4' => 'mp4',
            'image/jpeg' => 'jpg',
            'image/png' => 'png',
            'application/pdf' => 'pdf'
        };
        return mimeToExt.containsKey(normalized) ? mimeToExt.get(normalized) : null;
    }

    private static void processAudioTranscription(WhatsApp_Media__c media, Id contentVersionId, Id contentDocumentId) {
        try {
            WhatsApp_Message__c sourceMessage = [
                SELECT Id, Conversation__c, Sender_Phone__c, Recipient_Phone__c
                FROM WhatsApp_Message__c
                WHERE Id = :media.Message__c
                LIMIT 1
            ];

            String transcription = WhatsAppAudioTranscriptionService.transcribeAudio(contentDocumentId);

            if (String.isBlank(transcription)) {
                WhatsAppLogService.logWarn(
                    'AUDIO_TRANSCRIPTION_EMPTY',
                    'WhatsAppMediaHandler.processAudioTranscription',
                    'Transcription flow returned empty text. mediaRecordId=' + media.Id,
                    null
                );
                return;
            }

            WhatsApp_Message__c transcriptMessage = WhatsAppMessageService.createInboundTranscriptionMessage(
                sourceMessage.Conversation__c,
                sourceMessage.Sender_Phone__c,
                sourceMessage.Recipient_Phone__c,
                transcription,
                media.Media_ID__c
            );
            WhatsAppConversationService.updateConversationOnMessage(sourceMessage.Conversation__c, true);

            if (!Test.isRunningTest()) {
                String jobId = System.enqueueJob(
                    new WhatsAppAgentforceQueueable(sourceMessage.Conversation__c, transcriptMessage.Id)
                );
                WhatsAppLogService.logInfo(
                    'AUDIO_TRANSCRIPTION_ROUTED_TO_AGENTFORCE',
                    'WhatsAppMediaHandler.processAudioTranscription',
                    'Transcription message created and routed. transcriptMessageId=' +
                        transcriptMessage.Id +
                        ', queueableJobId=' +
                        jobId
                );
            }
        } catch (Exception e) {
            WhatsAppLogService.logError(
                'AUDIO_TRANSCRIPTION_PIPELINE_FAILED',
                'WhatsAppMediaHandler.processAudioTranscription',
                'Audio transcription pipeline failed: ' + e.getMessage(),
                null,
                null,
                e.getStackTraceString(),
                null
            );
        }
    }

    private static void processFileContent(WhatsApp_Media__c media, Id contentVersionId, Id contentDocumentId) {
        try {
            WhatsApp_Message__c sourceMessage = [
                SELECT Id, Conversation__c, Sender_Phone__c, Recipient_Phone__c
                FROM WhatsApp_Message__c
                WHERE Id = :media.Message__c
                LIMIT 1
            ];

            String fileContent = WhatsAppMediaFlowService.processMedia(
                contentDocumentId,
                WhatsAppMediaFlowService.forFile()
            );

            if (String.isBlank(fileContent)) {
                WhatsAppLogService.logWarn(
                    'FILE_PROCESSING_EMPTY',
                    'WhatsAppMediaHandler.processFileContent',
                    'File processing flow returned empty text. mediaRecordId=' + media.Id,
                    null
                );
                return;
            }

            WhatsApp_Message__c contentMessage = WhatsAppMessageService.createInboundTranscriptionMessage(
                sourceMessage.Conversation__c,
                sourceMessage.Sender_Phone__c,
                sourceMessage.Recipient_Phone__c,
                fileContent,
                media.Media_ID__c
            );
            WhatsAppConversationService.updateConversationOnMessage(sourceMessage.Conversation__c, true);

            if (!Test.isRunningTest()) {
                String jobId = System.enqueueJob(
                    new WhatsAppAgentforceQueueable(sourceMessage.Conversation__c, contentMessage.Id)
                );
                WhatsAppLogService.logInfo(
                    'FILE_PROCESSING_ROUTED_TO_AGENTFORCE',
                    'WhatsAppMediaHandler.processFileContent',
                    'File content message created and routed. contentMessageId=' +
                        contentMessage.Id +
                        ', queueableJobId=' +
                        jobId
                );
            }
        } catch (Exception e) {
            WhatsAppLogService.logError(
                'FILE_PROCESSING_PIPELINE_FAILED',
                'WhatsAppMediaHandler.processFileContent',
                'File processing pipeline failed: ' + e.getMessage(),
                null,
                null,
                e.getStackTraceString(),
                null
            );
        }
    }
}
