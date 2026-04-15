@IsTest
private class WhatsAppImageAnalysisFlowServiceTest {
    @TestSetup
    static void setup() {
        WhatsApp_Configuration__c config = new WhatsApp_Configuration__c(
            Phone_Number__c = '+1234567890',
            API_Base_URL__c = 'https://graph.facebook.com/v18.0',
            Is_Active__c = true,
            Phone_Number_ID__c = '123456789',
            Image_Analysis_Flow_API_Name__c = 'WhatsApp_Image_Analysis_Template'
        );
        insert config;
    }

    @IsTest
    static void testFlowNotConfigured() {
        WhatsApp_Configuration__c config = [SELECT Id FROM WhatsApp_Configuration__c LIMIT 1];
        config.Image_Analysis_Flow_API_Name__c = null;
        update config;
        WhatsAppConfigService.clearCache();

        ContentVersion cv = new ContentVersion(
            Title = 'Test Image',
            PathOnClient = 'test.jpg',
            VersionData = Blob.valueOf('test image data'),
            FirstPublishLocationId = UserInfo.getUserId()
        );
        insert cv;

        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        Test.startTest();
        String result = WhatsAppImageAnalysisFlowService.analyzeImage(insertedCv.ContentDocumentId);
        Test.stopTest();

        Assert.isNull(result, 'Should return null when Flow not configured');

        List<WhatsApp_Log__c> logs = [
            SELECT Level__c, Action__c
            FROM WhatsApp_Log__c
            WHERE Action__c = 'IMAGE_ANALYSIS_FLOW_NOT_CONFIGURED'
        ];
        Assert.areEqual(1, logs.size(), 'Should log error when Flow not configured');
        Assert.areEqual('ERROR', logs[0].Level__c, 'Should log as ERROR level');
    }

    @IsTest
    static void testFlowConfiguredButInvalid() {
        WhatsApp_Configuration__c config = [SELECT Id FROM WhatsApp_Configuration__c LIMIT 1];
        config.Image_Analysis_Flow_API_Name__c = 'NonExistentFlow';
        update config;
        WhatsAppConfigService.clearCache();

        ContentVersion cv = new ContentVersion(
            Title = 'Test Image',
            PathOnClient = 'test.jpg',
            VersionData = Blob.valueOf('test image data'),
            FirstPublishLocationId = UserInfo.getUserId()
        );
        insert cv;

        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        Test.startTest();
        String result = WhatsAppImageAnalysisFlowService.analyzeImage(insertedCv.ContentDocumentId);
        Test.stopTest();

        Assert.isNull(result, 'Should return null when Flow execution fails');

        List<WhatsApp_Log__c> logs = [
            SELECT Action__c
            FROM WhatsApp_Log__c
            WHERE Action__c = 'IMAGE_ANALYSIS_EXCEPTION'
        ];
        Assert.areEqual(1, logs.size(), 'Should log exception when Flow does not exist');
    }

    @IsTest
    static void testNullContentDocumentId() {
        Test.startTest();
        String result = WhatsAppImageAnalysisFlowService.analyzeImage(null);
        Test.stopTest();

        Assert.isNull(result, 'Should handle null contentDocumentId gracefully');
    }

    @IsTest
    static void testInvalidContentDocumentId() {
        Id fakeId = '069000000000000AAA';

        Test.startTest();
        String result = WhatsAppImageAnalysisFlowService.analyzeImage(fakeId);
        Test.stopTest();

        Assert.isNull(result, 'Should return null for invalid ContentDocument ID');
    }
}
