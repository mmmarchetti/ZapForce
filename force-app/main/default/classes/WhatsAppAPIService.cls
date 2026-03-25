/**
 * @description Service class for WhatsApp Business API integration
 * Handles all HTTP callouts to WhatsApp API
 */
public with sharing class WhatsAppAPIService {

    private static final String API_VERSION = 'v18.0';

    /**
     * @description Get active WhatsApp configuration
     * @return WhatsApp_Configuration__c Active configuration record
     */
    public static WhatsApp_Configuration__c getActiveConfiguration() {
        List<WhatsApp_Configuration__c> configs = [
            SELECT Id, API_Key__c, Phone_Number__c, API_Base_URL__c,
                   Business_Account_ID__c, Is_Active__c
            FROM WhatsApp_Configuration__c
            WHERE Is_Active__c = true
            LIMIT 1
        ];

        if (configs.isEmpty()) {
            throw new WhatsAppException('No active WhatsApp configuration found');
        }

        return configs[0];
    }

    /**
     * @description Send a text message via WhatsApp
     * @param recipientPhone Recipient phone number
     * @param messageText Message content
     * @return String Message ID from WhatsApp
     */
    @future(callout=true)
    public static void sendTextMessage(String recipientPhone, String messageText, String conversationId) {
        try {
            WhatsApp_Configuration__c config = getActiveConfiguration();

            String endpoint = config.API_Base_URL__c + '/' + config.Phone_Number__c + '/messages';

            Map<String, Object> requestBody = new Map<String, Object>{
                'messaging_product' => 'whatsapp',
                'recipient_type' => 'individual',
                'to' => recipientPhone,
                'type' => 'text',
                'text' => new Map<String, Object>{
                    'body' => messageText
                }
            };

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + config.API_Key__c);
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(60000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> messages = (List<Object>) responseMap.get('messages');
                if (messages != null && !messages.isEmpty()) {
                    Map<String, Object> messageData = (Map<String, Object>) messages[0];
                    String messageId = (String) messageData.get('id');

                    // Create outbound message record
                    createOutboundMessageRecord(messageId, recipientPhone, config.Phone_Number__c, messageText, conversationId);
                }
            } else {
                throw new WhatsAppException('Failed to send message: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error sending WhatsApp message: ' + e.getMessage());
            throw new WhatsAppException('Error sending message: ' + e.getMessage());
        }
    }

    /**
     * @description Send a media message via WhatsApp
     * @param recipientPhone Recipient phone number
     * @param mediaId WhatsApp media ID
     * @param mediaType Type of media (image, video, audio, document)
     * @param caption Optional caption for media
     */
    @future(callout=true)
    public static void sendMediaMessage(String recipientPhone, String mediaId, String mediaType, String caption, String conversationId) {
        try {
            WhatsApp_Configuration__c config = getActiveConfiguration();

            String endpoint = config.API_Base_URL__c + '/' + config.Phone_Number__c + '/messages';

            Map<String, Object> mediaObject = new Map<String, Object>{
                'id' => mediaId
            };

            if (String.isNotBlank(caption)) {
                mediaObject.put('caption', caption);
            }

            Map<String, Object> requestBody = new Map<String, Object>{
                'messaging_product' => 'whatsapp',
                'recipient_type' => 'individual',
                'to' => recipientPhone,
                'type' => mediaType.toLowerCase(),
                mediaType.toLowerCase() => mediaObject
            };

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + config.API_Key__c);
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(60000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
                throw new WhatsAppException('Failed to send media: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error sending WhatsApp media: ' + e.getMessage());
            throw new WhatsAppException('Error sending media: ' + e.getMessage());
        }
    }

    /**
     * @description Download media from WhatsApp
     * @param mediaId WhatsApp media ID
     * @return Blob Media file content
     */
    public static Blob downloadMedia(String mediaId) {
        try {
            WhatsApp_Configuration__c config = getActiveConfiguration();

            // First, get the media URL
            String endpoint = config.API_Base_URL__c + '/' + mediaId;

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + config.API_Key__c);
            req.setTimeout(60000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String mediaUrl = (String) responseMap.get('url');

                // Now download the actual media
                HttpRequest mediaReq = new HttpRequest();
                mediaReq.setEndpoint(mediaUrl);
                mediaReq.setMethod('GET');
                mediaReq.setHeader('Authorization', 'Bearer ' + config.API_Key__c);
                mediaReq.setTimeout(60000);

                HttpResponse mediaRes = http.send(mediaReq);

                if (mediaRes.getStatusCode() == 200) {
                    return mediaRes.getBodyAsBlob();
                }
            }

            throw new WhatsAppException('Failed to download media: ' + res.getBody());
        } catch (Exception e) {
            System.debug('Error downloading media: ' + e.getMessage());
            throw new WhatsAppException('Error downloading media: ' + e.getMessage());
        }
    }

    /**
     * @description Create outbound message record
     */
    private static void createOutboundMessageRecord(String messageId, String recipientPhone, String senderPhone, String content, String conversationId) {
        try {
            WhatsApp_Message__c message = new WhatsApp_Message__c(
                Message_ID__c = messageId,
                Conversation__c = conversationId,
                Direction__c = 'Outbound',
                Message_Type__c = 'Text',
                Content__c = content,
                Sender_Phone__c = senderPhone,
                Recipient_Phone__c = recipientPhone,
                Message_Status__c = 'Sent',
                Timestamp__c = System.now()
            );
            insert message;
        } catch (Exception e) {
            System.debug('Error creating outbound message record: ' + e.getMessage());
        }
    }

    /**
     * @description Custom exception class
     */
    public class WhatsAppException extends Exception {}
}
