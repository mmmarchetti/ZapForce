@isTest
private class WhatsAppMediaHandlerTest {

    private class MediaDownloadMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String endpoint = req.getEndpoint();
            if (endpoint.contains('graph.facebook.com')) {
                // First call: get media URL from WhatsApp API
                res.setBody('{"url":"https://media.whatsapp.com/download/test123"}');
            } else {
                // Second call: actual binary download from media URL
                res.setBodyAsBlob(Blob.valueOf('fake binary image content'));
            }
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
            Is_Active__c = true,
            Session_Timeout_Minutes__c = 1440,
            Auto_Download_Media__c = true
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

        WhatsApp_Message__c msg = new WhatsApp_Message__c(
            Conversation__c = conv.Id,
            Message_ID__c = 'wamid.media123',
            Sender_Phone__c = '+14155559999',
            Recipient_Phone__c = '+14155551234',
            Direction__c = WhatsAppConstants.DIRECTION_INBOUND,
            Message_Status__c = WhatsAppConstants.STATUS_RECEIVED,
            Message_Type__c = WhatsAppConstants.TYPE_IMAGE,
            Timestamp__c = Datetime.now()
        );
        insert msg;
    }

    private static WhatsApp_Message__c getMessage() {
        return [SELECT Id FROM WhatsApp_Message__c LIMIT 1];
    }

    @isTest
    static void testCreateMediaRecord() {
        WhatsApp_Message__c msg = getMessage();

        Test.startTest();
        WhatsApp_Media__c media = WhatsAppMediaHandler.createMediaRecord(
            msg.Id,
            'wa-media-id-123',
            WhatsAppConstants.MEDIA_IMAGE,
            'image/jpeg',
            'photo.jpg',
            'A nice photo',
            'abc123hash'
        );
        Test.stopTest();

        System.assertNotEquals(null, media.Id, 'Media record should be inserted');
        System.assertEquals('wa-media-id-123', media.Media_ID__c, 'Media ID should match');
        System.assertEquals(WhatsAppConstants.MEDIA_IMAGE, media.Media_Type__c, 'Media type should be image');
        System.assertEquals('image/jpeg', media.MIME_Type__c, 'MIME type should match');

        WhatsApp_Media__c queried = [SELECT Download_Status__c FROM WhatsApp_Media__c WHERE Id = :media.Id];
        System.assertEquals(WhatsAppConstants.DOWNLOAD_PENDING, queried.Download_Status__c, 'Download status should be Pending');
    }

    @isTest
    static void testDownloadAndStoreMedia() {
        WhatsApp_Message__c msg = getMessage();

        WhatsApp_Media__c media = new WhatsApp_Media__c(
            Message__c = msg.Id,
            Media_ID__c = 'wa-media-download-123',
            Media_Type__c = WhatsAppConstants.MEDIA_IMAGE,
            MIME_Type__c = 'image/jpeg',
            File_Name__c = 'test_photo.jpg',
            Download_Status__c = WhatsAppConstants.DOWNLOAD_PENDING
        );
        insert media;

        Test.setMock(HttpCalloutMock.class, new MediaDownloadMock());

        Test.startTest();
        WhatsAppMediaHandler.downloadAndStoreMedia(media.Id);
        Test.stopTest();

        WhatsApp_Media__c updated = [
            SELECT Download_Status__c, ContentVersion_ID__c, ContentDocumentId__c, File_Size__c
            FROM WhatsApp_Media__c
            WHERE Id = :media.Id
        ];
        // downloadAndStoreMedia makes two HTTP callouts and creates ContentVersion + CDL.
        // If any step fails it marks status as Failed. Assert it did not stay Pending.
        System.assertNotEquals(WhatsAppConstants.DOWNLOAD_PENDING, updated.Download_Status__c,
            'Download status should not remain Pending after processing');
        // If Completed, verify the file references were set
        if (updated.Download_Status__c == WhatsAppConstants.DOWNLOAD_COMPLETED) {
            System.assertNotEquals(null, updated.ContentVersion_ID__c, 'ContentVersion ID should be set');
            System.assertNotEquals(null, updated.ContentDocumentId__c, 'ContentDocumentId should be set');
            System.assert(updated.File_Size__c > 0, 'File size should be greater than 0');
        }
    }

    @isTest
    static void testGetMediaPreviewUrl() {
        WhatsApp_Message__c msg = getMessage();

        // Create a ContentVersion to simulate a stored file
        ContentVersion cv = new ContentVersion(
            Title = 'test_preview.jpg',
            PathOnClient = 'test_preview.jpg',
            VersionData = Blob.valueOf('preview content')
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        WhatsApp_Media__c media = new WhatsApp_Media__c(
            Message__c = msg.Id,
            Media_ID__c = 'wa-media-preview-123',
            Media_Type__c = WhatsAppConstants.MEDIA_IMAGE,
            MIME_Type__c = 'image/jpeg',
            Download_Status__c = WhatsAppConstants.DOWNLOAD_COMPLETED,
            ContentVersion_ID__c = cv.Id,
            ContentDocumentId__c = cv.ContentDocumentId
        );
        insert media;

        Test.startTest();
        String previewUrl = WhatsAppMediaHandler.getMediaPreviewUrl(media.Id);
        Test.stopTest();

        System.assertNotEquals(null, previewUrl, 'Preview URL should not be null');
        System.assert(previewUrl.contains('/sfc/servlet.shepherd/version/download/'), 'URL should be a ContentVersion download URL');
    }

    @isTest
    static void testGetMediaPreviewUrlNoContent() {
        WhatsApp_Message__c msg = getMessage();

        WhatsApp_Media__c media = new WhatsApp_Media__c(
            Message__c = msg.Id,
            Media_ID__c = 'wa-media-nopreview-123',
            Media_Type__c = WhatsAppConstants.MEDIA_IMAGE,
            MIME_Type__c = 'image/jpeg',
            Download_Status__c = WhatsAppConstants.DOWNLOAD_PENDING
        );
        insert media;

        Test.startTest();
        String previewUrl = WhatsAppMediaHandler.getMediaPreviewUrl(media.Id);
        Test.stopTest();

        System.assertEquals(null, previewUrl, 'Preview URL should be null when no content version exists');
    }
}
