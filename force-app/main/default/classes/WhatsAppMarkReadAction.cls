public with sharing class WhatsAppMarkReadAction {

    public class MarkReadRequest {
        @InvocableVariable(required=true label='WhatsApp Message ID' description='The WhatsApp message ID to mark as read')
        public String messageId;
    }

    public class MarkReadResult {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Mark WhatsApp Message as Read'
                     description='Sends read receipt for a WhatsApp message'
                     category='WhatsApp')
    public static List<MarkReadResult> markRead(List<MarkReadRequest> requests) {
        List<MarkReadResult> results = new List<MarkReadResult>();
        for (MarkReadRequest req : requests) {
            MarkReadResult result = new MarkReadResult();
            try {
                result.success = WhatsAppAPIService.markAsRead(req.messageId);
            } catch (Exception e) {
                result.success = false;
                result.errorMessage = e.getMessage();
            }
            results.add(result);
        }
        return results;
    }
}
