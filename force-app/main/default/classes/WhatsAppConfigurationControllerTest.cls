@isTest
private class WhatsAppConfigurationControllerTest {

    private class MockHttpSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"123456789","display_phone_number":"+14155551234"}');
            return res;
        }
    }

    private class MockHttpFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setStatus('Unauthorized');
            res.setBody('{"error":{"message":"Invalid OAuth access token"}}');
            return res;
        }
    }

    @testSetup
    static void setupData() {
        WhatsApp_Configuration__c config = new WhatsApp_Configuration__c(
            API_Key__c = 'test-api-key-123',
            Phone_Number__c = '+14155551234',
            Phone_Number_ID__c = '123456789',
            API_Base_URL__c = 'https://graph.facebook.com',
            WhatsApp_API_Version__c = 'v21.0',
            Webhook_Verify_Token__c = 'my-verify-token',
            Is_Active__c = true,
            Session_Timeout_Minutes__c = 1440
        );
        insert config;
    }

    @isTest
    static void testGetConfigurationReturnsMaskedSecrets() {
        Test.startTest();
        Map<String, Object> result = WhatsAppConfigurationController.getConfiguration();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return a configuration map');
        // API key should be returned as actual value (LWC password input handles masking)
        String apiKeyValue = (String) result.get('API_Key__c');
        System.assertEquals('test-api-key-123', apiKeyValue, 'API key should be returned as actual value');
        // Webhook token should be returned as actual value
        String webhookTokenValue = (String) result.get('Webhook_Verify_Token__c');
        System.assertEquals('my-verify-token', webhookTokenValue, 'Webhook token should be returned as actual value');
        // Boolean flags
        System.assertEquals(true, result.get('hasApiKey'), 'hasApiKey should be true');
        System.assertEquals(true, result.get('hasWebhookToken'), 'hasWebhookToken should be true');
        // Regular fields should not be masked
        System.assertEquals('+14155551234', result.get('Phone_Number__c'), 'Phone number should not be masked');
    }

    @isTest
    static void testSaveConfigurationCreatesOrUpdates() {
        WhatsApp_Configuration__c existing = [SELECT Id FROM WhatsApp_Configuration__c LIMIT 1];

        Map<String, Object> configData = new Map<String, Object>{
            'Id' => existing.Id,
            'Phone_Number__c' => '+14155555678',
            'Phone_Number_ID__c' => '987654321',
            'API_Base_URL__c' => 'https://graph.facebook.com',
            'WhatsApp_API_Version__c' => 'v21.0',
            'API_Key__c' => 'new-api-key-456',
            'Session_Timeout_Minutes__c' => 720,
            'HMAC_Validation_Enabled__c' => true,
            'Auto_Download_Media__c' => false
        };

        Test.startTest();
        String configId = WhatsAppConfigurationController.saveConfiguration(configData);
        Test.stopTest();

        System.assertNotEquals(null, configId, 'Should return the configuration record Id');
        WhatsApp_Configuration__c updated = [SELECT Phone_Number__c, API_Key__c FROM WhatsApp_Configuration__c WHERE Id = :configId];
        System.assertEquals('+14155555678', updated.Phone_Number__c, 'Phone number should be updated');
        System.assertEquals('new-api-key-456', updated.API_Key__c, 'API key should be updated with new value');
    }

    @isTest
    static void testSaveConfigurationDoesNotOverwriteSecretsWhenMasked() {
        WhatsApp_Configuration__c existing = [SELECT Id FROM WhatsApp_Configuration__c LIMIT 1];

        Map<String, Object> configData = new Map<String, Object>{
            'Id' => existing.Id,
            'Phone_Number__c' => '+14155551234',
            'Phone_Number_ID__c' => '123456789',
            'API_Base_URL__c' => 'https://graph.facebook.com',
            'WhatsApp_API_Version__c' => 'v21.0',
            'API_Key__c' => '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
            'Webhook_Verify_Token__c' => '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
            'Session_Timeout_Minutes__c' => 1440,
            'HMAC_Validation_Enabled__c' => false,
            'Auto_Download_Media__c' => false
        };

        Test.startTest();
        String configId = WhatsAppConfigurationController.saveConfiguration(configData);
        Test.stopTest();

        WhatsApp_Configuration__c updated = [SELECT API_Key__c, Webhook_Verify_Token__c FROM WhatsApp_Configuration__c WHERE Id = :configId];
        System.assertEquals('test-api-key-123', updated.API_Key__c, 'API key should not be overwritten with mask value');
        System.assertEquals('my-verify-token', updated.Webhook_Verify_Token__c, 'Webhook token should not be overwritten with mask value');
    }

    @isTest
    static void testTestConnectionSuccess() {
        WhatsApp_Configuration__c existing = [SELECT Id FROM WhatsApp_Configuration__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        Map<String, Object> result = WhatsAppConfigurationController.testConnection(existing.Id);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Connection test should succeed');
    }

    @isTest
    static void testTestConnectionFailure() {
        WhatsApp_Configuration__c existing = [SELECT Id FROM WhatsApp_Configuration__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockHttpFailure());

        Test.startTest();
        Map<String, Object> result = WhatsAppConfigurationController.testConnection(existing.Id);
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Connection test should fail');
    }

    @isTest
    static void testGetWebhookUrl() {
        Test.startTest();
        String webhookUrl = WhatsAppConfigurationController.getWebhookUrl();
        Test.stopTest();

        System.assertNotEquals(null, webhookUrl, 'Webhook URL should not be null');
        System.assert(webhookUrl.contains('/services/apexrest/whatsapp/webhook'), 'Webhook URL should contain the correct path');
    }
}
