/**
 * @description Handler for Agentforce integration
 * Routes WhatsApp messages to Salesforce Agentforce and processes responses
 */
public with sharing class WhatsAppAgentforceHandler {

    /**
     * @description Process message through Agentforce asynchronously
     * @param conversationId WhatsApp Conversation ID
     * @param messageId WhatsApp Message ID
     */
    @future(callout=true)
    public static void processMessageAsync(String conversationId, String messageId) {
        try {
            WhatsApp_Message__c message = [
                SELECT Id, Content__c, Message_Type__c, Sender_Phone__c,
                       Conversation__r.Customer_Phone__c, Conversation__r.Contact__c,
                       Conversation__r.Case__c
                FROM WhatsApp_Message__c
                WHERE Id = :messageId
                LIMIT 1
            ];

            // Only process text messages for now
            if (message.Message_Type__c != 'Text' || String.isBlank(message.Content__c)) {
                return;
            }

            // Get or create Contact for this customer
            String contactId = getOrCreateContact(message.Sender_Phone__c, conversationId);

            // Get conversation context
            List<WhatsApp_Message__c> recentMessages = getRecentMessages(conversationId, 10);

            // Build context for Agentforce
            String context = buildConversationContext(recentMessages);

            // Call Agentforce (placeholder - actual implementation depends on your Agentforce setup)
            String agentResponse = callAgentforce(message.Content__c, context, contactId);

            // Send response back to WhatsApp
            if (String.isNotBlank(agentResponse)) {
                WhatsAppAPIService.sendTextMessage(
                    message.Conversation__r.Customer_Phone__c,
                    agentResponse,
                    conversationId
                );
            }

        } catch (Exception e) {
            System.debug('Error processing message with Agentforce: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }

    /**
     * @description Get or create Contact for customer
     */
    private static String getOrCreateContact(String phoneNumber, String conversationId) {
        // Try to find existing contact
        List<Contact> contacts = [
            SELECT Id
            FROM Contact
            WHERE Phone = :phoneNumber OR MobilePhone = :phoneNumber
            LIMIT 1
        ];

        if (!contacts.isEmpty()) {
            // Update conversation with Contact
            updateConversationContact(conversationId, contacts[0].Id);
            return contacts[0].Id;
        }

        // Create new contact
        Contact newContact = new Contact(
            FirstName = 'WhatsApp',
            LastName = 'Customer ' + phoneNumber.substring(phoneNumber.length() - 4),
            Phone = phoneNumber,
            Description = 'Created from WhatsApp conversation'
        );
        insert newContact;

        // Update conversation with Contact
        updateConversationContact(conversationId, newContact.Id);

        return newContact.Id;
    }

    /**
     * @description Update conversation with Contact reference
     */
    private static void updateConversationContact(String conversationId, String contactId) {
        WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(
            Id = conversationId,
            Contact__c = contactId
        );
        update conv;
    }

    /**
     * @description Get recent messages from conversation
     */
    private static List<WhatsApp_Message__c> getRecentMessages(String conversationId, Integer limitCount) {
        return [
            SELECT Id, Content__c, Direction__c, Timestamp__c, Sender_Phone__c
            FROM WhatsApp_Message__c
            WHERE Conversation__c = :conversationId
            AND Message_Type__c = 'Text'
            ORDER BY Timestamp__c DESC
            LIMIT :limitCount
        ];
    }

    /**
     * @description Build conversation context string for Agentforce
     */
    private static String buildConversationContext(List<WhatsApp_Message__c> messages) {
        List<String> contextMessages = new List<String>();

        // Reverse to get chronological order
        for (Integer i = messages.size() - 1; i >= 0; i--) {
            WhatsApp_Message__c msg = messages[i];
            String sender = msg.Direction__c == 'Inbound' ? 'Customer' : 'Agent';
            contextMessages.add(sender + ': ' + msg.Content__c);
        }

        return String.join(contextMessages, '\n');
    }

    /**
     * @description Call Agentforce API
     * This is a placeholder implementation. Actual implementation depends on your Agentforce setup.
     * You may need to use Einstein Bot API, Flow invocation, or other Salesforce AI APIs.
     */
    private static String callAgentforce(String userMessage, String context, String contactId) {
        try {
            // Option 1: Use Einstein Bot API (requires Bot setup)
            // Option 2: Use Flow invocation (requires Autolaunched Flow)
            // Option 3: Use Custom Apex logic with AI integration

            // Placeholder: Simple keyword-based responses
            // Replace this with actual Agentforce/Einstein Bot integration
            return getAutomatedResponse(userMessage);

        } catch (Exception e) {
            System.debug('Error calling Agentforce: ' + e.getMessage());
            return 'Thank you for your message. A representative will assist you shortly.';
        }
    }

    /**
     * @description Placeholder automated response logic
     * Replace this with actual Agentforce integration
     */
    private static String getAutomatedResponse(String userMessage) {
        String lowerMessage = userMessage.toLowerCase();

        if (lowerMessage.contains('hello') || lowerMessage.contains('hi')) {
            return 'Hello! How can I help you today?';
        } else if (lowerMessage.contains('help')) {
            return 'I\'m here to help! Please describe your issue and I\'ll do my best to assist you.';
        } else if (lowerMessage.contains('thank')) {
            return 'You\'re welcome! Is there anything else I can help you with?';
        } else if (lowerMessage.contains('bye')) {
            return 'Goodbye! Feel free to reach out anytime you need assistance.';
        } else {
            return 'I understand you need assistance. Let me help you with that. Could you provide more details?';
        }
    }

    /**
     * @description Create or link Case to conversation
     */
    @AuraEnabled
    public static String createCaseForConversation(String conversationId, String subject, String description) {
        try {
            WhatsApp_Conversation__c conv = [
                SELECT Id, Contact__c, Case__c
                FROM WhatsApp_Conversation__c
                WHERE Id = :conversationId
                LIMIT 1
            ];

            if (conv.Case__c != null) {
                return conv.Case__c;
            }

            Case newCase = new Case(
                Subject = subject,
                Description = description,
                ContactId = conv.Contact__c,
                Origin = 'WhatsApp',
                Status = 'New'
            );
            insert newCase;

            // Link case to conversation
            conv.Case__c = newCase.Id;
            update conv;

            return newCase.Id;

        } catch (Exception e) {
            throw new AuraHandledException('Error creating case: ' + e.getMessage());
        }
    }

    /**
     * @description Get conversation messages for display
     */
    @AuraEnabled(cacheable=true)
    public static List<WhatsApp_Message__c> getConversationMessages(String conversationId) {
        try {
            return [
                SELECT Id, Content__c, Direction__c, Message_Type__c,
                       Timestamp__c, Message_Status__c, Sender_Phone__c,
                       Recipient_Phone__c, Latitude__c, Longitude__c,
                       (SELECT Id, Media_Type__c, File_Name__c, Download_Status__c
                        FROM WhatsApp_Media__r)
                FROM WhatsApp_Message__c
                WHERE Conversation__c = :conversationId
                ORDER BY Timestamp__c ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving messages: ' + e.getMessage());
        }
    }
}
