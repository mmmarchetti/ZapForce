public with sharing class WhatsAppSendInteractiveAction {

    public class SendInteractiveRequest {
        @InvocableVariable(required=true label='Recipient Phone Number')
        public String recipientPhone;

        @InvocableVariable(required=true label='Interactive Payload JSON' description='Full interactive message payload as JSON')
        public String interactivePayloadJson;

        @InvocableVariable(label='Conversation ID')
        public String conversationId;
    }

    public class SendInteractiveResult {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String messageId;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Send WhatsApp Interactive Message'
                     description='Sends buttons or list messages to a WhatsApp user'
                     category='WhatsApp')
    public static List<SendInteractiveResult> sendInteractive(List<SendInteractiveRequest> requests) {
        List<SendInteractiveResult> results = new List<SendInteractiveResult>();
        for (SendInteractiveRequest req : requests) {
            SendInteractiveResult result = new SendInteractiveResult();
            try {
                Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(req.interactivePayloadJson);
                result.messageId = WhatsAppAPIService.sendInteractiveMessage(req.recipientPhone, payload);
                result.success = true;
            } catch (Exception e) {
                result.success = false;
                result.errorMessage = e.getMessage();
            }
            results.add(result);
        }
        return results;
    }
}
