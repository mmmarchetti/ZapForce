@isTest
private class WhatsAppMessageServiceTest {

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

    private static WhatsApp_Conversation__c getConversation() {
        return [SELECT Id FROM WhatsApp_Conversation__c LIMIT 1];
    }

    @isTest
    static void testCreateInboundTextMessage() {
        WhatsApp_Conversation__c conv = getConversation();

        WhatsAppWebhookParser.ParsedMessage parsed = new WhatsAppWebhookParser.ParsedMessage();
        parsed.id = 'wamid.inbound123';
        parsed.from_field = '+14155559999';
        parsed.timestamp = String.valueOf(Datetime.now().getTime() / 1000);
        parsed.type = WhatsAppConstants.TYPE_TEXT;
        parsed.text = new WhatsAppWebhookParser.TextContent();
        parsed.text.body = 'Hello from customer';
        parsed.isForwarded = false;

        Test.startTest();
        WhatsApp_Message__c msg = WhatsAppMessageService.createInboundMessage(parsed, conv.Id, '+14155551234');
        Test.stopTest();

        System.assertNotEquals(null, msg.Id, 'Message record should be inserted');
        System.assertEquals('wamid.inbound123', msg.Message_ID__c, 'Message ID should match');
        System.assertEquals(WhatsAppConstants.DIRECTION_INBOUND, msg.Direction__c, 'Direction should be Inbound');
        System.assertEquals(WhatsAppConstants.STATUS_RECEIVED, msg.Message_Status__c, 'Status should be Received');
        System.assertEquals('Hello from customer', msg.Content__c, 'Content should match text body');
    }

    @isTest
    static void testCreateInboundLocationMessage() {
        WhatsApp_Conversation__c conv = getConversation();

        WhatsAppWebhookParser.ParsedMessage parsed = new WhatsAppWebhookParser.ParsedMessage();
        parsed.id = 'wamid.loc123';
        parsed.from_field = '+14155559999';
        parsed.timestamp = String.valueOf(Datetime.now().getTime() / 1000);
        parsed.type = WhatsAppConstants.TYPE_LOCATION;
        parsed.location = new WhatsAppWebhookParser.LocationContent();
        parsed.location.latitude = 37.7749;
        parsed.location.longitude = -122.4194;
        parsed.location.name = 'San Francisco';
        parsed.location.address = '123 Main St';
        parsed.isForwarded = false;

        Test.startTest();
        WhatsApp_Message__c msg = WhatsAppMessageService.createInboundMessage(parsed, conv.Id, '+14155551234');
        Test.stopTest();

        System.assertEquals(37.7749, msg.Latitude__c, 'Latitude should be set');
        System.assertEquals(-122.4194, msg.Longitude__c, 'Longitude should be set');
        System.assertEquals('San Francisco', msg.Location_Name__c, 'Location name should be set');
        System.assertEquals('123 Main St', msg.Location_Address__c, 'Location address should be set');
    }

    @isTest
    static void testCreateInboundReactionMessage() {
        WhatsApp_Conversation__c conv = getConversation();

        WhatsAppWebhookParser.ParsedMessage parsed = new WhatsAppWebhookParser.ParsedMessage();
        parsed.id = 'wamid.react123';
        parsed.from_field = '+14155559999';
        parsed.timestamp = String.valueOf(Datetime.now().getTime() / 1000);
        parsed.type = WhatsAppConstants.TYPE_REACTION;
        parsed.reaction = new WhatsAppWebhookParser.ReactionContent();
        parsed.reaction.emoji = '\uD83D\uDC4D';
        parsed.reaction.messageId = 'wamid.original456';
        parsed.isForwarded = false;

        Test.startTest();
        WhatsApp_Message__c msg = WhatsAppMessageService.createInboundMessage(parsed, conv.Id, '+14155551234');
        Test.stopTest();

        System.assertEquals('\uD83D\uDC4D', msg.Reaction_Emoji__c, 'Reaction emoji should be set');
        System.assertEquals('wamid.original456', msg.Context_Message_ID__c, 'Context message ID should reference the reacted-to message');
    }

    @isTest
    static void testCreateOutboundMessage() {
        WhatsApp_Conversation__c conv = getConversation();

        Test.startTest();
        WhatsApp_Message__c msg = WhatsAppMessageService.createOutboundMessage(
            conv.Id, '+14155559999', '+14155551234',
            WhatsAppConstants.TYPE_TEXT, 'Hello customer', 'wamid.out123'
        );
        Test.stopTest();

        System.assertNotEquals(null, msg.Id, 'Outbound message record should be inserted');
        System.assertEquals(WhatsAppConstants.DIRECTION_OUTBOUND, msg.Direction__c, 'Direction should be Outbound');
        System.assertEquals(WhatsAppConstants.STATUS_SENT, msg.Message_Status__c, 'Status should be Sent');
        System.assertEquals('Hello customer', msg.Content__c, 'Content should match');
        System.assertEquals('wamid.out123', msg.Message_ID__c, 'WhatsApp message ID should be set');
    }

    @isTest
    static void testUpdateMessageStatus() {
        WhatsApp_Conversation__c conv = getConversation();
        WhatsApp_Message__c msg = WhatsAppMessageService.createOutboundMessage(
            conv.Id, '+14155559999', '+14155551234',
            WhatsAppConstants.TYPE_TEXT, 'Test', 'wamid.status123'
        );

        Test.startTest();
        WhatsAppMessageService.updateMessageStatus('wamid.status123', WhatsAppConstants.STATUS_DELIVERED);
        Test.stopTest();

        WhatsApp_Message__c updated = [SELECT Message_Status__c FROM WhatsApp_Message__c WHERE Id = :msg.Id];
        System.assertEquals(WhatsAppConstants.STATUS_DELIVERED, updated.Message_Status__c, 'Status should be updated to Delivered');
    }

    @isTest
    static void testUpdateMessageWithError() {
        WhatsApp_Conversation__c conv = getConversation();
        WhatsApp_Message__c msg = WhatsAppMessageService.createOutboundMessage(
            conv.Id, '+14155559999', '+14155551234',
            WhatsAppConstants.TYPE_TEXT, 'Test', 'wamid.err123'
        );

        Test.startTest();
        WhatsAppMessageService.updateMessageWithError(msg.Id, '131047', 'Rate limit exceeded');
        Test.stopTest();

        WhatsApp_Message__c updated = [SELECT Message_Status__c, Error_Code__c, Error_Message__c FROM WhatsApp_Message__c WHERE Id = :msg.Id];
        System.assertEquals(WhatsAppConstants.STATUS_FAILED, updated.Message_Status__c, 'Status should be Failed');
        System.assertEquals('131047', updated.Error_Code__c, 'Error code should be set');
        System.assertEquals('Rate limit exceeded', updated.Error_Message__c, 'Error message should be set');
    }

    @isTest
    static void testGetConversationMessages() {
        WhatsApp_Conversation__c conv = getConversation();

        // Create a few messages
        WhatsAppMessageService.createOutboundMessage(
            conv.Id, '+14155559999', '+14155551234',
            WhatsAppConstants.TYPE_TEXT, 'Message 1', 'wamid.m1'
        );
        WhatsAppMessageService.createOutboundMessage(
            conv.Id, '+14155559999', '+14155551234',
            WhatsAppConstants.TYPE_TEXT, 'Message 2', 'wamid.m2'
        );

        Test.startTest();
        List<WhatsApp_Message__c> messages = WhatsAppMessageService.getConversationMessages(conv.Id, 50);
        Test.stopTest();

        System.assertEquals(2, messages.size(), 'Should return 2 messages');
    }
}