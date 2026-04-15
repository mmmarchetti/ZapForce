@IsTest
private class WhatsAppAudioTranscriptionServiceTest {
    @TestSetup
    static void setup() {
        WhatsApp_Configuration__c config = new WhatsApp_Configuration__c(
            Phone_Number__c = '+1234567890',
            API_Base_URL__c = 'https://graph.facebook.com/v18.0',
            Is_Active__c = true,
            Phone_Number_ID__c = '123456789',
            Audio_Transcription_Flow_API_Name__c = 'Test_Audio_Flow'
        );
        insert config;
    }

    @IsTest
    static void testTranscribeAudioFlowNotConfigured() {
        WhatsApp_Configuration__c config = [SELECT Id FROM WhatsApp_Configuration__c LIMIT 1];
        config.Audio_Transcription_Flow_API_Name__c = null;
        update config;
        WhatsAppConfigService.clearCache();

        ContentVersion cv = new ContentVersion(
            Title = 'Test Audio',
            PathOnClient = 'test.mp3',
            VersionData = Blob.valueOf('test audio data'),
            FirstPublishLocationId = UserInfo.getUserId()
        );
        insert cv;

        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        Test.startTest();
        String result = WhatsAppAudioTranscriptionService.transcribeAudio(insertedCv.ContentDocumentId);
        Test.stopTest();

        Assert.isNull(result, 'Should return null when Flow not configured');
    }

    @IsTest
    static void testTranscribeAudioInvalidFlow() {
        WhatsApp_Configuration__c config = [SELECT Id FROM WhatsApp_Configuration__c LIMIT 1];
        config.Audio_Transcription_Flow_API_Name__c = 'NonExistentFlow';
        update config;
        WhatsAppConfigService.clearCache();

        ContentVersion cv = new ContentVersion(
            Title = 'Test Audio',
            PathOnClient = 'test.mp3',
            VersionData = Blob.valueOf('test audio data'),
            FirstPublishLocationId = UserInfo.getUserId()
        );
        insert cv;

        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        Test.startTest();
        String result = WhatsAppAudioTranscriptionService.transcribeAudio(insertedCv.ContentDocumentId);
        Test.stopTest();

        Assert.isNull(result, 'Should return null when Flow execution fails');
    }

    @IsTest
    static void testTranscribeAudioNullInput() {
        Test.startTest();
        String result = WhatsAppAudioTranscriptionService.transcribeAudio(null);
        Test.stopTest();

        Assert.isNull(result, 'Should handle null input gracefully');
    }
}
