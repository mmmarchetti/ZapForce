@isTest
private class WhatsAppAPIServiceTest {

    private class MockHttpResponse implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        private Boolean isBlobResponse;
        private Integer callCount = 0;

        public MockHttpResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
            this.isBlobResponse = false;
        }

        public MockHttpResponse(Integer statusCode, String body, Boolean isBlobResponse) {
            this.statusCode = statusCode;
            this.body = body;
            this.isBlobResponse = isBlobResponse;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            if (isBlobResponse && callCount > 0) {
                res.setBodyAsBlob(Blob.valueOf('fake binary content'));
            } else {
                res.setBody(body);
            }
            callCount++;
            return res;
        }
    }

    private class MediaDownloadMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (req.getMethod() == 'GET' && !req.getEndpoint().contains('graph.facebook.com')) {
                res.setBodyAsBlob(Blob.valueOf('fake binary content'));
            } else if (req.getMethod() == 'GET') {
                res.setBody('{"url":"https://media.whatsapp.com/download/test123"}');
            } else {
                res.setBody('{"messages":[{"id":"wamid.test123"}]}');
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
            Session_Timeout_Minutes__c = 1440
        );
        insert config;
    }

    @isTest
    static void testSendTextMessage() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"messages":[{"id":"wamid.test123"}]}'));

        Test.startTest();
        String messageId = WhatsAppAPIService.sendTextMessage('+14155559999', 'Hello World');
        Test.stopTest();

        System.assertEquals('wamid.test123', messageId, 'Should return the WhatsApp message ID');
    }

    @isTest
    static void testSendMediaMessage() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"messages":[{"id":"wamid.test123"}]}'));

        Test.startTest();
        String messageId = WhatsAppAPIService.sendMediaMessage('+14155559999', 'media-id-123', 'image', 'Test caption');
        Test.stopTest();

        System.assertEquals('wamid.test123', messageId, 'Should return the WhatsApp message ID');
    }

    @isTest
    static void testSendLocationMessage() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"messages":[{"id":"wamid.test123"}]}'));

        Test.startTest();
        String messageId = WhatsAppAPIService.sendLocationMessage('+14155559999', (Double)37.7749, (Double)(-122.4194), 'San Francisco', '123 Main St');
        Test.stopTest();

        System.assertEquals('wamid.test123', messageId, 'Should return the WhatsApp message ID');
    }

    @isTest
    static void testSendTemplateMessage() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"messages":[{"id":"wamid.test123"}]}'));

        Test.startTest();
        String messageId = WhatsAppAPIService.sendTemplateMessage('+14155559999', 'hello_world', 'en_US', null);
        Test.stopTest();

        System.assertEquals('wamid.test123', messageId, 'Should return the WhatsApp message ID');
    }

    @isTest
    static void testSendReactionMessage() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"messages":[{"id":"wamid.test123"}]}'));

        Test.startTest();
        String messageId = WhatsAppAPIService.sendReactionMessage('+14155559999', 'wamid.original123', '\uD83D\uDC4D');
        Test.stopTest();

        System.assertEquals('wamid.test123', messageId, 'Should return the WhatsApp message ID');
    }

    @isTest
    static void testSendStickerMessage() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"messages":[{"id":"wamid.test123"}]}'));

        Test.startTest();
        String messageId = WhatsAppAPIService.sendStickerMessage('+14155559999', 'sticker-id-123');
        Test.stopTest();

        System.assertEquals('wamid.test123', messageId, 'Should return the WhatsApp message ID');
    }

    @isTest
    static void testSendContactMessage() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"messages":[{"id":"wamid.test123"}]}'));

        String contactJson = '[{"name":{"formatted_name":"John Doe"},"phones":[{"phone":"+14155551234"}]}]';

        Test.startTest();
        String messageId = WhatsAppAPIService.sendContactMessage('+14155559999', contactJson);
        Test.stopTest();

        System.assertEquals('wamid.test123', messageId, 'Should return the WhatsApp message ID');
    }

    @isTest
    static void testSendInteractiveMessage() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"messages":[{"id":"wamid.test123"}]}'));

        Map<String, Object> interactivePayload = new Map<String, Object>{
            'type' => 'button',
            'body' => new Map<String, Object>{ 'text' => 'Choose an option' },
            'action' => new Map<String, Object>{
                'buttons' => new List<Object>()
            }
        };

        Test.startTest();
        String messageId = WhatsAppAPIService.sendInteractiveMessage('+14155559999', interactivePayload);
        Test.stopTest();

        System.assertEquals('wamid.test123', messageId, 'Should return the WhatsApp message ID');
    }

    @isTest
    static void testMarkAsRead() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"success":true}'));

        Test.startTest();
        Boolean result = WhatsAppAPIService.markAsRead('wamid.test123');
        Test.stopTest();

        System.assertEquals(true, result, 'markAsRead should return true on success');
    }

    @isTest
    static void testMarkAsReadFailure() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(400, '{"error":"bad request"}'));

        Test.startTest();
        Boolean result = WhatsAppAPIService.markAsRead('wamid.test123');
        Test.stopTest();

        System.assertEquals(false, result, 'markAsRead should return false on failure');
    }

    @isTest
    static void testDownloadMedia() {
        Test.setMock(HttpCalloutMock.class, new MediaDownloadMock());

        Test.startTest();
        Blob mediaBlob = WhatsAppAPIService.downloadMedia('media-id-123');
        Test.stopTest();

        System.assertNotEquals(null, mediaBlob, 'downloadMedia should return a non-null Blob');
        System.assert(mediaBlob.size() > 0, 'Downloaded media blob should not be empty');
    }
}
