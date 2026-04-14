/**
 * @description Invocable action to retrieve the most recent location shared
 *              by a customer in a WhatsApp conversation. Returns coordinates,
 *              address, and a Google Maps link.
 */
public with sharing class WhatsAppGetLocationInfoAction {

    public class GetLocationInfoRequest {
        @InvocableVariable(required=true label='Conversation ID' description='The WhatsApp Conversation record ID')
        public String conversationId;
    }

    public class GetLocationInfoResult {
        @InvocableVariable public Boolean found;
        @InvocableVariable public Decimal latitude;
        @InvocableVariable public Decimal longitude;
        @InvocableVariable public String locationName;
        @InvocableVariable public String locationAddress;
        @InvocableVariable public String googleMapsUrl;
        @InvocableVariable public String formattedResponse;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Get WhatsApp Location Info'
                     description='Retrieves the most recent location shared by the customer in a conversation'
                     category='WhatsApp')
    public static List<GetLocationInfoResult> getLocationInfo(List<GetLocationInfoRequest> requests) {
        List<GetLocationInfoResult> results = new List<GetLocationInfoResult>();
        for (GetLocationInfoRequest req : requests) {
            GetLocationInfoResult result = new GetLocationInfoResult();
            try {
                if (String.isBlank(req.conversationId)) {
                    result.found = false;
                    result.errorMessage = 'Conversation ID is required.';
                    results.add(result);
                    continue;
                }

                List<WhatsApp_Message__c> locationMessages = [
                    SELECT Id, Latitude__c, Longitude__c, Location_Name__c,
                           Location_Address__c, Timestamp__c
                    FROM WhatsApp_Message__c
                    WHERE Conversation__c = :req.conversationId
                      AND Message_Type__c = :WhatsAppConstants.TYPE_LOCATION
                      AND Direction__c = :WhatsAppConstants.DIRECTION_INBOUND
                    ORDER BY CreatedDate DESC, Id DESC
                    LIMIT 1
                ];

                if (locationMessages.isEmpty()) {
                    result.found = false;
                    result.formattedResponse = 'No location has been shared in this conversation yet. Please ask the customer to share their location using WhatsApp\'s location sharing feature.';
                    results.add(result);
                    continue;
                }

                WhatsApp_Message__c locMsg = locationMessages[0];
                result.found = true;
                result.latitude = locMsg.Latitude__c;
                result.longitude = locMsg.Longitude__c;
                result.locationName = locMsg.Location_Name__c;
                result.locationAddress = locMsg.Location_Address__c;

                if (locMsg.Latitude__c != null && locMsg.Longitude__c != null) {
                    result.googleMapsUrl = 'https://www.google.com/maps?q='
                        + String.valueOf(locMsg.Latitude__c) + ','
                        + String.valueOf(locMsg.Longitude__c);
                }

                result.formattedResponse = buildFormattedResponse(locMsg);

            } catch (Exception e) {
                result.found = false;
                result.errorMessage = e.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    private static String buildFormattedResponse(WhatsApp_Message__c locMsg) {
        List<String> parts = new List<String>();

        if (String.isNotBlank(locMsg.Location_Name__c)) {
            parts.add('Location: ' + locMsg.Location_Name__c);
        }
        if (String.isNotBlank(locMsg.Location_Address__c)) {
            parts.add('Address: ' + locMsg.Location_Address__c);
        }
        if (locMsg.Latitude__c != null && locMsg.Longitude__c != null) {
            parts.add('Coordinates: ' + locMsg.Latitude__c + ', ' + locMsg.Longitude__c);
            parts.add('Google Maps: https://www.google.com/maps?q='
                + String.valueOf(locMsg.Latitude__c) + ','
                + String.valueOf(locMsg.Longitude__c));
        }

        if (parts.isEmpty()) {
            return 'Location was shared but no details were available.';
        }

        return String.join(parts, '\n');
    }
}
