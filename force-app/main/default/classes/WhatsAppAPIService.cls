/**
 * @description Core service class for WhatsApp Business API HTTP callouts.
 *              Supports all WhatsApp message types: text, media, location, contact,
 *              interactive, template, reaction, and sticker.
 *              Delegates configuration to WhatsAppConfigService, constants to WhatsAppConstants,
 *              and error logging to WhatsAppErrorLogger.
 *              All public methods are synchronous — callers decide async context (Queueable, @future).
 */
public with sharing class WhatsAppAPIService {

    // ─── Send Text Message ────────────────────────────────────────────────
    /**
     * @description Sends a plain text message via WhatsApp.
     * @param recipientPhone Recipient phone number in international format
     * @param messageText The text content to send
     * @return The WhatsApp message ID
     */
    public static String sendTextMessage(String recipientPhone, String messageText) {
        Map<String, Object> requestBody = new Map<String, Object>{
            'messaging_product' => WhatsAppConstants.MESSAGE_PRODUCT,
            'recipient_type' => WhatsAppConstants.RECIPIENT_TYPE,
            'to' => recipientPhone,
            'type' => WhatsAppConstants.TYPE_TEXT,
            'text' => new Map<String, Object>{
                'body' => messageText
            }
        };
        return sendMessage(requestBody);
    }

    // ─── Send Media Message ───────────────────────────────────────────────
    /**
     * @description Sends a media message (image, video, audio, document) via WhatsApp.
     * @param recipientPhone Recipient phone number
     * @param mediaId WhatsApp media ID of the uploaded asset
     * @param mediaType The media type (image, video, audio, document)
     * @param caption Optional caption for the media (ignored for audio)
     * @return The WhatsApp message ID
     */
    public static String sendMediaMessage(String recipientPhone, String mediaId, String mediaType, String caption) {
        String normalizedType = mediaType.toLowerCase();

        Map<String, Object> mediaObject = new Map<String, Object>{
            'id' => mediaId
        };
        if (String.isNotBlank(caption)) {
            mediaObject.put('caption', caption);
        }

        Map<String, Object> requestBody = new Map<String, Object>{
            'messaging_product' => WhatsAppConstants.MESSAGE_PRODUCT,
            'recipient_type' => WhatsAppConstants.RECIPIENT_TYPE,
            'to' => recipientPhone,
            'type' => normalizedType,
            normalizedType => mediaObject
        };
        return sendMessage(requestBody);
    }

    // ─── Send Location Message ────────────────────────────────────────────
    /**
     * @description Sends a location pin via WhatsApp.
     * @param recipientPhone Recipient phone number
     * @param latitude Location latitude
     * @param longitude Location longitude
     * @param name Optional location name
     * @param address Optional street address
     * @return The WhatsApp message ID
     */
    public static String sendLocationMessage(String recipientPhone, Double latitude, Double longitude, String name, String address) {
        Map<String, Object> locationObject = new Map<String, Object>{
            'latitude' => latitude,
            'longitude' => longitude
        };
        if (String.isNotBlank(name)) {
            locationObject.put('name', name);
        }
        if (String.isNotBlank(address)) {
            locationObject.put('address', address);
        }

        Map<String, Object> requestBody = new Map<String, Object>{
            'messaging_product' => WhatsAppConstants.MESSAGE_PRODUCT,
            'recipient_type' => WhatsAppConstants.RECIPIENT_TYPE,
            'to' => recipientPhone,
            'type' => WhatsAppConstants.TYPE_LOCATION,
            'location' => locationObject
        };
        return sendMessage(requestBody);
    }

    // ─── Send Contact Message ─────────────────────────────────────────────
    /**
     * @description Sends a contact card via WhatsApp.
     * @param recipientPhone Recipient phone number
     * @param contactJson JSON string representing the contacts array payload
     * @return The WhatsApp message ID
     */
    public static String sendContactMessage(String recipientPhone, String contactJson) {
        List<Object> contacts = (List<Object>) JSON.deserializeUntyped(contactJson);

        Map<String, Object> requestBody = new Map<String, Object>{
            'messaging_product' => WhatsAppConstants.MESSAGE_PRODUCT,
            'recipient_type' => WhatsAppConstants.RECIPIENT_TYPE,
            'to' => recipientPhone,
            'type' => WhatsAppConstants.TYPE_CONTACTS,
            'contacts' => contacts
        };
        return sendMessage(requestBody);
    }

    // ─── Send Interactive Message ─────────────────────────────────────────
    /**
     * @description Sends an interactive message (buttons, lists, CTAs) via WhatsApp.
     * @param recipientPhone Recipient phone number
     * @param interactivePayload Map representing the interactive object
     * @return The WhatsApp message ID
     */
    public static String sendInteractiveMessage(String recipientPhone, Map<String, Object> interactivePayload) {
        Map<String, Object> requestBody = new Map<String, Object>{
            'messaging_product' => WhatsAppConstants.MESSAGE_PRODUCT,
            'recipient_type' => WhatsAppConstants.RECIPIENT_TYPE,
            'to' => recipientPhone,
            'type' => WhatsAppConstants.TYPE_INTERACTIVE,
            'interactive' => interactivePayload
        };
        return sendMessage(requestBody);
    }

    // ─── Send Template Message ────────────────────────────────────────────
    /**
     * @description Sends a pre-approved template message via WhatsApp.
     * @param recipientPhone Recipient phone number
     * @param templateName The template name as registered in WhatsApp Business Manager
     * @param languageCode Language code (e.g., 'en_US')
     * @param components Optional list of component parameter maps
     * @return The WhatsApp message ID
     */
    public static String sendTemplateMessage(String recipientPhone, String templateName, String languageCode, List<Map<String, Object>> components) {
        Map<String, Object> templateObject = new Map<String, Object>{
            'name' => templateName,
            'language' => new Map<String, Object>{
                'code' => languageCode
            }
        };
        if (components != null && !components.isEmpty()) {
            templateObject.put('components', components);
        }

        Map<String, Object> requestBody = new Map<String, Object>{
            'messaging_product' => WhatsAppConstants.MESSAGE_PRODUCT,
            'recipient_type' => WhatsAppConstants.RECIPIENT_TYPE,
            'to' => recipientPhone,
            'type' => WhatsAppConstants.TYPE_TEMPLATE,
            'template' => templateObject
        };
        return sendMessage(requestBody);
    }

    // ─── Send Reaction Message ────────────────────────────────────────────
    /**
     * @description Sends an emoji reaction to a specific message.
     * @param recipientPhone Recipient phone number
     * @param targetMessageId The WhatsApp message ID to react to
     * @param emoji The emoji character to send as a reaction
     * @return The WhatsApp message ID
     */
    public static String sendReactionMessage(String recipientPhone, String targetMessageId, String emoji) {
        Map<String, Object> requestBody = new Map<String, Object>{
            'messaging_product' => WhatsAppConstants.MESSAGE_PRODUCT,
            'recipient_type' => WhatsAppConstants.RECIPIENT_TYPE,
            'to' => recipientPhone,
            'type' => WhatsAppConstants.TYPE_REACTION,
            'reaction' => new Map<String, Object>{
                'message_id' => targetMessageId,
                'emoji' => emoji
            }
        };
        return sendMessage(requestBody);
    }

    // ─── Send Sticker Message ─────────────────────────────────────────────
    /**
     * @description Sends a sticker message via WhatsApp.
     * @param recipientPhone Recipient phone number
     * @param stickerId WhatsApp media ID of the uploaded sticker
     * @return The WhatsApp message ID
     */
    public static String sendStickerMessage(String recipientPhone, String stickerId) {
        Map<String, Object> requestBody = new Map<String, Object>{
            'messaging_product' => WhatsAppConstants.MESSAGE_PRODUCT,
            'recipient_type' => WhatsAppConstants.RECIPIENT_TYPE,
            'to' => recipientPhone,
            'type' => WhatsAppConstants.TYPE_STICKER,
            'sticker' => new Map<String, Object>{
                'id' => stickerId
            }
        };
        return sendMessage(requestBody);
    }

    // ─── Mark as Read ─────────────────────────────────────────────────────
    /**
     * @description Sends a read receipt for a specific message.
     * @param messageId The WhatsApp message ID to mark as read
     * @return true if the read receipt was sent successfully
     */
    public static Boolean markAsRead(String messageId) {
        WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();
        String endpoint = WhatsAppConfigService.getMessagesEndpoint();

        Map<String, Object> requestBody = new Map<String, Object>{
            'messaging_product' => WhatsAppConstants.MESSAGE_PRODUCT,
            'status' => 'read',
            'message_id' => messageId
        };

        HttpRequest req = buildRequest(endpoint, config.API_Key__c);
        req.setBody(JSON.serialize(requestBody));

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                WhatsAppLogService.logInfo(
                    'MARK_AS_READ_SUCCESS',
                    'WhatsAppAPIService.markAsRead',
                    'Read receipt sent successfully for messageId=' + messageId
                );
                return true;
            }

            WhatsAppLogService.logWarn(
                'MARK_AS_READ_FAILED',
                'WhatsAppAPIService.markAsRead',
                'Failed to send read receipt for messageId=' + messageId,
                res.getStatusCode()
            );
            WhatsAppErrorLogger.logApiError(
                String.valueOf(res.getStatusCode()),
                'Failed to send read receipt for message ' + messageId,
                JSON.serialize(requestBody),
                res.getBody()
            );
            return false;
        } catch (Exception e) {
            WhatsAppErrorLogger.logError(WhatsAppConstants.ERROR_API, 'Error sending read receipt', e);
            return false;
        }
    }

    // ─── Get Media URL ────────────────────────────────────────────────────
    /**
     * @description Retrieves the temporary download URL for a WhatsApp media item.
     *              This is the first step of the two-step media download process.
     * @param mediaId The WhatsApp media ID
     * @return The temporary media download URL
     */
    public static String getMediaUrl(String mediaId) {
        WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();
        String endpoint = WhatsAppConfigService.getMediaUrlEndpoint(mediaId);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + config.API_Key__c);
        req.setTimeout(WhatsAppConstants.DEFAULT_TIMEOUT);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String mediaUrl = (String) responseMap.get('url');
                if (String.isNotBlank(mediaUrl)) {
                    return mediaUrl;
                }
            }

            WhatsAppErrorLogger.logApiError(
                String.valueOf(res.getStatusCode()),
                'Failed to retrieve media URL for media ' + mediaId,
                null,
                res.getBody()
            );
            throw new WhatsAppException('Failed to retrieve media URL: ' + res.getBody());
        } catch (WhatsAppException e) {
            throw e;
        } catch (Exception e) {
            WhatsAppLogService.logError(
                'GET_MEDIA_URL_EXCEPTION',
                'WhatsAppAPIService.getMediaUrl',
                'Error retrieving media URL for mediaId=' + mediaId + ': ' + e.getMessage(),
                null,
                null,
                e.getStackTraceString(),
                null
            );
            WhatsAppErrorLogger.logError(WhatsAppConstants.ERROR_MEDIA, 'Error retrieving media URL', e);
            throw new WhatsAppException('Error retrieving media URL: ' + e.getMessage());
        }
    }

    // ─── Download Media ───────────────────────────────────────────────────
    /**
     * @description Downloads a media file from WhatsApp (two-step: get URL then download binary).
     * @param mediaId The WhatsApp media ID
     * @return The media file as a Blob
     */
    public static Blob downloadMedia(String mediaId) {
        WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();

        String mediaUrl = getMediaUrl(mediaId);

        HttpRequest mediaReq = new HttpRequest();
        mediaReq.setEndpoint(mediaUrl);
        mediaReq.setMethod('GET');
        mediaReq.setHeader('Authorization', 'Bearer ' + config.API_Key__c);
        mediaReq.setTimeout(WhatsAppConstants.DEFAULT_TIMEOUT);

        try {
            Http http = new Http();
            HttpResponse mediaRes = http.send(mediaReq);

            if (mediaRes.getStatusCode() == 200) {
                return mediaRes.getBodyAsBlob();
            }

            WhatsAppErrorLogger.logApiError(
                String.valueOf(mediaRes.getStatusCode()),
                'Failed to download media binary for media ' + mediaId,
                null,
                mediaRes.getBody()
            );
            throw new WhatsAppException('Failed to download media: ' + mediaRes.getBody());
        } catch (WhatsAppException e) {
            throw e;
        } catch (Exception e) {
            WhatsAppLogService.logError(
                'DOWNLOAD_MEDIA_EXCEPTION',
                'WhatsAppAPIService.downloadMedia',
                'Error downloading media for mediaId=' + mediaId + ': ' + e.getMessage(),
                null,
                null,
                e.getStackTraceString(),
                null
            );
            WhatsAppErrorLogger.logError(WhatsAppConstants.ERROR_MEDIA, 'Error downloading media', e);
            throw new WhatsAppException('Error downloading media: ' + e.getMessage());
        }
    }

    // ─── Private Helpers ──────────────────────────────────────────────────

    /**
     * @description Builds an HttpRequest, sends the message payload to the WhatsApp messages endpoint,
     *              parses the response, and returns the WhatsApp message ID.
     * @param requestBody The complete request body map to serialize and send
     * @return The WhatsApp message ID from the response
     */
    private static String sendMessage(Map<String, Object> requestBody) {
        WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();
        String endpoint = WhatsAppConfigService.getMessagesEndpoint();
        String serializedBody = JSON.serialize(requestBody);

        HttpRequest req = buildRequest(endpoint, config.API_Key__c);
        req.setBody(serializedBody);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> messages = (List<Object>) responseMap.get('messages');
                if (messages != null && !messages.isEmpty()) {
                    Map<String, Object> messageData = (Map<String, Object>) messages[0];
                    WhatsAppLogService.logInfo(
                        'SEND_MESSAGE_SUCCESS',
                        'WhatsAppAPIService.sendMessage',
                        'Outbound message sent successfully.'
                    );
                    return (String) messageData.get('id');
                }
                throw new WhatsAppException('No message ID returned in API response');
            }

            WhatsAppLogService.logWarn(
                'SEND_MESSAGE_FAILED',
                'WhatsAppAPIService.sendMessage',
                'WhatsApp API returned non-success status.',
                res.getStatusCode()
            );
            WhatsAppErrorLogger.logApiError(
                String.valueOf(res.getStatusCode()),
                'WhatsApp API returned error',
                serializedBody,
                res.getBody()
            );
            throw new WhatsAppException('WhatsApp API error (HTTP ' + res.getStatusCode() + '): ' + res.getBody());
        } catch (WhatsAppException e) {
            throw e;
        } catch (Exception e) {
            WhatsAppLogService.logError(
                'SEND_MESSAGE_EXCEPTION',
                'WhatsAppAPIService.sendMessage',
                'Unexpected exception sending message: ' + e.getMessage(),
                serializedBody,
                null,
                e.getStackTraceString(),
                null
            );
            WhatsAppErrorLogger.logError(WhatsAppConstants.ERROR_API, 'Error sending WhatsApp message', e);
            throw new WhatsAppException('Error sending message: ' + e.getMessage());
        }
    }

    /**
     * @description Builds a standard POST HttpRequest with common headers.
     * @param endpoint The full endpoint URL
     * @param apiKey The Bearer token for authorization
     * @return A configured HttpRequest ready for a body to be set
     */
    private static HttpRequest buildRequest(String endpoint, String apiKey) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setTimeout(WhatsAppConstants.DEFAULT_TIMEOUT);
        return req;
    }

    // ─── Inner Exception Class ────────────────────────────────────────────

    /**
     * @description Custom exception class for WhatsApp API errors.
     */
    public class WhatsAppException extends Exception {}
}