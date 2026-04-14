@isTest
private class WhatsAppGetLocationInfoActionTest {

    @testSetup
    static void setupData() {
        WhatsApp_Configuration__c config = new WhatsApp_Configuration__c(
            API_Key__c = 'test-api-key-123',
            Phone_Number__c = '+14155551234',
            Phone_Number_ID__c = '123456789',
            API_Base_URL__c = 'https://graph.facebook.com',
            WhatsApp_API_Version__c = 'v21.0',
            Is_Active__c = true,
            Session_Timeout_Minutes__c = 1440
        );
        insert config;

        WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(
            Customer_Phone__c = '+14155559999',
            Customer_Name__c = 'Test Customer',
            Status__c = WhatsAppConstants.CONV_STATUS_ACTIVE,
            Session_Start_Time__c = Datetime.now(),
            Session_Expiry_Time__c = Datetime.now().addMinutes(1440),
            Unread_Count__c = 0,
            Message_Count__c = 0
        );
        insert conv;
    }

    @isTest
    static void testGetLocationInfo_Success() {
        WhatsApp_Conversation__c conv = [SELECT Id FROM WhatsApp_Conversation__c LIMIT 1];

        WhatsApp_Message__c msg = new WhatsApp_Message__c(
            Conversation__c = conv.Id,
            Message_Type__c = WhatsAppConstants.TYPE_LOCATION,
            Direction__c = WhatsAppConstants.DIRECTION_INBOUND,
            Latitude__c = -34.6037,
            Longitude__c = -58.3816,
            Location_Name__c = 'Obelisco',
            Location_Address__c = 'Av. 9 de Julio, Buenos Aires, Argentina',
            Sender_Phone__c = '+14155559999',
            Recipient_Phone__c = '+14155551234',
            Timestamp__c = Datetime.now()
        );
        insert msg;

        WhatsAppGetLocationInfoAction.GetLocationInfoRequest req = new WhatsAppGetLocationInfoAction.GetLocationInfoRequest();
        req.conversationId = conv.Id;

        Test.startTest();
        List<WhatsAppGetLocationInfoAction.GetLocationInfoResult> results =
            WhatsAppGetLocationInfoAction.getLocationInfo(
                new List<WhatsAppGetLocationInfoAction.GetLocationInfoRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        WhatsAppGetLocationInfoAction.GetLocationInfoResult result = results[0];
        System.assertEquals(true, result.found, 'Should find location');
        System.assertEquals(-34.6037, result.latitude, 'Latitude should match');
        System.assertEquals(-58.3816, result.longitude, 'Longitude should match');
        System.assertEquals('Obelisco', result.locationName, 'Location name should match');
        System.assertEquals('Av. 9 de Julio, Buenos Aires, Argentina', result.locationAddress, 'Address should match');
        System.assert(result.googleMapsUrl != null, 'Google Maps URL should be set');
        System.assert(result.googleMapsUrl.contains('-34.6037'), 'Google Maps URL should contain latitude');
        System.assert(result.formattedResponse.contains('Obelisco'), 'Formatted response should contain location name');
    }

    @isTest
    static void testGetLocationInfo_NoLocationFound() {
        WhatsApp_Conversation__c conv = [SELECT Id FROM WhatsApp_Conversation__c LIMIT 1];

        WhatsAppGetLocationInfoAction.GetLocationInfoRequest req = new WhatsAppGetLocationInfoAction.GetLocationInfoRequest();
        req.conversationId = conv.Id;

        Test.startTest();
        List<WhatsAppGetLocationInfoAction.GetLocationInfoResult> results =
            WhatsAppGetLocationInfoAction.getLocationInfo(
                new List<WhatsAppGetLocationInfoAction.GetLocationInfoRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        WhatsAppGetLocationInfoAction.GetLocationInfoResult result = results[0];
        System.assertEquals(false, result.found, 'Should not find location');
        System.assert(result.formattedResponse.contains('No location'), 'Should explain no location found');
    }

    @isTest
    static void testGetLocationInfo_NullConversationId() {
        WhatsAppGetLocationInfoAction.GetLocationInfoRequest req = new WhatsAppGetLocationInfoAction.GetLocationInfoRequest();
        req.conversationId = null;

        Test.startTest();
        List<WhatsAppGetLocationInfoAction.GetLocationInfoResult> results =
            WhatsAppGetLocationInfoAction.getLocationInfo(
                new List<WhatsAppGetLocationInfoAction.GetLocationInfoRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        WhatsAppGetLocationInfoAction.GetLocationInfoResult result = results[0];
        System.assertEquals(false, result.found, 'Should not find location');
        System.assertEquals('Conversation ID is required.', result.errorMessage, 'Error message should explain');
    }

    @isTest
    static void testGetLocationInfo_MultipleLocations_ReturnsMostRecent() {
        WhatsApp_Conversation__c conv = [SELECT Id FROM WhatsApp_Conversation__c LIMIT 1];

        // Older location
        WhatsApp_Message__c oldMsg = new WhatsApp_Message__c(
            Conversation__c = conv.Id,
            Message_Type__c = WhatsAppConstants.TYPE_LOCATION,
            Direction__c = WhatsAppConstants.DIRECTION_INBOUND,
            Latitude__c = 40.7128,
            Longitude__c = -74.0060,
            Location_Name__c = 'New York',
            Location_Address__c = 'New York, NY, USA',
            Sender_Phone__c = '+14155559999',
            Recipient_Phone__c = '+14155551234',
            Timestamp__c = Datetime.now().addHours(-2)
        );
        insert oldMsg;

        // Newer location
        WhatsApp_Message__c newMsg = new WhatsApp_Message__c(
            Conversation__c = conv.Id,
            Message_Type__c = WhatsAppConstants.TYPE_LOCATION,
            Direction__c = WhatsAppConstants.DIRECTION_INBOUND,
            Latitude__c = 48.8566,
            Longitude__c = 2.3522,
            Location_Name__c = 'Paris',
            Location_Address__c = 'Paris, France',
            Sender_Phone__c = '+14155559999',
            Recipient_Phone__c = '+14155551234',
            Timestamp__c = Datetime.now()
        );
        insert newMsg;

        WhatsAppGetLocationInfoAction.GetLocationInfoRequest req = new WhatsAppGetLocationInfoAction.GetLocationInfoRequest();
        req.conversationId = conv.Id;

        Test.startTest();
        List<WhatsAppGetLocationInfoAction.GetLocationInfoResult> results =
            WhatsAppGetLocationInfoAction.getLocationInfo(
                new List<WhatsAppGetLocationInfoAction.GetLocationInfoRequest>{ req }
            );
        Test.stopTest();

        WhatsAppGetLocationInfoAction.GetLocationInfoResult result = results[0];
        System.assertEquals(true, result.found, 'Should find location');
        System.assertEquals('Paris', result.locationName, 'Should return the most recent location');
        System.assertEquals(48.8566, result.latitude, 'Latitude should be from most recent');
    }

    @isTest
    static void testGetLocationInfo_OutboundLocationIgnored() {
        WhatsApp_Conversation__c conv = [SELECT Id FROM WhatsApp_Conversation__c LIMIT 1];

        // Outbound location (sent by agent, not customer)
        WhatsApp_Message__c outMsg = new WhatsApp_Message__c(
            Conversation__c = conv.Id,
            Message_Type__c = WhatsAppConstants.TYPE_LOCATION,
            Direction__c = WhatsAppConstants.DIRECTION_OUTBOUND,
            Latitude__c = 51.5074,
            Longitude__c = -0.1278,
            Location_Name__c = 'London',
            Location_Address__c = 'London, UK',
            Sender_Phone__c = '+14155551234',
            Recipient_Phone__c = '+14155559999',
            Timestamp__c = Datetime.now()
        );
        insert outMsg;

        WhatsAppGetLocationInfoAction.GetLocationInfoRequest req = new WhatsAppGetLocationInfoAction.GetLocationInfoRequest();
        req.conversationId = conv.Id;

        Test.startTest();
        List<WhatsAppGetLocationInfoAction.GetLocationInfoResult> results =
            WhatsAppGetLocationInfoAction.getLocationInfo(
                new List<WhatsAppGetLocationInfoAction.GetLocationInfoRequest>{ req }
            );
        Test.stopTest();

        WhatsAppGetLocationInfoAction.GetLocationInfoResult result = results[0];
        System.assertEquals(false, result.found, 'Should not find outbound locations');
    }
}
