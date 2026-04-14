public with sharing class WhatsAppHmacValidator {

    public static Boolean validateSignature(String payload, String signature, String appSecret) {
        try {
            if (String.isBlank(payload) || String.isBlank(signature) || String.isBlank(appSecret)) {
                return false;
            }

            String expectedHash = signature;
            if (expectedHash.startsWith('sha256=')) {
                expectedHash = expectedHash.substringAfter('sha256=');
            }

            Blob hmac = Crypto.generateMac(
                'HmacSHA256',
                Blob.valueOf(payload),
                Blob.valueOf(appSecret)
            );
            String computedHash = EncodingUtil.convertToHex(hmac);

            return computedHash.equalsIgnoreCase(expectedHash);
        } catch (Exception e) {
            return false;
        }
    }

    public static Boolean validateFromRequest(RestRequest req, String appSecret) {
        try {
            if (req == null || String.isBlank(appSecret)) {
                return false;
            }

            String signatureHeader = req.headers.get('X-Hub-Signature-256');
            if (String.isBlank(signatureHeader)) {
                return false;
            }

            return validateSignature(req.requestBody.toString(), signatureHeader, appSecret);
        } catch (Exception e) {
            return false;
        }
    }
}