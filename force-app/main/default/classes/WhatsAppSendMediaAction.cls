public with sharing class WhatsAppSendMediaAction {

    public class SendMediaRequest {
        @InvocableVariable(required=true label='Recipient Phone Number')
        public String recipientPhone;

        @InvocableVariable(required=true label='Media ID' description='WhatsApp media ID or URL')
        public String mediaId;

        @InvocableVariable(required=true label='Media Type' description='image, video, audio, or document')
        public String mediaType;

        @InvocableVariable(label='Caption')
        public String caption;

        @InvocableVariable(label='Conversation ID')
        public String conversationId;
    }

    public class SendMediaResult {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String messageId;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Send WhatsApp Media Message'
                     description='Sends a media file (image, video, audio, document)'
                     category='WhatsApp')
    public static List<SendMediaResult> sendMedia(List<SendMediaRequest> requests) {
        List<SendMediaResult> results = new List<SendMediaResult>();
        for (SendMediaRequest req : requests) {
            SendMediaResult result = new SendMediaResult();
            try {
                result.messageId = WhatsAppAPIService.sendMediaMessage(
                    req.recipientPhone, req.mediaId, req.mediaType, req.caption
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