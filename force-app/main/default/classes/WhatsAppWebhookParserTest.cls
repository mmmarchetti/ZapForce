@isTest
private class WhatsAppWebhookParserTest {

    // ── JSON payload helpers ────────────────────────────────────────────

    private static String getTextMessageJson() {
        return '{"object":"whatsapp_business_account","entry":[{"id":"123","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"15551234567","phone_number_id":"123456"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"5511999999999"}],"messages":[{"from":"5511999999999","id":"wamid.abc123","timestamp":"1234567890","type":"text","text":{"body":"Hello"}}]},"field":"messages"}]}]}';
    }

    private static String getImageMessageJson() {
        return '{"object":"whatsapp_business_account","entry":[{"id":"123","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"15551234567","phone_number_id":"123456"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"5511999999999"}],"messages":[{"from":"5511999999999","id":"wamid.img456","timestamp":"1234567891","type":"image","image":{"id":"media-id-001","mime_type":"image/jpeg","sha256":"abc123hash","caption":"Check this out"}}]},"field":"messages"}]}]}';
    }

    private static String getLocationMessageJson() {
        return '{"object":"whatsapp_business_account","entry":[{"id":"123","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"15551234567","phone_number_id":"123456"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"5511999999999"}],"messages":[{"from":"5511999999999","id":"wamid.loc789","timestamp":"1234567892","type":"location","location":{"latitude":-23.5505,"longitude":-46.6333,"name":"Sao Paulo","address":"Av Paulista, 1000"}}]},"field":"messages"}]}]}';
    }

    private static String getReactionMessageJson() {
        return '{"object":"whatsapp_business_account","entry":[{"id":"123","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"15551234567","phone_number_id":"123456"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"5511999999999"}],"messages":[{"from":"5511999999999","id":"wamid.react001","timestamp":"1234567893","type":"reaction","reaction":{"message_id":"wamid.abc123","emoji":"\\ud83d\\udc4d"}}]},"field":"messages"}]}]}';
    }

    private static String getInteractiveButtonReplyJson() {
        return '{"object":"whatsapp_business_account","entry":[{"id":"123","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"15551234567","phone_number_id":"123456"},"contacts":[{"profile":{"name":"Test User"},"wa_id":"5511999999999"}],"messages":[{"from":"5511999999999","id":"wamid.btn001","timestamp":"1234567894","type":"interactive","interactive":{"type":"button_reply","button_reply":{"id":"btn-yes","title":"Yes"}}}]},"field":"messages"}]}]}';
    }

    private static String getStatusUpdateJson() {
        return '{"object":"whatsapp_business_account","entry":[{"id":"123","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"15551234567","phone_number_id":"123456"},"statuses":[{"id":"wamid.abc123","status":"delivered","timestamp":"1234567895","recipient_id":"5511999999999","pricing":{"pricing_model":"CBP","category":"business_initiated","billable":true}}]},"field":"messages"}]}]}';
    }

    // ── Test methods ────────────────────────────────────────────────────

    @isTest
    static void testParseTextMessage() {
        Test.startTest();
        WhatsAppWebhookParser.WebhookPayload payload = WhatsAppWebhookParser.parse(getTextMessageJson());
        Test.stopTest();

        System.assertNotEquals(null, payload);
        System.assertEquals(1, payload.entries.size());

        WhatsAppWebhookParser.WebhookEntry entry = payload.entries[0];
        System.assertEquals('123', entry.id);
        System.assertEquals(1, entry.changes.size());

        WhatsAppWebhookParser.WebhookChange change = entry.changes[0];
        System.assertEquals('messages', change.field);
        System.assertEquals('whatsapp', change.value.messagingProduct);

        // Metadata
        System.assertEquals('15551234567', change.value.metadata.displayPhoneNumber);
        System.assertEquals('123456', change.value.metadata.phoneNumberId);

        // Contacts
        System.assertEquals(1, change.value.contacts.size());
        System.assertEquals('5511999999999', change.value.contacts[0].waId);
        System.assertEquals('Test User', change.value.contacts[0].profile.name);

        // Messages
        System.assertEquals(1, change.value.messages.size());
        WhatsAppWebhookParser.ParsedMessage msg = change.value.messages[0];
        System.assertEquals('wamid.abc123', msg.id);
        System.assertEquals('5511999999999', msg.from_field);
        System.assertEquals('1234567890', msg.timestamp);
        System.assertEquals('text', msg.type);
        System.assertEquals('Hello', msg.text.body);
        System.assertEquals(false, msg.isForwarded);
    }

