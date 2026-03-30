public class WhatsAppSendMessageQueueable implements Queueable, Database.AllowsCallouts {

    private String recipientPhone;
    private String messageType;
    private String content;
    private String conversationId;
    private Map<String, Object> additionalParams;

    public WhatsAppSendMessageQueueable(String recipientPhone, String messageType, String content, String conversationId) {
        this.recipientPhone = recipientPhone;
        this.messageType = messageType;
        this.content = content;
        this.conversationId = conversationId;
        this.additionalParams = new Map<String, Object>();
    }

    public WhatsAppSendMessageQueueable(String recipientPhone, String messageType, String content, String conversationId, Map<String, Object> additionalParams) {
        this(recipientPhone, messageType, content, conversationId);
        this.additionalParams = additionalParams != null ? additionalParams : new Map<String, Object>();
    }

    public void execute(QueueableContext context) {
        try {
            String messageId;
            WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();
            String senderPhone = config.Phone_Number__c;

            if (messageType == WhatsAppConstants.TYPE_TEXT) {
                messageId = WhatsAppAPIService.sendTextMessage(recipientPhone, content);
            } else if (messageType == WhatsAppConstants.TYPE_IMAGE || messageType == WhatsAppConstants.TYPE_VIDEO ||
                       messageType == WhatsAppConstants.TYPE_AUDIO || messageType == WhatsAppConstants.TYPE_DOCUMENT) {
                String mediaId = (String) additionalParams.get('mediaId');
                messageId = WhatsAppAPIService.sendMediaMessage(recipientPhone, mediaId, messageType, content);
            } else if (messageType == WhatsAppConstants.TYPE_LOCATION) {
                Double lat = (Double) additionalParams.get('latitude');
                Double lng = (Double) additionalParams.get('longitude');
                String name = (String) additionalParams.get('name');
                String address = (String) additionalParams.get('address');
                messageId = WhatsAppAPIService.sendLocationMessage(recipientPhone, lat, lng, name, address);
            } else if (messageType == WhatsAppConstants.TYPE_TEMPLATE) {
                String templateName = (String) additionalParams.get('templateName');
                String languageCode = (String) additionalParams.get('languageCode');
                List<Map<String, Object>> components = (List<Map<String, Object>>) additionalParams.get('components');
                messageId = WhatsAppAPIService.sendTemplateMessage(recipientPhone, templateName, languageCode, components);
            } else if (messageType == WhatsAppConstants.TYPE_INTERACTIVE) {
                Map<String, Object> interactivePayload = (Map<String, Object>) additionalParams.get('interactive');
                messageId = WhatsAppAPIService.sendInteractiveMessage(recipientPhone, interactivePayload);
            } else if (messageType == WhatsAppConstants.TYPE_REACTION) {
                String targetMsgId = (String) additionalParams.get('targetMessageId');
                String emoji = (String) additionalParams.get('emoji');
                messageId = WhatsAppAPIService.sendReactionMessage(recipientPhone, targetMsgId, emoji);
            } else if (messageType == WhatsAppConstants.TYPE_STICKER) {
                String stickerId = (String) additionalParams.get('stickerId');
                messageId = WhatsAppAPIService.sendStickerMessage(recipientPhone, stickerId);
            } else if (messageType == WhatsAppConstants.TYPE_CONTACTS) {
                String contactJson = (String) additionalParams.get('contactJson');
                messageId = WhatsAppAPIService.sendContactMessage(recipientPhone, contactJson);
            }

            // Create outbound message record
            if (String.isNotBlank(messageId) && String.isNotBlank(conversationId)) {
                WhatsAppMessageService.createOutboundMessage(
                    conversationId, recipientPhone, senderPhone, messageType, content, messageId
                );
                WhatsAppConversationService.updateConversationOnMessage(conversationId, false);
            }
        } catch (Exception e) {
            WhatsAppErrorLogger.logError(WhatsAppConstants.ERROR_API, 'Failed to send ' + messageType + ' message', e);
        }
    }
}
