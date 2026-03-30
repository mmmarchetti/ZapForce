// Test Script: Simulate a WhatsApp webhook payload being processed
// This tests the parsing and message creation pipeline without a real WhatsApp connection
// Run with: sf apex run --file scripts/apex/test-webhook-simulation.apex --target-org WhatsAppSF

// Simulate a WhatsApp webhook JSON payload (same format Meta sends)
String webhookJson = '{' +
    '"object": "whatsapp_business_account",' +
    '"entry": [{' +
        '"id": "TEST_WABA_ID",' +
        '"changes": [{' +
            '"value": {' +
                '"messaging_product": "whatsapp",' +
                '"metadata": {' +
                    '"display_phone_number": "5511970934419",' +
                    '"phone_number_id": "TEST_PHONE_ID"' +
                '},' +
                '"contacts": [{' +
                    '"profile": {"name": "Joao Santos (Simulated)"},' +
                    '"wa_id": "5511988776655"' +
                '}],' +
                '"messages": [{' +
                    '"from": "5511988776655",' +
                    '"id": "wamid.simulated_' + Datetime.now().getTime() + '",' +
                    '"timestamp": "' + String.valueOf(Datetime.now().getTime() / 1000) + '",' +
                    '"text": {"body": "Oi, preciso de ajuda com meu pedido #12345"},' +
                    '"type": "text"' +
                '}]' +
            '},' +
            '"field": "messages"' +
        '}]' +
    '}]' +
'}';

System.debug('=== Simulating WhatsApp Webhook ===');
System.debug('Payload: ' + webhookJson);

// Parse the webhook
WhatsAppWebhookParser.WebhookPayload payload = WhatsAppWebhookParser.parse(webhookJson);

if (payload != null) {
    System.debug('Parsed successfully');
    System.debug('Object type: ' + payload.objectType);

    List<WhatsAppWebhookParser.ParsedMessage> messages = WhatsAppWebhookParser.extractMessages(payload);
    System.debug('Messages found: ' + messages.size());

    for (WhatsAppWebhookParser.ParsedMessage msg : messages) {
        System.debug('  From: ' + msg.from_field);
        System.debug('  Type: ' + msg.type);
        System.debug('  Text: ' + (msg.text != null ? msg.text.body : 'null'));
        System.debug('  Customer Name: ' + msg.customerName);

        // Create the conversation
        String conversationId = WhatsAppConversationService.findOrCreateConversation(
            msg.from_field,
            msg.customerName
        );
        System.debug('  Conversation ID: ' + conversationId);

        // Create the message record
        WhatsApp_Message__c newMsg = WhatsAppMessageService.createInboundMessage(
            msg,
            conversationId,
            '5511970934419'
        );
        System.debug('  Message record created: ' + newMsg.Id);
        System.debug('  Content: ' + newMsg.Content__c);
    }

    System.debug('=== Webhook simulation complete ===');
    System.debug('Open the WhatsApp Dashboard to see the new conversation');
} else {
    System.debug('ERROR: Failed to parse webhook payload');
}