    @isTest
    static void testParseImageMessage() {
        Test.startTest();
        WhatsAppWebhookParser.WebhookPayload payload = WhatsAppWebhookParser.parse(getImageMessageJson());
        Test.stopTest();

        List<WhatsAppWebhookParser.ParsedMessage> messages = WhatsAppWebhookParser.extractMessages(payload);
        System.assertEquals(1, messages.size());

        WhatsAppWebhookParser.ParsedMessage msg = messages[0];
        System.assertEquals('image', msg.type);
        System.assertEquals('wamid.img456', msg.id);
        System.assertNotEquals(null, msg.image);
        System.assertEquals('media-id-001', msg.image.id);
        System.assertEquals('image/jpeg', msg.image.mimeType);
        System.assertEquals('abc123hash', msg.image.sha256);
        System.assertEquals('Check this out', msg.image.caption);
    }

    @isTest
    static void testParseLocationMessage() {
        Test.startTest();
        WhatsAppWebhookParser.WebhookPayload payload = WhatsAppWebhookParser.parse(getLocationMessageJson());
        Test.stopTest();

        List<WhatsAppWebhookParser.ParsedMessage> messages = WhatsAppWebhookParser.extractMessages(payload);
        System.assertEquals(1, messages.size());

        WhatsAppWebhookParser.ParsedMessage msg = messages[0];
        System.assertEquals('location', msg.type);
        System.assertNotEquals(null, msg.location);
        System.assertEquals(-23.5505, msg.location.latitude);
        System.assertEquals(-46.6333, msg.location.longitude);
        System.assertEquals('Sao Paulo', msg.location.name);
        System.assertEquals('Av Paulista, 1000', msg.location.address);
    }

    @isTest
    static void testParseReactionMessage() {
        Test.startTest();
        WhatsAppWebhookParser.WebhookPayload payload = WhatsAppWebhookParser.parse(getReactionMessageJson());
        Test.stopTest();

        List<WhatsAppWebhookParser.ParsedMessage> messages = WhatsAppWebhookParser.extractMessages(payload);
        System.assertEquals(1, messages.size());

        WhatsAppWebhookParser.ParsedMessage msg = messages[0];
        System.assertEquals('reaction', msg.type);
        System.assertNotEquals(null, msg.reaction);
        System.assertEquals('wamid.abc123', msg.reaction.messageId);
        System.assertNotEquals(null, msg.reaction.emoji);
    }

    @isTest
    static void testParseInteractiveButtonReply() {
        Test.startTest();
        WhatsAppWebhookParser.WebhookPayload payload = WhatsAppWebhookParser.parse(getInteractiveButtonReplyJson());
        Test.stopTest();

        List<WhatsAppWebhookParser.ParsedMessage> messages = WhatsAppWebhookParser.extractMessages(payload);
        System.assertEquals(1, messages.size());

        WhatsAppWebhookParser.ParsedMessage msg = messages[0];
        System.assertEquals('interactive', msg.type);
        System.assertNotEquals(null, msg.interactive);
        System.assertEquals('button_reply', msg.interactive.type);
        System.assertNotEquals(null, msg.interactive.buttonReply);
        System.assertEquals('btn-yes', msg.interactive.buttonReply.id);
        System.assertEquals('Yes', msg.interactive.buttonReply.title);
    }

    @isTest
    static void testParseStatusUpdate() {
        Test.startTest();
        WhatsAppWebhookParser.WebhookPayload payload = WhatsAppWebhookParser.parse(getStatusUpdateJson());
        Test.stopTest();

        System.assertNotEquals(null, payload);

        // No messages in status update
        List<WhatsAppWebhookParser.ParsedMessage> messages = WhatsAppWebhookParser.extractMessages(payload);
        System.assertEquals(0, messages.size());

        // Statuses should be present
        List<WhatsAppWebhookParser.StatusUpdate> statuses = WhatsAppWebhookParser.extractStatuses(payload);
        System.assertEquals(1, statuses.size());

        WhatsAppWebhookParser.StatusUpdate status = statuses[0];
        System.assertEquals('wamid.abc123', status.id);
        System.assertEquals('delivered', status.status);
        System.assertEquals('1234567895', status.timestamp);
        System.assertEquals('5511999999999', status.recipientId);
        System.assertNotEquals(null, status.pricing);
        System.assertEquals('CBP', status.pricing.pricingModel);
        System.assertEquals('business_initiated', status.pricing.category);
        System.assertEquals(true, status.pricing.billable);
    }

    @isTest
    static void testParseNullBodyReturnsNull() {
        Test.startTest();
        WhatsAppWebhookParser.WebhookPayload result = WhatsAppWebhookParser.parse(null);
        Test.stopTest();

        System.assertEquals(null, result, 'Null body should return null');
    }

