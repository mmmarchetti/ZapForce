/**
 * @description Service class for CRUD operations on WhatsApp_Message__c records.
 *              Handles creation of records for all WhatsApp message types (text, media,
 *              location, interactive, reaction, contacts, template) and status updates.
 */
public with sharing class WhatsAppMessageService {

    /**
     * @description Creates an inbound WhatsApp_Message__c record from a parsed webhook message.
     *              Handles all message types: text, image, video, audio, document, sticker,
     *              location, interactive, reaction, contacts, and template.
     * @param parsed The parsed message from the webhook
     * @param conversationId The related conversation record Id
     * @param businessPhone The business phone number that received the message
     * @return The inserted WhatsApp_Message__c record
     */
    public static WhatsApp_Message__c createInboundMessage(
        WhatsAppWebhookParser.ParsedMessage parsed,
        String conversationId,
        String businessPhone
    ) {
        WhatsApp_Message__c msg = new WhatsApp_Message__c();
        msg.Message_ID__c = parsed.id;
        msg.Conversation__c = conversationId;
        msg.Sender_Phone__c = parsed.from_field;
        msg.Recipient_Phone__c = businessPhone;
        msg.Direction__c = WhatsAppConstants.DIRECTION_INBOUND;
        msg.Message_Status__c = WhatsAppConstants.STATUS_RECEIVED;
        msg.Message_Type__c = parsed.type;
        msg.Raw_Payload_JSON__c = parsed.rawJson;

        // Timestamp from webhook (Unix epoch seconds)
        if (String.isNotBlank(parsed.timestamp)) {
            msg.Timestamp__c = Datetime.newInstance(Long.valueOf(parsed.timestamp) * 1000);
        } else {
            msg.Timestamp__c = Datetime.now();
        }

        // Context fields (reply threading / forwarding)
        if (parsed.context != null) {
            msg.Context_Message_ID__c = parsed.context.messageId;
            msg.Is_Forwarded__c = parsed.context.forwarded == true;
        } else {
            msg.Is_Forwarded__c = parsed.isForwarded == true;
        }

        // Type-specific content mapping
        if (parsed.type == WhatsAppConstants.TYPE_TEXT && parsed.text != null) {
            msg.Content__c = parsed.text.body;

        } else if (parsed.type == WhatsAppConstants.TYPE_LOCATION && parsed.location != null) {
            msg.Latitude__c = parsed.location.latitude;
            msg.Longitude__c = parsed.location.longitude;
            msg.Location_Name__c = parsed.location.name;
            msg.Location_Address__c = parsed.location.address;

        } else if (parsed.type == WhatsAppConstants.TYPE_IMAGE && parsed.image != null) {
            msg.Content__c = parsed.image.caption;

        } else if (parsed.type == WhatsAppConstants.TYPE_VIDEO && parsed.video != null) {
            msg.Content__c = parsed.video.caption;

        } else if (parsed.type == WhatsAppConstants.TYPE_AUDIO && parsed.audio != null) {
            msg.Content__c = parsed.audio.caption;

        } else if (parsed.type == WhatsAppConstants.TYPE_DOCUMENT && parsed.document != null) {
            msg.Content__c = parsed.document.caption;

        } else if (parsed.type == WhatsAppConstants.TYPE_STICKER && parsed.sticker != null) {
            msg.Content__c = parsed.sticker.caption;

        } else if (parsed.type == WhatsAppConstants.TYPE_INTERACTIVE && parsed.interactive != null) {
            msg.Interactive_Type__c = parsed.interactive.type;
            if (parsed.interactive.buttonReply != null) {
                msg.Interactive_Button_Text__c = parsed.interactive.buttonReply.title;
                msg.Content__c = parsed.interactive.buttonReply.title;
            } else if (parsed.interactive.listReply != null) {
                msg.Interactive_Button_Text__c = parsed.interactive.listReply.title;
                msg.Content__c = parsed.interactive.listReply.title;
            }

        } else if (parsed.type == WhatsAppConstants.TYPE_REACTION && parsed.reaction != null) {
            msg.Reaction_Emoji__c = parsed.reaction.emoji;
            msg.Context_Message_ID__c = parsed.reaction.messageId;

        } else if (parsed.type == WhatsAppConstants.TYPE_CONTACTS && parsed.contacts != null) {
            msg.Contact_Card_JSON__c = JSON.serialize(parsed.contacts);

        } else if (parsed.type == WhatsAppConstants.TYPE_TEMPLATE) {
            // Template name may be set externally; store type for reference
            msg.Template_Name__c = parsed.type;
        }

        try {
            insert msg;
        } catch (Exception ex) {
            WhatsAppErrorLogger.logError(
                WhatsAppConstants.ERROR_WEBHOOK,
                'Failed to create inbound message',
                ex
            );
            throw ex;
        }

        return msg;
    }

    /**
     * @description Creates an outbound WhatsApp_Message__c record.
     * @param conversationId The related conversation record Id
     * @param recipientPhone The recipient phone number
     * @param senderPhone The sender (business) phone number
     * @param messageType The message type (text, image, template, etc.)
     * @param content The message content
     * @param whatsappMessageId The WhatsApp message ID returned by the API
     * @return The inserted WhatsApp_Message__c record
     */
    public static WhatsApp_Message__c createOutboundMessage(
        String conversationId,
        String recipientPhone,
        String senderPhone,
        String messageType,
        String content,
        String whatsappMessageId
    ) {
        WhatsApp_Message__c msg = new WhatsApp_Message__c();
        msg.Conversation__c = conversationId;
        msg.Recipient_Phone__c = recipientPhone;
        msg.Sender_Phone__c = senderPhone;
        msg.Direction__c = WhatsAppConstants.DIRECTION_OUTBOUND;
        msg.Message_Status__c = WhatsAppConstants.STATUS_SENT;
        msg.Message_Type__c = messageType;
        msg.Content__c = content;
        msg.Message_ID__c = whatsappMessageId;
        msg.Timestamp__c = Datetime.now();

        try {
            insert msg;
        } catch (Exception ex) {
            WhatsAppErrorLogger.logError(
                WhatsAppConstants.ERROR_API,
                'Failed to create outbound message',
                ex
            );
            throw ex;
        }

        return msg;
    }

    /**
     * @description Updates the status of a message identified by its WhatsApp message ID.
     * @param whatsappMessageId The WhatsApp message ID (Message_ID__c)
     * @param status The new status value (use WhatsAppConstants status values)
     */
    public static void updateMessageStatus(String whatsappMessageId, String status) {
        if (String.isBlank(whatsappMessageId) || String.isBlank(status)) {
            return;
        }

        // Message_ID__c is a LongTextArea and cannot be used in SOQL WHERE filters.
        // We scan recent records and match in Apex to preserve behavior.
        List<WhatsApp_Message__c> recentMessages = [
            SELECT Id, Message_ID__c, Message_Status__c
            FROM WhatsApp_Message__c
            ORDER BY CreatedDate DESC
            LIMIT 2000
        ];

        WhatsApp_Message__c targetMessage;
        for (WhatsApp_Message__c record : recentMessages) {
            if (record.Message_ID__c == whatsappMessageId) {
                targetMessage = record;
                break;
            }
        }

        if (targetMessage != null) {
            targetMessage.Message_Status__c = status;
            try {
                update targetMessage;
            } catch (Exception ex) {
                WhatsAppErrorLogger.logError(
                    WhatsAppConstants.ERROR_WEBHOOK,
                    'Failed to update message status for ' + whatsappMessageId,
                    ex
                );
            }
        }
    }

    /**
     * @description Updates a message record with error information and sets status to Failed.
     * @param messageId The Salesforce record Id of the message
     * @param errorCode The error code
     * @param errorMessage The error message description
     */
    public static void updateMessageWithError(Id messageId, String errorCode, String errorMessage) {
        if (messageId == null) {
            return;
        }

        WhatsApp_Message__c msg = new WhatsApp_Message__c(Id = messageId);
        msg.Message_Status__c = WhatsAppConstants.STATUS_FAILED;
        msg.Error_Code__c = errorCode;
        msg.Error_Message__c = errorMessage;

        try {
            update msg;
        } catch (Exception ex) {
            WhatsAppErrorLogger.logError(
                WhatsAppConstants.ERROR_API,
                'Failed to update message with error for ' + messageId,
                ex
            );
        }
    }

    /**
     * @description Retrieves messages for a conversation ordered by timestamp ascending,
     *              including a subquery for related media records.
     * @param conversationId The conversation record Id
     * @param limitCount Maximum number of messages to return
     * @return List of WhatsApp_Message__c records with all display fields and media subquery
     */
    public static List<WhatsApp_Message__c> getConversationMessages(String conversationId, Integer limitCount) {
        if (String.isBlank(conversationId)) {
            return new List<WhatsApp_Message__c>();
        }

        return [
            SELECT Id,
                   Content__c,
                   Direction__c,
                   Message_Type__c,
                   Timestamp__c,
                   Message_Status__c,
                   Latitude__c,
                   Longitude__c,
                   Location_Name__c,
                   Location_Address__c,
                   Reaction_Emoji__c,
                   Interactive_Type__c,
                   Interactive_Button_Text__c,
                   Template_Name__c,
                   Contact_Card_JSON__c,
                   Is_Forwarded__c,
                   Is_From_Agentforce__c,
                   Context_Message_ID__c,
                   Error_Code__c,
                   Error_Message__c,
                   Message_ID__c,
                   Sender_Phone__c,
                   Recipient_Phone__c,
                   (SELECT Id,
                           Media_Type__c,
                           Media_ID__c,
                           Mime_Type__c,
                           File_Name__c,
                           File_Size__c,
                           ContentVersion_ID__c,
                           Download_Status__c
                    FROM WhatsApp_Media__r)
            FROM WhatsApp_Message__c
            WHERE Conversation__c = :conversationId
            ORDER BY Timestamp__c ASC
            LIMIT :limitCount
        ];
    }
}
