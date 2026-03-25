/**
 * @description REST endpoint for receiving WhatsApp webhooks
 * URL: /services/apexrest/whatsapp/webhook
 */
@RestResource(urlMapping='/whatsapp/webhook/*')
global with sharing class WhatsAppWebhookHandler {

    /**
     * @description Handle webhook verification (GET request)
     * WhatsApp sends this during initial setup
     */
    @HttpGet
    global static String handleVerification() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String mode = req.params.get('hub.mode');
        String token = req.params.get('hub.verify_token');
        String challenge = req.params.get('hub.challenge');

        if (mode == 'subscribe') {
            WhatsApp_Configuration__c config = getActiveConfiguration();

            if (config != null && token == config.Webhook_Verify_Token__c) {
                res.statusCode = 200;
                return challenge;
            }
        }

        res.statusCode = 403;
        return 'Forbidden';
    }

    /**
     * @description Handle incoming webhook messages (POST request)
     */
    @HttpPost
    global static void handleIncomingMessage() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String requestBody = req.requestBody.toString();
            System.debug('Webhook payload: ' + requestBody);

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(requestBody);

            // Parse WhatsApp webhook structure
            List<Object> entries = (List<Object>) payload.get('entry');

            if (entries != null && !entries.isEmpty()) {
                for (Object entryObj : entries) {
                    Map<String, Object> entry = (Map<String, Object>) entryObj;
                    List<Object> changes = (List<Object>) entry.get('changes');

                    if (changes != null) {
                        for (Object changeObj : changes) {
                            Map<String, Object> change = (Map<String, Object>) changeObj;
                            Map<String, Object> value = (Map<String, Object>) change.get('value');

                            if (value != null) {
                                // Process messages
                                List<Object> messages = (List<Object>) value.get('messages');
                                if (messages != null) {
                                    for (Object msgObj : messages) {
                                        Map<String, Object> message = (Map<String, Object>) msgObj;
                                        processIncomingMessage(message);
                                    }
                                }

                                // Process message status updates
                                List<Object> statuses = (List<Object>) value.get('statuses');
                                if (statuses != null) {
                                    for (Object statusObj : statuses) {
                                        Map<String, Object> status = (Map<String, Object>) statusObj;
                                        processMessageStatus(status);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"status":"success"}');
        } catch (Exception e) {
            System.debug('Error processing webhook: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"status":"error","message":"' + e.getMessage() + '"}');
        }
    }

    /**
     * @description Process incoming message from webhook
     */
    private static void processIncomingMessage(Map<String, Object> message) {
        try {
            String messageId = (String) message.get('id');
            String fromPhone = (String) message.get('from');
            String timestamp = (String) message.get('timestamp');
            String messageType = (String) message.get('type');

            WhatsApp_Configuration__c config = getActiveConfiguration();
            String businessPhone = config.Phone_Number__c;

            // Find or create conversation
            String conversationId = findOrCreateConversation(fromPhone, businessPhone);

            // Create message record
            WhatsApp_Message__c msg = new WhatsApp_Message__c(
                Message_ID__c = messageId,
                Conversation__c = conversationId,
                Direction__c = 'Inbound',
                Message_Type__c = capitalizeFirstLetter(messageType),
                Sender_Phone__c = fromPhone,
                Recipient_Phone__c = businessPhone,
                Message_Status__c = 'Received',
                Timestamp__c = convertTimestampToDateTime(timestamp)
            );

            // Extract message content based on type
            if (messageType == 'text') {
                Map<String, Object> textObj = (Map<String, Object>) message.get('text');
                if (textObj != null) {
                    msg.Content__c = (String) textObj.get('body');
                }
            } else if (messageType == 'location') {
                Map<String, Object> locationObj = (Map<String, Object>) message.get('location');
                if (locationObj != null) {
                    msg.Latitude__c = (Decimal) locationObj.get('latitude');
                    msg.Longitude__c = (Decimal) locationObj.get('longitude');
                    String locationName = (String) locationObj.get('name');
                    String locationAddress = (String) locationObj.get('address');
                    msg.Content__c = 'Location: ' + (locationName != null ? locationName : '') +
                                    (locationAddress != null ? ' - ' + locationAddress : '');
                }
            } else if (messageType == 'image' || messageType == 'video' ||
                      messageType == 'audio' || messageType == 'document') {
                Map<String, Object> mediaObj = (Map<String, Object>) message.get(messageType);
                if (mediaObj != null) {
                    String mediaId = (String) mediaObj.get('id');
                    String caption = (String) mediaObj.get('caption');
                    msg.Content__c = caption != null ? caption : 'Media file received';

                    // Create media record (will be downloaded asynchronously)
                    insert msg;
                    createMediaRecord(msg.Id, mediaId, messageType, mediaObj);
                    return;
                }
            }

            insert msg;

            // Update conversation
            updateConversation(conversationId);

            // Route to Agentforce
            routeToAgentforce(conversationId, msg.Id);

        } catch (Exception e) {
            System.debug('Error processing incoming message: ' + e.getMessage());
            throw e;
        }
    }

    /**
     * @description Process message status updates
     */
    private static void processMessageStatus(Map<String, Object> status) {
        try {
            String messageId = (String) status.get('id');
            String statusValue = (String) status.get('status');

            List<WhatsApp_Message__c> messages = [
                SELECT Id, Message_Status__c
                FROM WhatsApp_Message__c
                WHERE Message_ID__c = :messageId
                LIMIT 1
            ];

            if (!messages.isEmpty()) {
                WhatsApp_Message__c msg = messages[0];
                msg.Message_Status__c = capitalizeFirstLetter(statusValue);
                update msg;
            }
        } catch (Exception e) {
            System.debug('Error updating message status: ' + e.getMessage());
        }
    }

    /**
     * @description Find or create conversation record
     */
    private static String findOrCreateConversation(String customerPhone, String businessPhone) {
        List<WhatsApp_Conversation__c> conversations = [
            SELECT Id
            FROM WhatsApp_Conversation__c
            WHERE Customer_Phone__c = :customerPhone
            AND Status__c != 'Closed'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!conversations.isEmpty()) {
            return conversations[0].Id;
        }

        // Create new conversation
        WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(
            Customer_Phone__c = customerPhone,
            Status__c = 'Active',
            Last_Message_Time__c = System.now(),
            Message_Count__c = 0
        );
        insert conv;

        return conv.Id;
    }

    /**
     * @description Update conversation metadata
     */
    private static void updateConversation(String conversationId) {
        WhatsApp_Conversation__c conv = [
            SELECT Id, Message_Count__c
            FROM WhatsApp_Conversation__c
            WHERE Id = :conversationId
        ];

        conv.Last_Message_Time__c = System.now();
        conv.Message_Count__c = conv.Message_Count__c != null ? conv.Message_Count__c + 1 : 1;
        conv.Status__c = 'Active';
        update conv;
    }

    /**
     * @description Create media record for async download
     */
    private static void createMediaRecord(String messageId, String mediaId, String mediaType, Map<String, Object> mediaObj) {
        try {
            WhatsApp_Media__c media = new WhatsApp_Media__c(
                Message__c = messageId,
                Media_ID__c = mediaId,
                Media_Type__c = capitalizeFirstLetter(mediaType),
                MIME_Type__c = (String) mediaObj.get('mime_type'),
                File_Name__c = (String) mediaObj.get('filename'),
                Download_Status__c = 'Pending'
            );
            insert media;

            // Trigger async download
            WhatsAppMediaHandler.downloadMediaAsync(media.Id);
        } catch (Exception e) {
            System.debug('Error creating media record: ' + e.getMessage());
        }
    }

    /**
     * @description Route message to Agentforce
     */
    private static void routeToAgentforce(String conversationId, String messageId) {
        // Queue for Agentforce processing
        if (!System.isFuture() && !System.isBatch()) {
            WhatsAppAgentforceHandler.processMessageAsync(conversationId, messageId);
        }
    }

    /**
     * @description Get active configuration
     */
    private static WhatsApp_Configuration__c getActiveConfiguration() {
        List<WhatsApp_Configuration__c> configs = [
            SELECT Id, Phone_Number__c, Webhook_Verify_Token__c
            FROM WhatsApp_Configuration__c
            WHERE Is_Active__c = true
            LIMIT 1
        ];

        return configs.isEmpty() ? null : configs[0];
    }

    /**
     * @description Convert Unix timestamp to DateTime
     */
    private static DateTime convertTimestampToDateTime(String timestamp) {
        Long unixTime = Long.valueOf(timestamp);
        return DateTime.newInstance(unixTime * 1000);
    }

    /**
     * @description Capitalize first letter of string
     */
    private static String capitalizeFirstLetter(String str) {
        if (String.isBlank(str)) return str;
        return str.substring(0, 1).toUpperCase() + str.substring(1).toLowerCase();
    }
}
