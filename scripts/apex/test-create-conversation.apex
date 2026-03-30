// Test Script: Create a sample conversation with messages
// Uses dynamic SOQL/DML to work around anonymous Apex schema cache issues
// Run with: sf apex run --file scripts/apex/test-create-conversation.apex --target-org WhatsAppSF

// 1. Create configuration using dynamic DML
SObject config = (SObject) Type.forName('WhatsApp_Configuration__c').newInstance();
config.put('API_Key__c', 'TEST_API_KEY_PLACEHOLDER');
config.put('Phone_Number__c', '+5511970934419');
config.put('API_Base_URL__c', 'https://graph.facebook.com');
// Use Database.insert for partial success
Database.SaveResult sr = Database.insert(config, false);
if (sr.isSuccess()) {
    System.debug('Created configuration: ' + config.Id);
} else {
    System.debug('Config insert error (may already exist): ' + sr.getErrors()[0].getMessage());
    // Try to find existing config
    List<WhatsApp_Configuration__c> existing = [SELECT Id FROM WhatsApp_Configuration__c LIMIT 1];
    if (!existing.isEmpty()) {
        System.debug('Using existing config: ' + existing[0].Id);
    }
}

// 2. Create a test conversation
WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(
    Customer_Phone__c = '+5511999887766',
    Status__c = 'Active',
    Message_Count__c = 0
);
insert conv;
System.debug('Created conversation: ' + conv.Id);

// 3. Create sample messages
List<WhatsApp_Message__c> messages = new List<WhatsApp_Message__c>();

// Customer greeting
messages.add(new WhatsApp_Message__c(
    Conversation__c = conv.Id,
    Message_ID__c = 'wamid.test_' + Datetime.now().getTime() + '_1',
    Sender_Phone__c = '+5511999887766',
    Recipient_Phone__c = '+5511970934419',
    Direction__c = 'Inbound',
    Message_Status__c = 'Received',
    Message_Type__c = 'Text',
    Content__c = 'Ola! Gostaria de saber sobre os produtos disponiveis.',
    Timestamp__c = Datetime.now().addMinutes(-5)
));

// Agent response
messages.add(new WhatsApp_Message__c(
    Conversation__c = conv.Id,
    Message_ID__c = 'wamid.test_' + Datetime.now().getTime() + '_2',
    Sender_Phone__c = '+5511970934419',
    Recipient_Phone__c = '+5511999887766',
    Direction__c = 'Outbound',
    Message_Status__c = 'Sent',
    Message_Type__c = 'Text',
    Content__c = 'Ola! Bem-vinda ao nosso atendimento. Como posso ajudar?',
    Timestamp__c = Datetime.now().addMinutes(-4)
));

// Location message
messages.add(new WhatsApp_Message__c(
    Conversation__c = conv.Id,
    Message_ID__c = 'wamid.test_' + Datetime.now().getTime() + '_3',
    Sender_Phone__c = '+5511999887766',
    Recipient_Phone__c = '+5511970934419',
    Direction__c = 'Inbound',
    Message_Status__c = 'Received',
    Message_Type__c = 'Location',
    Latitude__c = -23.5505,
    Longitude__c = -46.6333,
    Timestamp__c = Datetime.now().addMinutes(-3)
));

// Customer follow-up
messages.add(new WhatsApp_Message__c(
    Conversation__c = conv.Id,
    Message_ID__c = 'wamid.test_' + Datetime.now().getTime() + '_4',
    Sender_Phone__c = '+5511999887766',
    Recipient_Phone__c = '+5511970934419',
    Direction__c = 'Inbound',
    Message_Status__c = 'Received',
    Message_Type__c = 'Text',
    Content__c = 'Estou perto dessa localizacao. Voces tem loja fisica?',
    Timestamp__c = Datetime.now().addMinutes(-2)
));

// Agent response (from Agentforce)
messages.add(new WhatsApp_Message__c(
    Conversation__c = conv.Id,
    Message_ID__c = 'wamid.test_' + Datetime.now().getTime() + '_5',
    Sender_Phone__c = '+5511970934419',
    Recipient_Phone__c = '+5511999887766',
    Direction__c = 'Outbound',
    Message_Status__c = 'Delivered',
    Message_Type__c = 'Text',
    Content__c = 'Sim! Nossa loja fica na Av. Paulista, 1500. Funciona de segunda a sabado das 9h as 18h.',
    Timestamp__c = Datetime.now().addMinutes(-1)
));

insert messages;
conv.Message_Count__c = messages.size();
update conv;

System.debug('Created ' + messages.size() + ' test messages');
System.debug('SUCCESS - Open the WhatsApp Dashboard in Salesforce to see the conversation');
System.debug('Conversation ID: ' + conv.Id);