    @isTest
    static void testParseEmptyBodyReturnsNull() {
        Test.startTest();
        WhatsAppWebhookParser.WebhookPayload result = WhatsAppWebhookParser.parse('');
        Test.stopTest();

        System.assertEquals(null, result, 'Empty body should return null');
    }

    @isTest
    static void testParseBlankBodyReturnsNull() {
        Test.startTest();
        WhatsAppWebhookParser.WebhookPayload result = WhatsAppWebhookParser.parse('   ');
        Test.stopTest();

        System.assertEquals(null, result, 'Blank body should return null');
    }

    @isTest
    static void testExtractMessagesFlattensCorrectly() {
        // Build a payload with two entries, each with one message
        String json = '{"object":"whatsapp_business_account","entry":['
            + '{"id":"e1","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"15551234567","phone_number_id":"123456"},"messages":[{"from":"5511999999999","id":"wamid.m1","timestamp":"1234567890","type":"text","text":{"body":"First"}}]},"field":"messages"}]}'
            + ','
            + '{"id":"e2","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"15551234567","phone_number_id":"123456"},"messages":[{"from":"5511999999999","id":"wamid.m2","timestamp":"1234567891","type":"text","text":{"body":"Second"}}]},"field":"messages"}]}'
            + ']}';

        Test.startTest();
        WhatsAppWebhookParser.WebhookPayload payload = WhatsAppWebhookParser.parse(json);
        List<WhatsAppWebhookParser.ParsedMessage> messages = WhatsAppWebhookParser.extractMessages(payload);
        Test.stopTest();

        System.assertEquals(2, messages.size(), 'Should flatten messages from all entries');
        System.assertEquals('wamid.m1', messages[0].id);
        System.assertEquals('wamid.m2', messages[1].id);
    }

    @isTest
    static void testExtractStatusesFlattensCorrectly() {
        String json = '{"object":"whatsapp_business_account","entry":['
            + '{"id":"e1","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"15551234567","phone_number_id":"123456"},"statuses":[{"id":"wamid.s1","status":"sent","timestamp":"1234567890","recipient_id":"5511999999999"}]},"field":"messages"}]}'
            + ','
            + '{"id":"e2","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"15551234567","phone_number_id":"123456"},"statuses":[{"id":"wamid.s2","status":"delivered","timestamp":"1234567891","recipient_id":"5511999999999"}]},"field":"messages"}]}'
            + ']}';

        Test.startTest();
        WhatsAppWebhookParser.WebhookPayload payload = WhatsAppWebhookParser.parse(json);
        List<WhatsAppWebhookParser.StatusUpdate> statuses = WhatsAppWebhookParser.extractStatuses(payload);
        Test.stopTest();

        System.assertEquals(2, statuses.size(), 'Should flatten statuses from all entries');
        System.assertEquals('wamid.s1', statuses[0].id);
        System.assertEquals('sent', statuses[0].status);
        System.assertEquals('wamid.s2', statuses[1].id);
        System.assertEquals('delivered', statuses[1].status);
    }

    @isTest
    static void testExtractMessagesWithNullPayload() {
        Test.startTest();
        List<WhatsAppWebhookParser.ParsedMessage> messages = WhatsAppWebhookParser.extractMessages(null);
        Test.stopTest();

        System.assertNotEquals(null, messages);
        System.assertEquals(0, messages.size(), 'Null payload should return empty list');
    }

    @isTest
    static void testExtractStatusesWithNullPayload() {
        Test.startTest();
        List<WhatsAppWebhookParser.StatusUpdate> statuses = WhatsAppWebhookParser.extractStatuses(null);
        Test.stopTest();

        System.assertNotEquals(null, statuses);
        System.assertEquals(0, statuses.size(), 'Null payload should return empty list');
    }

    @isTest
    static void testParsePayloadWithNoEntries() {
        String json = '{"object":"whatsapp_business_account"}';

        Test.startTest();
        WhatsAppWebhookParser.WebhookPayload payload = WhatsAppWebhookParser.parse(json);
        Test.stopTest();

        System.assertNotEquals(null, payload);
        System.assertEquals(0, payload.entries.size(),
            'Payload with no entry array should have empty entries');
    }

    @isTest
    static void testParsedMessageRawJsonPopulated() {
        Test.startTest();
        WhatsAppWebhookParser.WebhookPayload payload = WhatsAppWebhookParser.parse(getTextMessageJson());
        Test.stopTest();

        List<WhatsAppWebhookParser.ParsedMessage> messages = WhatsAppWebhookParser.extractMessages(payload);
        System.assertNotEquals(null, messages[0].rawJson,
            'rawJson should be populated on parsed messages');
        System.assert(messages[0].rawJson.contains('wamid.abc123'),
            'rawJson should contain the message ID');
    }
}