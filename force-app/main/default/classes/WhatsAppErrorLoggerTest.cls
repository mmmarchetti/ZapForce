@isTest
private class WhatsAppErrorLoggerTest {

    @isTest
    static void testLogErrorWithAllParameters() {
        Test.startTest();
        WhatsAppErrorLogger.logError(
            WhatsAppConstants.ERROR_API,
            '400',
            'Bad Request',
            '{"to":"5511999999999"}',
            '{"error":{"code":400}}',
            'WhatsAppAPIService.sendMessage line 42',
            null,
            null
        );
        Test.stopTest();

        List<WhatsApp_Error_Log__c> logs = [
            SELECT Error_Type__c, Error_Code__c, Error_Message__c,
                   Request_Payload__c, Response_Payload__c, Stack_Trace__c,
                   Related_Conversation__c, Related_Message__c
            FROM WhatsApp_Error_Log__c
        ];

        System.assertEquals(1, logs.size(), 'One error log record should be created');
        System.assertEquals(WhatsAppConstants.ERROR_API, logs[0].Error_Type__c);
        System.assertEquals('400', logs[0].Error_Code__c);
        System.assertEquals('Bad Request', logs[0].Error_Message__c);
        System.assertEquals('{"to":"5511999999999"}', logs[0].Request_Payload__c);
        System.assertEquals('{"error":{"code":400}}', logs[0].Response_Payload__c);
        System.assertEquals('WhatsAppAPIService.sendMessage line 42', logs[0].Stack_Trace__c);
        System.assertEquals(null, logs[0].Related_Conversation__c);
        System.assertEquals(null, logs[0].Related_Message__c);
    }

    @isTest
    static void testLogErrorWithExceptionOverload() {
        Exception testEx;
        try {
            Integer result = 1 / 0;
        } catch (Exception e) {
            testEx = e;
        }

        Test.startTest();
        WhatsAppErrorLogger.logError(
            WhatsAppConstants.ERROR_WEBHOOK,
            'Processing failed',
            testEx
        );
        Test.stopTest();

        List<WhatsApp_Error_Log__c> logs = [
            SELECT Error_Type__c, Error_Message__c, Stack_Trace__c
            FROM WhatsApp_Error_Log__c
        ];

        System.assertEquals(1, logs.size(), 'One error log record should be created');
        System.assertEquals(WhatsAppConstants.ERROR_WEBHOOK, logs[0].Error_Type__c);
        System.assert(logs[0].Error_Message__c.contains('Processing failed'),
            'Error message should contain the provided message');
        System.assertNotEquals(null, logs[0].Stack_Trace__c,
            'Stack trace should be populated from exception');
    }

    @isTest
    static void testLogApiError() {
        Test.startTest();
        WhatsAppErrorLogger.logApiError(
            '401',
            'Unauthorized',
            '{"request":"data"}',
            '{"error":"unauthorized"}'
        );
        Test.stopTest();

        List<WhatsApp_Error_Log__c> logs = [
            SELECT Error_Type__c, Error_Code__c, Error_Message__c,
                   Request_Payload__c, Response_Payload__c
            FROM WhatsApp_Error_Log__c
        ];

        System.assertEquals(1, logs.size());
        System.assertEquals(WhatsAppConstants.ERROR_API, logs[0].Error_Type__c);
        System.assertEquals('401', logs[0].Error_Code__c);
        System.assertEquals('Unauthorized', logs[0].Error_Message__c);
        System.assertEquals('{"request":"data"}', logs[0].Request_Payload__c);
        System.assertEquals('{"error":"unauthorized"}', logs[0].Response_Payload__c);
    }

    @isTest
    static void testLogWebhookError() {
        Exception testEx;
        try {
            String s = null;
            s.length();
        } catch (Exception e) {
            testEx = e;
        }

        Test.startTest();
        WhatsAppErrorLogger.logWebhookError(
            'Webhook parse failed',
            '{"invalid":"payload"}',
            testEx
        );
        Test.stopTest();

        List<WhatsApp_Error_Log__c> logs = [
            SELECT Error_Type__c, Error_Message__c, Request_Payload__c, Stack_Trace__c
            FROM WhatsApp_Error_Log__c
        ];

        System.assertEquals(1, logs.size());
        System.assertEquals(WhatsAppConstants.ERROR_WEBHOOK, logs[0].Error_Type__c);
        System.assert(logs[0].Error_Message__c.contains('Webhook parse failed'));
        System.assertEquals('{"invalid":"payload"}', logs[0].Request_Payload__c);
        System.assertNotEquals(null, logs[0].Stack_Trace__c);
    }

    @isTest
    static void testLogMediaError() {
        Exception testEx;
        try {
            Integer result = 1 / 0;
        } catch (Exception e) {
            testEx = e;
        }

        Test.startTest();
        WhatsAppErrorLogger.logMediaError(
            'Media download failed',
            null,
            testEx
        );
        Test.stopTest();

        List<WhatsApp_Error_Log__c> logs = [
            SELECT Error_Type__c, Error_Message__c, Stack_Trace__c
            FROM WhatsApp_Error_Log__c
        ];

        System.assertEquals(1, logs.size());
        System.assertEquals(WhatsAppConstants.ERROR_MEDIA, logs[0].Error_Type__c);
        System.assert(logs[0].Error_Message__c.contains('Media download failed'));
    }

    @isTest
    static void testLogAgentforceError() {
        Exception testEx;
        try {
            Integer result = 1 / 0;
        } catch (Exception e) {
            testEx = e;
        }

        Test.startTest();
        WhatsAppErrorLogger.logAgentforceError(
            'Agentforce timeout',
            null,
            testEx
        );
        Test.stopTest();

        List<WhatsApp_Error_Log__c> logs = [
            SELECT Error_Type__c, Error_Message__c, Stack_Trace__c
            FROM WhatsApp_Error_Log__c
        ];

        System.assertEquals(1, logs.size());
        System.assertEquals(WhatsAppConstants.ERROR_AGENTFORCE, logs[0].Error_Type__c);
        System.assert(logs[0].Error_Message__c.contains('Agentforce timeout'));
    }

    @isTest
    static void testLongStringsAreTruncated() {
        // Error_Code__c is truncated to 50, Error_Message__c to 500
        String longCode = 'A'.repeat(100);
        String longMessage = 'B'.repeat(1000);

        Test.startTest();
        WhatsAppErrorLogger.logError(
            WhatsAppConstants.ERROR_API,
            longCode,
            longMessage,
            null,
            null,
            null,
            null,
            null
        );
        Test.stopTest();

        List<WhatsApp_Error_Log__c> logs = [
            SELECT Error_Code__c, Error_Message__c
            FROM WhatsApp_Error_Log__c
        ];

        System.assertEquals(1, logs.size());
        System.assertEquals(50, logs[0].Error_Code__c.length(),
            'Error code should be truncated to 50 characters');
        System.assertEquals(500, logs[0].Error_Message__c.length(),
            'Error message should be truncated to 500 characters');
    }
}
