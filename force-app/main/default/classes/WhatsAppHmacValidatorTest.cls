@isTest
private class WhatsAppHmacValidatorTest {

    private static final String TEST_SECRET = 'my_app_secret_key';
    private static final String TEST_PAYLOAD = '{"object":"whatsapp_business_account","entry":[]}';

    /**
     * Helper that computes the expected HMAC-SHA256 signature for the test payload.
     */
    private static String computeExpectedSignature(String payload, String secret) {
        Blob hmac = Crypto.generateMac(
            'HmacSHA256',
            Blob.valueOf(payload),
            Blob.valueOf(secret)
        );
        return EncodingUtil.convertToHex(hmac);
    }

    @isTest
    static void testValidateSignatureWithCorrectSignature() {
        String expectedHash = computeExpectedSignature(TEST_PAYLOAD, TEST_SECRET);
        String signatureWithPrefix = 'sha256=' + expectedHash;

        Test.startTest();
        Boolean result = WhatsAppHmacValidator.validateSignature(
            TEST_PAYLOAD, signatureWithPrefix, TEST_SECRET
        );
        Test.stopTest();

        System.assertEquals(true, result, 'Valid signature should return true');
    }

    @isTest
    static void testValidateSignatureWithCorrectHashOnly() {
        String expectedHash = computeExpectedSignature(TEST_PAYLOAD, TEST_SECRET);

        Test.startTest();
        Boolean result = WhatsAppHmacValidator.validateSignature(
            TEST_PAYLOAD, expectedHash, TEST_SECRET
        );
        Test.stopTest();

        System.assertEquals(true, result, 'Valid hash without prefix should return true');
    }

    @isTest
    static void testValidateSignatureWithIncorrectSignature() {
        Test.startTest();
        Boolean result = WhatsAppHmacValidator.validateSignature(
            TEST_PAYLOAD, 'sha256=incorrecthashvalue', TEST_SECRET
        );
        Test.stopTest();

        System.assertEquals(false, result, 'Invalid signature should return false');
    }

    @isTest
    static void testValidateSignatureWithNullPayload() {
        Test.startTest();
        Boolean result = WhatsAppHmacValidator.validateSignature(
            null, 'sha256=abc123', TEST_SECRET
        );
        Test.stopTest();

        System.assertEquals(false, result, 'Null payload should return false');
    }

    @isTest
    static void testValidateSignatureWithEmptySignature() {
        Test.startTest();
        Boolean result = WhatsAppHmacValidator.validateSignature(
            TEST_PAYLOAD, '', TEST_SECRET
        );
        Test.stopTest();

        System.assertEquals(false, result, 'Empty signature should return false');
    }

    @isTest
    static void testValidateSignatureWithNullSecret() {
        Test.startTest();
        Boolean result = WhatsAppHmacValidator.validateSignature(
            TEST_PAYLOAD, 'sha256=abc123', null
        );
        Test.stopTest();

        System.assertEquals(false, result, 'Null secret should return false');
    }

    @isTest
    static void testValidateSignatureWithAllNullParams() {
        Test.startTest();
        Boolean result = WhatsAppHmacValidator.validateSignature(null, null, null);
        Test.stopTest();

        System.assertEquals(false, result, 'All null parameters should return false');
    }

    @isTest
    static void testValidateFromRequestWithValidHeader() {
        String expectedHash = computeExpectedSignature(TEST_PAYLOAD, TEST_SECRET);

        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(TEST_PAYLOAD);
        req.headers.put('X-Hub-Signature-256', 'sha256=' + expectedHash);

        Test.startTest();
        Boolean result = WhatsAppHmacValidator.validateFromRequest(req, TEST_SECRET);
        Test.stopTest();

        System.assertEquals(true, result, 'Valid request with correct header should return true');
    }

    @isTest
    static void testValidateFromRequestWithMissingHeader() {
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(TEST_PAYLOAD);

        Test.startTest();
        Boolean result = WhatsAppHmacValidator.validateFromRequest(req, TEST_SECRET);
        Test.stopTest();

        System.assertEquals(false, result, 'Missing signature header should return false');
    }

    @isTest
    static void testValidateFromRequestWithNullRequest() {
        Test.startTest();
        Boolean result = WhatsAppHmacValidator.validateFromRequest(null, TEST_SECRET);
        Test.stopTest();

        System.assertEquals(false, result, 'Null request should return false');
    }

    @isTest
    static void testValidateFromRequestWithNullSecret() {
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(TEST_PAYLOAD);
        req.headers.put('X-Hub-Signature-256', 'sha256=abc');

        Test.startTest();
        Boolean result = WhatsAppHmacValidator.validateFromRequest(req, null);
        Test.stopTest();

        System.assertEquals(false, result, 'Null secret should return false');
    }
}