@IsTest
private class WhatsAppMediaFlowServiceTest {
    @TestSetup
    static void setup() {
        WhatsApp_Configuration__c config = new WhatsApp_Configuration__c(
            Phone_Number__c = '+1234567890',
            API_Base_URL__c = 'https://graph.facebook.com/v18.0',
            Is_Active__c = true,
            Phone_Number_ID__c = '123456789',
            Audio_Transcription_Flow_API_Name__c = 'Test_Audio_Flow',
            Image_Analysis_Flow_API_Name__c = 'Test_Image_Flow'
        );
        insert config;
    }

    @IsTest
    static void testAudioFlowNotConfigured() {
        WhatsApp_Configuration__c config = [SELECT Id FROM WhatsApp_Configuration__c LIMIT 1];
        config.Audio_Transcription_Flow_API_Name__c = null;
        update config;
        WhatsAppConfigService.clearCache();

        ContentVersion cv = createTestContentVersion();

        Test.startTest();
        String result = WhatsAppMediaFlowService.processMedia(
            cv.ContentDocumentId,
            WhatsAppMediaFlowService.MediaFlowConfig.forAudio()
        );
        Test.stopTest();

        Assert.isNull(result, 'Should return null when Flow not configured');

        List<WhatsApp_Log__c> logs = [
            SELECT Action__c
            FROM WhatsApp_Log__c
            WHERE Action__c = 'AUDIO_TRANSCRIPTION_FLOW_NOT_CONFIGURED'
        ];
        Assert.areEqual(1, logs.size(), 'Should log AUDIO_TRANSCRIPTION_FLOW_NOT_CONFIGURED');
    }

    @IsTest
    static void testImageFlowNotConfigured() {
        WhatsApp_Configuration__c config = [SELECT Id FROM WhatsApp_Configuration__c LIMIT 1];
        config.Image_Analysis_Flow_API_Name__c = null;
        update config;
        WhatsAppConfigService.clearCache();

        ContentVersion cv = createTestContentVersion();

        Test.startTest();
        String result = WhatsAppMediaFlowService.processMedia(
            cv.ContentDocumentId,
            WhatsAppMediaFlowService.MediaFlowConfig.forImage()
        );
        Test.stopTest();

        Assert.isNull(result, 'Should return null when Flow not configured');

        List<WhatsApp_Log__c> logs = [
            SELECT Action__c
            FROM WhatsApp_Log__c
            WHERE Action__c = 'IMAGE_ANALYSIS_FLOW_NOT_CONFIGURED'
        ];
        Assert.areEqual(1, logs.size(), 'Should log IMAGE_ANALYSIS_FLOW_NOT_CONFIGURED');
    }

    @IsTest
    static void testInvalidFlowName() {
        WhatsApp_Configuration__c config = [SELECT Id FROM WhatsApp_Configuration__c LIMIT 1];
        config.Audio_Transcription_Flow_API_Name__c = 'NonExistentFlow';
        update config;
        WhatsAppConfigService.clearCache();

        ContentVersion cv = createTestContentVersion();

        Test.startTest();
        String result = WhatsAppMediaFlowService.processMedia(
            cv.ContentDocumentId,
            WhatsAppMediaFlowService.MediaFlowConfig.forAudio()
        );
        Test.stopTest();

        Assert.isNull(result, 'Should return null when Flow does not exist');

        List<WhatsApp_Log__c> logs = [
            SELECT Action__c
            FROM WhatsApp_Log__c
            WHERE Action__c LIKE 'AUDIO_TRANSCRIPTION_%'
        ];
        Assert.isTrue(logs.size() > 0, 'Should log error when Flow fails');
    }

    @IsTest
    static void testNullContentDocumentId() {
        Test.startTest();
        String result = WhatsAppMediaFlowService.processMedia(
            null,
            WhatsAppMediaFlowService.MediaFlowConfig.forAudio()
        );
        Test.stopTest();

        Assert.isNull(result, 'Should handle null contentDocumentId gracefully');
    }

    @IsTest
    static void testMediaFlowConfigForAudio() {
        WhatsAppMediaFlowService.MediaFlowConfig config = WhatsAppMediaFlowService.MediaFlowConfig.forAudio();

        Assert.areEqual('Test_Audio_Flow', config.flowApiName, 'Should get audio flow name from config');
        Assert.areEqual('transcription', config.outputKey, 'Should use transcription output key');
        Assert.areEqual('AUDIO_TRANSCRIPTION', config.logPrefix, 'Should use AUDIO_TRANSCRIPTION log prefix');
    }

    @IsTest
    static void testMediaFlowConfigForImage() {
        WhatsAppMediaFlowService.MediaFlowConfig config = WhatsAppMediaFlowService.MediaFlowConfig.forImage();

        Assert.areEqual('Test_Image_Flow', config.flowApiName, 'Should get image flow name from config');
        Assert.areEqual('analysis', config.outputKey, 'Should use analysis output key');
        Assert.areEqual('IMAGE_ANALYSIS', config.logPrefix, 'Should use IMAGE_ANALYSIS log prefix');
    }

    @IsTest
    static void testLogPrefixesAreDistinct() {
        WhatsAppMediaFlowService.MediaFlowConfig audioConfig = WhatsAppMediaFlowService.MediaFlowConfig.forAudio();
        WhatsAppMediaFlowService.MediaFlowConfig imageConfig = WhatsAppMediaFlowService.MediaFlowConfig.forImage();

        Assert.areNotEqual(audioConfig.logPrefix, imageConfig.logPrefix, 'Log prefixes should be distinct');
        Assert.areNotEqual(audioConfig.outputKey, imageConfig.outputKey, 'Output keys should be distinct');
    }

    // Helper method
    private static ContentVersion createTestContentVersion() {
        ContentVersion cv = new ContentVersion(
            Title = 'Test Media',
            PathOnClient = 'test.mp3',
            VersionData = Blob.valueOf('test media data'),
            FirstPublishLocationId = UserInfo.getUserId()
        );
        insert cv;

        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        return insertedCv;
    }
}
