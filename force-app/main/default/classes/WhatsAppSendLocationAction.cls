public with sharing class WhatsAppSendLocationAction {

    public class SendLocationRequest {
        @InvocableVariable(required=true label='Recipient Phone Number')
        public String recipientPhone;

        @InvocableVariable(required=true label='Latitude')
        public Double latitude;

        @InvocableVariable(required=true label='Longitude')
        public Double longitude;

        @InvocableVariable(label='Location Name')
        public String name;

        @InvocableVariable(label='Location Address')
        public String address;

        @InvocableVariable(label='Conversation ID')
        public String conversationId;
    }

    public class SendLocationResult {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String messageId;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Send WhatsApp Location'
                     description='Sends a location pin to a WhatsApp user'
                     category='WhatsApp')
    public static List<SendLocationResult> sendLocation(List<SendLocationRequest> requests) {
        List<SendLocationResult> results = new List<SendLocationResult>();
        for (SendLocationRequest req : requests) {
            SendLocationResult result = new SendLocationResult();
            try {
                result.messageId = WhatsAppAPIService.sendLocationMessage(
                    req.recipientPhone, req.latitude, req.longitude, req.name, req.address
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
