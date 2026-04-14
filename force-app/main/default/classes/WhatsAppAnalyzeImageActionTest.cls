@isTest
private class WhatsAppAnalyzeImageActionTest {

    @testSetup
    static void setupData() {
        WhatsApp_Configuration__c config = new WhatsApp_Configuration__c(
            API_Key__c = 'test-api-key-123',
            Phone_Number__c = '+14155551234',
            Phone_Number_ID__c = '123456789',
            API_Base_URL__c = 'https://graph.facebook.com',
            WhatsApp_API_Version__c = 'v21.0',
            Is_Active__c = true,
            Session_Timeout_Minutes__c = 1440,
            SF_Client_Id__c = 'test-client-id',
            SF_Client_Secret__c = 'test-client-secret'
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

    // Mock for the vision model API (token + chat-generations)
    private class VisionModelMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('oauth2/token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"eyJtest-jwt-token","token_type":"Bearer"}');
            } else if (req.getEndpoint().contains('einstein/llm/chat-generations')) {
                res.setStatusCode(200);
                res.setBody('{"generationDetails":{"generations":[{"content":"The image shows the Salesforce logo - a blue cloud shape with the text Salesforce written in white inside it. The cloud is a distinctive rounded shape that has become an iconic symbol in the technology industry."}]}}');
            } else {
                res.setStatusCode(404);
                res.setBody('{"error":"Not Found"}');
            }
            return res;
        }
    }

    private static WhatsApp_Media__c createImageMedia(Id conversationId, String downloadStatus) {
        WhatsApp_Message__c msg = new WhatsApp_Message__c(
            Conversation__c = conversationId,
            Message_Type__c = 'Image',
            Direction__c = WhatsAppConstants.DIRECTION_INBOUND,
            Content__c = 'Salesforce logo',
            Sender_Phone__c = '+14155559999',
            Recipient_Phone__c = '+14155551234',
            Timestamp__c = Datetime.now()
        );
        insert msg;

        WhatsApp_Media__c media = new WhatsApp_Media__c(
            Message__c = msg.Id,
            Media_ID__c = 'wa-media-' + String.valueOf(Datetime.now().getTime()),
            Media_Type__c = 'Image',
            MIME_Type__c = 'image/png',
            File_Name__c = 'salesforce-logo.png',
            Download_Status__c = downloadStatus
        );
        insert media;

        if (downloadStatus == WhatsAppConstants.DOWNLOAD_COMPLETED) {
            // Create a small test image in ContentVersion
            Blob testImageBlob = Blob.valueOf('fake-png-image-data-for-testing');
            ContentVersion cv = new ContentVersion();
            cv.Title = 'salesforce-logo.png';
            cv.PathOnClient = 'salesforce-logo.png';
            cv.VersionData = testImageBlob;
            insert cv;

            cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

            media.ContentVersion_ID__c = cv.Id;
            media.ContentDocumentId__c = cv.ContentDocumentId;
            update media;
        }

        return media;
    }

    @isTest
    static void testAnalyzeImage_Success() {
        WhatsApp_Conversation__c conv = [SELECT Id FROM WhatsApp_Conversation__c LIMIT 1];
        createImageMedia(conv.Id, WhatsAppConstants.DOWNLOAD_COMPLETED);

        WhatsAppAnalyzeImageAction.AnalyzeImageRequest req = new WhatsAppAnalyzeImageAction.AnalyzeImageRequest();
        req.conversationId = conv.Id;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new VisionModelMock());
        List<WhatsAppAnalyzeImageAction.AnalyzeImageResult> results =
            WhatsAppAnalyzeImageAction.analyzeImage(
                new List<WhatsAppAnalyzeImageAction.AnalyzeImageRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        WhatsAppAnalyzeImageAction.AnalyzeImageResult result = results[0];
        System.assertEquals(true, result.imageFound, 'Should find image');
        System.assert(String.isNotBlank(result.description), 'Description should not be blank');
        System.assert(result.description.contains('Salesforce'), 'Description should mention Salesforce');
        System.assertEquals('image/png', result.imageMimeType, 'MIME type should match');
        System.assertEquals('salesforce-logo.png', result.imageFileName, 'File name should match');
        System.assertEquals(null, result.errorMessage, 'Error message should be null');
    }

    @isTest
    static void testAnalyzeImage_NoImageFound() {
        WhatsApp_Conversation__c conv = [SELECT Id FROM WhatsApp_Conversation__c LIMIT 1];

        WhatsAppAnalyzeImageAction.AnalyzeImageRequest req = new WhatsAppAnalyzeImageAction.AnalyzeImageRequest();
        req.conversationId = conv.Id;

        Test.startTest();
        List<WhatsAppAnalyzeImageAction.AnalyzeImageResult> results =
            WhatsAppAnalyzeImageAction.analyzeImage(
                new List<WhatsAppAnalyzeImageAction.AnalyzeImageRequest>{ req }
            );
        Test.stopTest();

        WhatsAppAnalyzeImageAction.AnalyzeImageResult result = results[0];
        System.assertEquals(false, result.imageFound, 'Should not find image');
        System.assert(result.errorMessage.contains('No image'), 'Error should explain no image found');
    }

    @isTest
    static void testAnalyzeImage_ImageStillDownloading() {
        WhatsApp_Conversation__c conv = [SELECT Id FROM WhatsApp_Conversation__c LIMIT 1];
        createImageMedia(conv.Id, WhatsAppConstants.DOWNLOAD_PENDING);

        WhatsAppAnalyzeImageAction.AnalyzeImageRequest req = new WhatsAppAnalyzeImageAction.AnalyzeImageRequest();
        req.conversationId = conv.Id;

        Test.startTest();
        List<WhatsAppAnalyzeImageAction.AnalyzeImageResult> results =
            WhatsAppAnalyzeImageAction.analyzeImage(
                new List<WhatsAppAnalyzeImageAction.AnalyzeImageRequest>{ req }
            );
        Test.stopTest();

        WhatsAppAnalyzeImageAction.AnalyzeImageResult result = results[0];
        System.assertEquals(true, result.imageFound, 'Should find image record');
        System.assertEquals(null, result.description, 'Description should be null');
        System.assert(result.errorMessage.contains('still being downloaded'), 'Error should mention downloading');
    }

    @isTest
    static void testAnalyzeImage_DownloadFailed() {
        WhatsApp_Conversation__c conv = [SELECT Id FROM WhatsApp_Conversation__c LIMIT 1];
        createImageMedia(conv.Id, WhatsAppConstants.DOWNLOAD_FAILED);

        WhatsAppAnalyzeImageAction.AnalyzeImageRequest req = new WhatsAppAnalyzeImageAction.AnalyzeImageRequest();
        req.conversationId = conv.Id;

        Test.startTest();
        List<WhatsAppAnalyzeImageAction.AnalyzeImageResult> results =
            WhatsAppAnalyzeImageAction.analyzeImage(
                new List<WhatsAppAnalyzeImageAction.AnalyzeImageRequest>{ req }
            );
        Test.stopTest();

        WhatsAppAnalyzeImageAction.AnalyzeImageResult result = results[0];
        System.assertEquals(true, result.imageFound, 'Should find image record');
        System.assert(result.errorMessage.contains('download failed'), 'Error should mention download failure');
    }

    @isTest
    static void testAnalyzeImage_NullConversationId() {
        WhatsAppAnalyzeImageAction.AnalyzeImageRequest req = new WhatsAppAnalyzeImageAction.AnalyzeImageRequest();
        req.conversationId = null;

        Test.startTest();
        List<WhatsAppAnalyzeImageAction.AnalyzeImageResult> results =
            WhatsAppAnalyzeImageAction.analyzeImage(
                new List<WhatsAppAnalyzeImageAction.AnalyzeImageRequest>{ req }
            );
        Test.stopTest();

        WhatsAppAnalyzeImageAction.AnalyzeImageResult result = results[0];
        System.assertEquals(false, result.imageFound, 'Should not find image');
        System.assertEquals('Conversation ID is required.', result.errorMessage, 'Error message should explain');
    }

    @isTest
    static void testAnalyzeImage_MultipleImages_ReturnsMostRecent() {
        WhatsApp_Conversation__c conv = [SELECT Id FROM WhatsApp_Conversation__c LIMIT 1];

        // Older image
        WhatsApp_Message__c oldMsg = new WhatsApp_Message__c(
            Conversation__c = conv.Id,
            Message_Type__c = 'Image',
            Direction__c = WhatsAppConstants.DIRECTION_INBOUND,
            Content__c = 'Old image',
            Sender_Phone__c = '+14155559999',
            Recipient_Phone__c = '+14155551234',
            Timestamp__c = Datetime.now().addHours(-2)
        );
        insert oldMsg;

        WhatsApp_Media__c oldMedia = new WhatsApp_Media__c(
            Message__c = oldMsg.Id,
            Media_ID__c = 'wa-media-old',
            Media_Type__c = 'Image',
            MIME_Type__c = 'image/jpeg',
            File_Name__c = 'old-photo.jpg',
            Download_Status__c = WhatsAppConstants.DOWNLOAD_COMPLETED
        );
        insert oldMedia;

        // Create ContentVersion for old image
        ContentVersion oldCv = new ContentVersion();
        oldCv.Title = 'old-photo.jpg';
        oldCv.PathOnClient = 'old-photo.jpg';
        oldCv.VersionData = Blob.valueOf('old-image-data');
        insert oldCv;
        oldCv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :oldCv.Id];
        oldMedia.ContentVersion_ID__c = oldCv.Id;
        oldMedia.ContentDocumentId__c = oldCv.ContentDocumentId;
        update oldMedia;

        // Newer image (Salesforce logo)
        createImageMedia(conv.Id, WhatsAppConstants.DOWNLOAD_COMPLETED);

        WhatsAppAnalyzeImageAction.AnalyzeImageRequest req = new WhatsAppAnalyzeImageAction.AnalyzeImageRequest();
        req.conversationId = conv.Id;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new VisionModelMock());
        List<WhatsAppAnalyzeImageAction.AnalyzeImageResult> results =
            WhatsAppAnalyzeImageAction.analyzeImage(
                new List<WhatsAppAnalyzeImageAction.AnalyzeImageRequest>{ req }
            );
        Test.stopTest();

        WhatsAppAnalyzeImageAction.AnalyzeImageResult result = results[0];
        System.assertEquals(true, result.imageFound, 'Should find image');
        System.assertEquals('salesforce-logo.png', result.imageFileName, 'Should return the most recent image');
        System.assertEquals('image/png', result.imageMimeType, 'MIME type should be from the newest image');
    }
}
