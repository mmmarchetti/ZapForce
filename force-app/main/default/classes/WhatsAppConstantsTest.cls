@isTest
private class WhatsAppConstantsTest {

    @isTest
    static void testApiConfigurationConstants() {
        System.assertEquals('v21.0', WhatsAppConstants.API_VERSION,
            'API_VERSION should be v21.0');
        System.assertEquals('https://graph.facebook.com', WhatsAppConstants.GRAPH_API_BASE,
            'GRAPH_API_BASE should be the Facebook Graph API URL');
        System.assertEquals('whatsapp', WhatsAppConstants.MESSAGE_PRODUCT,
            'MESSAGE_PRODUCT should be whatsapp');
        System.assertEquals('individual', WhatsAppConstants.RECIPIENT_TYPE,
            'RECIPIENT_TYPE should be individual');
    }

    @isTest
    static void testMessageDirectionConstants() {
        System.assertEquals('Inbound', WhatsAppConstants.DIRECTION_INBOUND);
        System.assertEquals('Outbound', WhatsAppConstants.DIRECTION_OUTBOUND);
    }

    @isTest
    static void testMessageTypeConstants() {
        System.assertEquals('text', WhatsAppConstants.TYPE_TEXT);
        System.assertEquals('image', WhatsAppConstants.TYPE_IMAGE);
        System.assertEquals('video', WhatsAppConstants.TYPE_VIDEO);
        System.assertEquals('audio', WhatsAppConstants.TYPE_AUDIO);
        System.assertEquals('document', WhatsAppConstants.TYPE_DOCUMENT);
        System.assertEquals('location', WhatsAppConstants.TYPE_LOCATION);
        System.assertEquals('interactive', WhatsAppConstants.TYPE_INTERACTIVE);
        System.assertEquals('template', WhatsAppConstants.TYPE_TEMPLATE);
        System.assertEquals('reaction', WhatsAppConstants.TYPE_REACTION);
        System.assertEquals('sticker', WhatsAppConstants.TYPE_STICKER);
        System.assertEquals('contacts', WhatsAppConstants.TYPE_CONTACTS);
        System.assertEquals('system', WhatsAppConstants.TYPE_SYSTEM);
        System.assertEquals('contact', WhatsAppConstants.TYPE_CONTACT);
    }

    @isTest
    static void testMessageStatusConstants() {
        System.assertEquals('Sent', WhatsAppConstants.STATUS_SENT);
        System.assertEquals('Delivered', WhatsAppConstants.STATUS_DELIVERED);
        System.assertEquals('Read', WhatsAppConstants.STATUS_READ);
        System.assertEquals('Failed', WhatsAppConstants.STATUS_FAILED);
        System.assertEquals('Received', WhatsAppConstants.STATUS_RECEIVED);
        System.assertEquals('Pending', WhatsAppConstants.STATUS_PENDING);
    }

    @isTest
    static void testConversationStatusConstants() {
        System.assertEquals('Active', WhatsAppConstants.CONV_STATUS_ACTIVE);
        System.assertEquals('Idle', WhatsAppConstants.CONV_STATUS_IDLE);
        System.assertEquals('Closed', WhatsAppConstants.CONV_STATUS_CLOSED);
    }

    @isTest
    static void testDownloadStatusConstants() {
        System.assertEquals('Pending', WhatsAppConstants.DOWNLOAD_PENDING);
        System.assertEquals('Downloading', WhatsAppConstants.DOWNLOAD_DOWNLOADING);
        System.assertEquals('Completed', WhatsAppConstants.DOWNLOAD_COMPLETED);
        System.assertEquals('Failed', WhatsAppConstants.DOWNLOAD_FAILED);
    }

    @isTest
    static void testErrorTypeConstants() {
        System.assertEquals('API_ERROR', WhatsAppConstants.ERROR_API);
        System.assertEquals('WEBHOOK_ERROR', WhatsAppConstants.ERROR_WEBHOOK);
        System.assertEquals('MEDIA_ERROR', WhatsAppConstants.ERROR_MEDIA);
        System.assertEquals('AGENTFORCE_ERROR', WhatsAppConstants.ERROR_AGENTFORCE);
        System.assertEquals('VALIDATION_ERROR', WhatsAppConstants.ERROR_VALIDATION);
    }

    @isTest
    static void testApiPathConstants() {
        System.assertEquals('/messages', WhatsAppConstants.PATH_MESSAGES);
        System.assertEquals('/media', WhatsAppConstants.PATH_MEDIA);
        System.assertEquals('/message_templates', WhatsAppConstants.PATH_TEMPLATES);
    }

    @isTest
    static void testInteractiveTypeConstants() {
        System.assertEquals('button_reply', WhatsAppConstants.INTERACTIVE_BUTTON_REPLY);
        System.assertEquals('list_reply', WhatsAppConstants.INTERACTIVE_LIST_REPLY);
        System.assertEquals('cta_url', WhatsAppConstants.INTERACTIVE_CTA_URL);
        System.assertEquals('flow', WhatsAppConstants.INTERACTIVE_FLOW);
    }

    @isTest
    static void testDefaultTimeouts() {
        System.assertEquals(60000, WhatsAppConstants.DEFAULT_TIMEOUT);
        System.assertEquals(1440, WhatsAppConstants.DEFAULT_SESSION_TIMEOUT_MINUTES);
    }

    @isTest
    static void testSecurityConstants() {
        System.assertEquals('HmacSHA256', WhatsAppConstants.HMAC_ALGORITHM);
    }

    @isTest
    static void testWebhookConstants() {
        System.assertEquals('subscribe', WhatsAppConstants.WEBHOOK_MODE_SUBSCRIBE);
    }

    @isTest
    static void testTemplateConstants() {
        System.assertEquals('MARKETING', WhatsAppConstants.TEMPLATE_MARKETING);
        System.assertEquals('UTILITY', WhatsAppConstants.TEMPLATE_UTILITY);
        System.assertEquals('AUTHENTICATION', WhatsAppConstants.TEMPLATE_AUTHENTICATION);
        System.assertEquals('APPROVED', WhatsAppConstants.TEMPLATE_APPROVED);
        System.assertEquals('PENDING', WhatsAppConstants.TEMPLATE_PENDING);
        System.assertEquals('REJECTED', WhatsAppConstants.TEMPLATE_REJECTED);
    }

    @isTest
    static void testMediaTypeConstants() {
        System.assertEquals('image', WhatsAppConstants.MEDIA_IMAGE);
        System.assertEquals('video', WhatsAppConstants.MEDIA_VIDEO);
        System.assertEquals('audio', WhatsAppConstants.MEDIA_AUDIO);
        System.assertEquals('document', WhatsAppConstants.MEDIA_DOCUMENT);
        System.assertEquals('sticker', WhatsAppConstants.MEDIA_STICKER);
    }

    @isTest
    static void testOriginConstants() {
        System.assertEquals('user_initiated', WhatsAppConstants.ORIGIN_USER_INITIATED);
        System.assertEquals('business_initiated', WhatsAppConstants.ORIGIN_BUSINESS_INITIATED);
        System.assertEquals('referral', WhatsAppConstants.ORIGIN_REFERRAL);
    }
}