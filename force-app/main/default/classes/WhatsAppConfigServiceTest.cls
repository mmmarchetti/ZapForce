@isTest
private class WhatsAppConfigServiceTest {

    @testSetup
    static void setupTestData() {
        WhatsApp_Configuration__c config = new WhatsApp_Configuration__c(
            API_Key__c = 'test-api-key-12345',
            Phone_Number__c = '+15551234567',
            API_Base_URL__c = 'https://graph.facebook.com',
            Webhook_URL__c = 'https://example.com/webhook',
            Webhook_Verify_Token__c = 'verify-token-abc',
            Business_Account_ID__c = 'BA123456',
            Is_Active__c = true,
            Phone_Number_ID__c = '999888777',
            Display_Phone_Number__c = '15551234567',
            WhatsApp_API_Version__c = 'v21.0',
            Agentforce_Agent_Id__c = 'agent-001',
            Session_Timeout_Minutes__c = 60,
            HMAC_Validation_Enabled__c = true,
            Auto_Download_Media__c = true
        );
        insert config;
    }

    @isTest
    static void testGetActiveConfigurationReturnsConfig() {
        Test.startTest();
        WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();
        Test.stopTest();

        System.assertNotEquals(null, config, 'Configuration should not be null');
        System.assertEquals(true, config.Is_Active__c);
        System.assertEquals('999888777', config.Phone_Number_ID__c);
    }

    @isTest
    static void testGetActiveConfigurationCachesResult() {
        Test.startTest();
        WhatsApp_Configuration__c config1 = WhatsAppConfigService.getActiveConfiguration();
        WhatsApp_Configuration__c config2 = WhatsAppConfigService.getActiveConfiguration();
        Test.stopTest();

        System.assert(config1 === config2,
            'Second call should return the exact same cached object reference');
    }

    @isTest
    static void testClearCacheForcesFreshQuery() {
        Test.startTest();
        WhatsApp_Configuration__c config1 = WhatsAppConfigService.getActiveConfiguration();
        WhatsAppConfigService.clearCache();
        WhatsApp_Configuration__c config2 = WhatsAppConfigService.getActiveConfiguration();
        Test.stopTest();

        System.assertNotEquals(null, config2, 'Should return a config after cache clear');
        System.assertEquals(config1.Id, config2.Id, 'Should return the same record');
    }

    @isTest
    static void testGetApiVersionReturnsConfigValue() {
        Test.startTest();
        String apiVersion = WhatsAppConfigService.getApiVersion();
        Test.stopTest();

        System.assertEquals('v21.0', apiVersion,
            'Should return the API version from configuration');
    }

    @isTest
    static void testGetApiVersionReturnsDefaultWhenBlank() {
        WhatsApp_Configuration__c config = [
            SELECT Id FROM WhatsApp_Configuration__c LIMIT 1
        ];
        config.WhatsApp_API_Version__c = null;
        update config;
        WhatsAppConfigService.clearCache();

        Test.startTest();
        String apiVersion = WhatsAppConfigService.getApiVersion();
        Test.stopTest();

        System.assertEquals(WhatsAppConstants.API_VERSION, apiVersion,
            'Should return the default API version when config value is blank');
    }

    @isTest
    static void testGetMessagesEndpointBuildsCorrectUrl() {
        Test.startTest();
        String endpoint = WhatsAppConfigService.getMessagesEndpoint();
        Test.stopTest();

        System.assertEquals(
            'https://graph.facebook.com/v21.0/999888777/messages',
            endpoint,
            'Messages endpoint URL should be correctly constructed'
        );
    }

    @isTest
    static void testGetMediaEndpointBuildsCorrectUrl() {
        Test.startTest();
        String endpoint = WhatsAppConfigService.getMediaEndpoint();
        Test.stopTest();

        System.assertEquals(
            'https://graph.facebook.com/v21.0/999888777/media',
            endpoint,
            'Media endpoint URL should be correctly constructed'
        );
    }

    @isTest
    static void testGetMediaUrlEndpointBuildsCorrectUrl() {
        Test.startTest();
        String endpoint = WhatsAppConfigService.getMediaUrlEndpoint('media-id-xyz');
        Test.stopTest();

        System.assertEquals(
            'https://graph.facebook.com/v21.0/media-id-xyz',
            endpoint,
            'Media URL endpoint should include the media ID'
        );
    }

    @isTest
    static void testGetSessionTimeoutMinutesReturnsConfigValue() {
        Test.startTest();
        Integer timeout = WhatsAppConfigService.getSessionTimeoutMinutes();
        Test.stopTest();

        System.assertEquals(60, timeout,
            'Should return the session timeout from configuration');
    }

    @isTest
    static void testGetSessionTimeoutMinutesReturnsDefaultWhenNull() {
        WhatsApp_Configuration__c config = [
            SELECT Id FROM WhatsApp_Configuration__c LIMIT 1
        ];
        config.Session_Timeout_Minutes__c = null;
        update config;
        WhatsAppConfigService.clearCache();

        Test.startTest();
        Integer timeout = WhatsAppConfigService.getSessionTimeoutMinutes();
        Test.stopTest();

        System.assertEquals(1440, timeout,
            'Should return default 1440 when config value is null');
    }

    @isTest
    static void testIsHmacValidationEnabledReturnsConfigValue() {
        Test.startTest();
        Boolean enabled = WhatsAppConfigService.isHmacValidationEnabled();
        Test.stopTest();

        System.assertEquals(true, enabled,
            'Should return HMAC validation setting from configuration');
    }

    @isTest
    static void testIsHmacValidationEnabledReturnsFalseWhenDisabled() {
        WhatsApp_Configuration__c config = [
            SELECT Id FROM WhatsApp_Configuration__c LIMIT 1
        ];
        config.HMAC_Validation_Enabled__c = false;
        update config;
        WhatsAppConfigService.clearCache();

        Test.startTest();
        Boolean enabled = WhatsAppConfigService.isHmacValidationEnabled();
        Test.stopTest();

        System.assertEquals(false, enabled,
            'Should return false when HMAC validation is disabled');
    }

    @isTest
    static void testIsAutoDownloadMediaEnabledReturnsConfigValue() {
        Test.startTest();
        Boolean enabled = WhatsAppConfigService.isAutoDownloadMediaEnabled();
        Test.stopTest();

        System.assertEquals(true, enabled,
            'Should return auto-download media setting from configuration');
    }

    @isTest
    static void testIsAutoDownloadMediaEnabledReturnsFalseWhenDisabled() {
        WhatsApp_Configuration__c config = [
            SELECT Id FROM WhatsApp_Configuration__c LIMIT 1
        ];
        config.Auto_Download_Media__c = false;
        update config;
        WhatsAppConfigService.clearCache();

        Test.startTest();
        Boolean enabled = WhatsAppConfigService.isAutoDownloadMediaEnabled();
        Test.stopTest();

        System.assertEquals(false, enabled,
            'Should return false when auto-download media is disabled');
    }

    @isTest
    static void testGetActiveConfigurationThrowsWhenNoConfig() {
        delete [SELECT Id FROM WhatsApp_Configuration__c];
        WhatsAppConfigService.clearCache();

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            WhatsAppConfigService.getActiveConfiguration();
        } catch (WhatsAppConfigService.WhatsAppConfigException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('No active WhatsApp configuration found'),
                'Exception message should indicate missing configuration');
        }
        Test.stopTest();

        System.assert(exceptionThrown,
            'WhatsAppConfigException should be thrown when no active config exists');
    }
}