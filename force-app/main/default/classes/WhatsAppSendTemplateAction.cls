public with sharing class WhatsAppSendTemplateAction {

    public class SendTemplateRequest {
        @InvocableVariable(required=true label='Recipient Phone Number')
        public String recipientPhone;

        @InvocableVariable(required=true label='Template Name')
        public String templateName;

        @InvocableVariable(required=true label='Language Code' description='e.g. en_US, pt_BR')
        public String languageCode;

        @InvocableVariable(label='Template Variables JSON' description='JSON array of component parameter values')
        public String variablesJson;

        @InvocableVariable(label='Conversation ID')
        public String conversationId;
    }

    public class SendTemplateResult {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String messageId;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Send WhatsApp Template Message'
                     description='Sends a pre-approved template message'
                     category='WhatsApp')
    public static List<SendTemplateResult> sendTemplate(List<SendTemplateRequest> requests) {
        List<SendTemplateResult> results = new List<SendTemplateResult>();
        for (SendTemplateRequest req : requests) {
            SendTemplateResult result = new SendTemplateResult();
            try {
                List<Map<String, Object>> components = new List<Map<String, Object>>();
                if (String.isNotBlank(req.variablesJson)) {
                    components = (List<Map<String, Object>>) JSON.deserializeUntyped(req.variablesJson);
                }
                result.messageId = WhatsAppAPIService.sendTemplateMessage(
                    req.recipientPhone, req.templateName, req.languageCode, components
                );
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
