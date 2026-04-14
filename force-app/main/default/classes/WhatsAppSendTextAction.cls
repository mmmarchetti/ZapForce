public with sharing class WhatsAppSendTextAction {

    public class SendTextRequest {
        @InvocableVariable(required=true label='Recipient Phone Number' description='WhatsApp phone number with country code')
        public String recipientPhone;

        @InvocableVariable(required=true label='Message Text' description='Text message content to send')
        public String messageText;

        @InvocableVariable(label='Conversation ID' description='WhatsApp Conversation record ID')
        public String conversationId;
    }

    public class SendTextResult {
        @InvocableVariable(label='Success' description='Whether the message was sent successfully')
        public Boolean success;

        @InvocableVariable(label='Message ID' description='WhatsApp message ID returned by API')
        public String messageId;

        @InvocableVariable(label='Error Message' description='Error details if sending failed')
        public String errorMessage;
    }

    @InvocableMethod(label='Send WhatsApp Text Message'
                     description='Sends a text message to a WhatsApp user'
                     category='WhatsApp')
    public static List<SendTextResult> sendText(List<SendTextRequest> requests) {
        List<SendTextResult> results = new List<SendTextResult>();
        for (SendTextRequest req : requests) {
            SendTextResult result = new SendTextResult();
            try {
                result.messageId = WhatsAppAPIService.sendTextMessage(req.recipientPhone, req.messageText);
                result.success = true;

                if (String.isNotBlank(req.conversationId) && String.isNotBlank(result.messageId)) {
                    WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();
                    WhatsAppMessageService.createOutboundMessage(
                        req.conversationId, req.recipientPhone, config.Phone_Number__c,
                        WhatsAppConstants.TYPE_TEXT, req.messageText, result.messageId
                    );
                }
            } catch (Exception e) {
                result.success = false;
                result.errorMessage = e.getMessage();
            }
            results.add(result);
        }
        return results;
    }
}