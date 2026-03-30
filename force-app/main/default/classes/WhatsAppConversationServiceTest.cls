@isTest
private class WhatsAppConversationServiceTest {

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
    }

    @isTest
    static void testFindOrCreateConversationCreatesNew() {
        Test.startTest();
        WhatsApp_Conversation__c conv = WhatsAppConversationService.findOrCreateConversation(
            '+14155559999', '+14155551234', 'John Doe'
        );
        Test.stopTest();

        System.assertNotEquals(null, conv.Id, 'Should create a new conversation');
        System.assertEquals('+14155559999', conv.Customer_Phone__c, 'Customer phone should match');
        System.assertEquals('John Doe', conv.Customer_Name__c, 'Customer name should match');
        System.assertEquals(WhatsAppConstants.CONV_STATUS_ACTIVE, conv.Status__c, 'Status should be Active');
    }

    @isTest
    static void testFindOrCreateConversationReturnsExisting() {
        // Create an open conversation first
        WhatsApp_Conversation__c existing = new WhatsApp_Conversation__c(
            Customer_Phone__c = '+14155559999',
            Customer_Name__c = 'John Doe',
            Status__c = WhatsAppConstants.CONV_STATUS_ACTIVE,
            Session_Start_Time__c = Datetime.now(),
            Session_Expiry_Time__c = Datetime.now().addMinutes(1440),
            Unread_Count__c = 0,
            Message_Count__c = 5
        );
        insert existing;

        Test.startTest();
        WhatsApp_Conversation__c result = WhatsAppConversationService.findOrCreateConversation(
            '+14155559999', '+14155551234', 'John Doe'
        );
        Test.stopTest();

        System.assertEquals(existing.Id, result.Id, 'Should return the existing conversation');
    }

    @isTest
    static void testFindOrCreateConversationClosesExpiredSession() {
        // Create an expired conversation
        WhatsApp_Conversation__c expired = new WhatsApp_Conversation__c(
            Customer_Phone__c = '+14155559999',
            Customer_Name__c = 'John Doe',
            Status__c = WhatsAppConstants.CONV_STATUS_ACTIVE,
            Session_Start_Time__c = Datetime.now().addDays(-2),
            Session_Expiry_Time__c = Datetime.now().addDays(-1),
            Unread_Count__c = 0,
            Message_Count__c = 5
        );
        insert expired;

        Test.startTest();
        WhatsApp_Conversation__c result = WhatsAppConversationService.findOrCreateConversation(
            '+14155559999', '+14155551234', 'John Doe'
        );
        Test.stopTest();

        System.assertNotEquals(expired.Id, result.Id, 'Should create a new conversation, not return the expired one');

        WhatsApp_Conversation__c closedConv = [SELECT Status__c FROM WhatsApp_Conversation__c WHERE Id = :expired.Id];
        System.assertEquals(WhatsAppConstants.CONV_STATUS_CLOSED, closedConv.Status__c, 'Expired conversation should be closed');
    }

    @isTest
    static void testUpdateConversationOnMessage() {
        WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(
            Customer_Phone__c = '+14155559999',
            Customer_Name__c = 'Test',
            Status__c = WhatsAppConstants.CONV_STATUS_ACTIVE,
            Session_Start_Time__c = Datetime.now(),
            Session_Expiry_Time__c = Datetime.now().addMinutes(1440),
            Unread_Count__c = 0,
            Message_Count__c = 0
        );
        insert conv;

        Test.startTest();
        WhatsAppConversationService.updateConversationOnMessage(conv.Id, true);
        Test.stopTest();

        WhatsApp_Conversation__c updated = [SELECT Message_Count__c, Unread_Count__c FROM WhatsApp_Conversation__c WHERE Id = :conv.Id];
        System.assertEquals(1, updated.Message_Count__c, 'Message count should be incremented');
        System.assertEquals(1, updated.Unread_Count__c, 'Unread count should be incremented for inbound');
    }

    @isTest
    static void testMarkConversationRead() {
        WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(
            Customer_Phone__c = '+14155559999',
            Customer_Name__c = 'Test',
            Status__c = WhatsAppConstants.CONV_STATUS_ACTIVE,
            Session_Start_Time__c = Datetime.now(),
            Session_Expiry_Time__c = Datetime.now().addMinutes(1440),
            Unread_Count__c = 5,
            Message_Count__c = 10
        );
        insert conv;

        Test.startTest();
        WhatsAppConversationService.markConversationRead(conv.Id);
        Test.stopTest();

        WhatsApp_Conversation__c updated = [SELECT Unread_Count__c FROM WhatsApp_Conversation__c WHERE Id = :conv.Id];
        System.assertEquals(0, updated.Unread_Count__c, 'Unread count should be reset to 0');
    }

    @isTest
    static void testIsSessionActiveTrue() {
        WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(
            Session_Expiry_Time__c = Datetime.now().addMinutes(60)
        );

        Test.startTest();
        Boolean result = WhatsAppConversationService.isSessionActive(conv);
        Test.stopTest();

        System.assertEquals(true, result, 'Session with future expiry should be active');
    }

    @isTest
    static void testIsSessionActiveFalseExpired() {
        WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(
            Session_Expiry_Time__c = Datetime.now().addMinutes(-60)
        );

        Test.startTest();
        Boolean result = WhatsAppConversationService.isSessionActive(conv);
        Test.stopTest();

        System.assertEquals(false, result, 'Session with past expiry should be inactive');
    }

    @isTest
    static void testCloseConversation() {
        WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(
            Customer_Phone__c = '+14155559999',
            Customer_Name__c = 'Test',
            Status__c = WhatsAppConstants.CONV_STATUS_ACTIVE,
            Session_Start_Time__c = Datetime.now(),
            Session_Expiry_Time__c = Datetime.now().addMinutes(1440),
            Unread_Count__c = 0,
            Message_Count__c = 0
        );
        insert conv;

        Test.startTest();
        WhatsAppConversationService.closeConversation(conv.Id);
        Test.stopTest();

        WhatsApp_Conversation__c updated = [SELECT Status__c FROM WhatsApp_Conversation__c WHERE Id = :conv.Id];
        System.assertEquals(WhatsAppConstants.CONV_STATUS_CLOSED, updated.Status__c, 'Status should be Closed');
    }

    @isTest
    static void testAssignToAgent() {
        WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(
            Customer_Phone__c = '+14155559999',
            Customer_Name__c = 'Test',
            Status__c = WhatsAppConstants.CONV_STATUS_ACTIVE,
            Session_Start_Time__c = Datetime.now(),
            Session_Expiry_Time__c = Datetime.now().addMinutes(1440),
            Unread_Count__c = 0,
            Message_Count__c = 0
        );
        insert conv;

        Id currentUserId = UserInfo.getUserId();

        Test.startTest();
        WhatsAppConversationService.assignToAgent(conv.Id, currentUserId);
        Test.stopTest();

        WhatsApp_Conversation__c updated = [SELECT Escalated_To_User__c FROM WhatsApp_Conversation__c WHERE Id = :conv.Id];
        System.assertEquals(currentUserId, updated.Escalated_To_User__c, 'Escalated_To_User__c should be set');
    }

    @isTest
    static void testGetActiveConversations() {
        WhatsApp_Conversation__c conv1 = new WhatsApp_Conversation__c(
            Customer_Phone__c = '+14155559999',
            Customer_Name__c = 'Active User',
            Status__c = WhatsAppConstants.CONV_STATUS_ACTIVE,
            Session_Start_Time__c = Datetime.now(),
            Session_Expiry_Time__c = Datetime.now().addMinutes(1440),
            Unread_Count__c = 0,
            Message_Count__c = 0,
            Last_Message_Time__c = Datetime.now()
        );
        WhatsApp_Conversation__c conv2 = new WhatsApp_Conversation__c(
            Customer_Phone__c = '+14155558888',
            Customer_Name__c = 'Closed User',
            Status__c = WhatsAppConstants.CONV_STATUS_CLOSED,
            Unread_Count__c = 0,
            Message_Count__c = 0
        );
        insert new List<WhatsApp_Conversation__c>{ conv1, conv2 };

        Test.startTest();
        List<WhatsApp_Conversation__c> active = WhatsAppConversationService.getActiveConversations(50);
        Test.stopTest();

        System.assertEquals(1, active.size(), 'Should return only active conversations, not closed');
        System.assertEquals('Active User', active[0].Customer_Name__c, 'Should return the active conversation');
    }
}
