/**
 * @description Service class for Agentforce integration.
 *              Handles routing WhatsApp messages to Salesforce Agentforce,
 *              managing conversation sessions, and processing AI responses.
 */
public with sharing class WhatsAppAgentforceService {

    /**
     * @description Process an inbound WhatsApp message through Agentforce.
     *              Finds or creates a contact, builds conversation context,
     *              and routes to the configured Agentforce agent.
     * @param conversationId The WhatsApp_Conversation__c record ID
     * @param messageId The WhatsApp_Message__c record ID
     */
    public static void processMessage(Id conversationId, Id messageId) {
        try {
            WhatsApp_Message__c message = [
                SELECT Id, Content__c, Message_Type__c, Sender_Phone__c,
                       Conversation__r.Customer_Phone__c, Conversation__r.Contact__c,
                       Conversation__r.Case__c, Conversation__r.Agentforce_Session_Id__c,
                       Conversation__r.Customer_Name__c
                FROM WhatsApp_Message__c
                WHERE Id = :messageId
                LIMIT 1
            ];

            // Only process text and interactive messages for Agentforce
            if (message.Message_Type__c != 'Text' &&
                message.Message_Type__c != 'Interactive' &&
                message.Message_Type__c != 'Location') {
                // For media messages, send acknowledgment
                if (isMediaType(message.Message_Type__c)) {
                    sendMediaAcknowledgment(conversationId, message.Conversation__r.Customer_Phone__c);
                }
                return;
            }

            // Get or create Contact
            Id contactId = getOrCreateContact(
                message.Sender_Phone__c,
                message.Conversation__r.Customer_Name__c,
                conversationId
            );

            // Build conversation context from recent messages
            String conversationContext = buildConversationContext(conversationId);

            // Build the user input string
            String userInput = buildUserInput(message);

            // Route to Agentforce
            String agentResponse = routeToAgentforce(
                userInput,
                conversationContext,
                contactId,
                conversationId,
                message.Conversation__r.Agentforce_Session_Id__c
            );

            // Send response back via WhatsApp
            if (String.isNotBlank(agentResponse)) {
                String waMessageId = WhatsAppAPIService.sendTextMessage(
                    message.Conversation__r.Customer_Phone__c,
                    agentResponse
                );

                // Record the outbound message
                if (String.isNotBlank(waMessageId)) {
                    WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();
                    WhatsApp_Message__c outMsg = WhatsAppMessageService.createOutboundMessage(
                        conversationId,
                        message.Conversation__r.Customer_Phone__c,
                        config.Phone_Number__c,
                        WhatsAppConstants.TYPE_TEXT,
                        agentResponse,
                        waMessageId
                    );
                    // Mark as from Agentforce
                    outMsg.Is_From_Agentforce__c = true;
                    update outMsg;

                    WhatsAppConversationService.updateConversationOnMessage(conversationId, false);
                }
            }

        } catch (Exception e) {
            WhatsAppErrorLogger.logAgentforceError(
                'Failed to process message through Agentforce', conversationId, e
            );
        }
    }

    /**
     * @description Route message to Agentforce using Invocable Action pattern.
     *              This integrates with Salesforce's Agent/Bot framework through
     *              the Messaging Session or via direct API if available.
     */
    private static String routeToAgentforce(String userInput, String context,
                                             Id contactId, Id conversationId,
                                             String sessionId) {
        try {
            WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();
            String agentId = config.Agentforce_Agent_Id__c;

            if (String.isBlank(agentId)) {
                // No Agentforce agent configured - use fallback
                return getFallbackResponse(userInput);
            }

            // Try to use the Agents Runtime API (available in API 62.0+)
            // If not available, fall back to Flow-based routing
            return invokeAgentRuntime(agentId, userInput, context, contactId, conversationId, sessionId);

        } catch (Exception e) {
            WhatsAppErrorLogger.logAgentforceError(
                'Agentforce routing failed', conversationId, e
            );
            return 'I apologize, but I\'m having trouble processing your request right now. A human agent will assist you shortly.';
        }
    }

    /**
     * @description Invoke the Agentforce Runtime API to get a response.
     *              Uses the Connect API for Agent invocation.
     */
    private static String invokeAgentRuntime(String agentId, String userInput,
                                              String context, Id contactId,
                                              Id conversationId, String sessionId) {
        try {
            // Build the request to the Agents Runtime API
            // POST /services/data/v62.0/einstein/agents/{agentId}/sessions
            // or POST /services/data/v62.0/einstein/agents/{agentId}/sessions/{sessionId}/messages

            WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();
            String baseUrl = URL.getOrgDomainUrl().toExternalForm();
            String apiVersion = 'v62.0'; // Agents API requires v62.0+

            // Create or continue session
            if (String.isBlank(sessionId)) {
                sessionId = createAgentSession(baseUrl, apiVersion, agentId);
                if (String.isNotBlank(sessionId)) {
                    // Save session ID to conversation
                    WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(
                        Id = conversationId,
                        Agentforce_Session_Id__c = sessionId
                    );
                    update conv;
                }
            }

            if (String.isBlank(sessionId)) {
                return getFallbackResponse(userInput);
            }

            // Send message to agent session
            String endpoint = baseUrl + '/services/data/' + apiVersion +
                             '/einstein/agents/' + agentId + '/sessions/' + sessionId + '/messages';

            Map<String, Object> requestBody = new Map<String, Object>{
                'message' => new Map<String, Object>{
                    'role' => 'EndUser',
                    'text' => userInput
                },
                'variables' => new List<Map<String, Object>>{
                    new Map<String, Object>{
                        'name' => 'ContactId',
                        'value' => contactId
                    },
                    new Map<String, Object>{
                        'name' => 'ConversationContext',
                        'value' => context
                    }
                }
            };

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(WhatsAppConstants.DEFAULT_TIMEOUT);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                return parseAgentResponse(res.getBody(), conversationId);
            } else {
                WhatsAppErrorLogger.logApiError(
                    String.valueOf(res.getStatusCode()),
                    'Agentforce API error',
                    JSON.serialize(requestBody),
                    res.getBody()
                );
                return getFallbackResponse(userInput);
            }

        } catch (Exception e) {
            WhatsAppErrorLogger.logAgentforceError(
                'Agent runtime invocation failed', conversationId, e
            );
            return getFallbackResponse(userInput);
        }
    }

    /**
     * @description Create a new Agentforce session
     */
    private static String createAgentSession(String baseUrl, String apiVersion, String agentId) {
        try {
            String endpoint = baseUrl + '/services/data/' + apiVersion +
                             '/einstein/agents/' + agentId + '/sessions';

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
            req.setBody('{}');
            req.setTimeout(WhatsAppConstants.DEFAULT_TIMEOUT);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (String) responseMap.get('sessionId');
            }
        } catch (Exception e) {
            System.debug('Failed to create agent session: ' + e.getMessage());
        }
        return null;
    }

    /**
     * @description Parse the response from Agentforce Runtime API
     */
    private static String parseAgentResponse(String responseBody, Id conversationId) {
        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

            // Extract the agent's text response
            List<Object> messages = (List<Object>) responseMap.get('messages');
            if (messages != null && !messages.isEmpty()) {
                List<String> responseParts = new List<String>();
                for (Object msgObj : messages) {
                    Map<String, Object> msg = (Map<String, Object>) msgObj;
                    String role = (String) msg.get('role');
                    if (role == 'Agent') {
                        String text = (String) msg.get('text');
                        if (String.isNotBlank(text)) {
                            responseParts.add(text);
                        }
                    }
                }
                if (!responseParts.isEmpty()) {
                    return String.join(responseParts, '\n');
                }
            }

            // Check for topic information
            String topic = (String) responseMap.get('topic');
            if (String.isNotBlank(topic)) {
                WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(
                    Id = conversationId,
                    Agentforce_Topic__c = topic
                );
                update conv;
            }

        } catch (Exception e) {
            WhatsAppErrorLogger.logAgentforceError(
                'Failed to parse agent response', conversationId, e
            );
        }
        return null;
    }

    /**
     * @description Get or create Contact for customer
     */
    public static Id getOrCreateContact(String phoneNumber, String customerName, Id conversationId) {
        List<Contact> contacts = [
            SELECT Id FROM Contact
            WHERE Phone = :phoneNumber OR MobilePhone = :phoneNumber
            LIMIT 1
        ];

        Id contactId;
        if (!contacts.isEmpty()) {
            contactId = contacts[0].Id;
        } else {
            String lastName = String.isNotBlank(customerName) ? customerName : 'WhatsApp User ' + phoneNumber.right(4);
            Contact newContact = new Contact(
                LastName = lastName,
                Phone = phoneNumber,
                Description = 'Created from WhatsApp conversation'
            );
            insert newContact;
            contactId = newContact.Id;
        }

        // Link contact to conversation if not already linked
        WhatsApp_Conversation__c conv = [
            SELECT Id, Contact__c FROM WhatsApp_Conversation__c WHERE Id = :conversationId LIMIT 1
        ];
        if (conv.Contact__c == null) {
            conv.Contact__c = contactId;
            update conv;
        }

        return contactId;
    }

    /**
     * @description Build conversation context string from recent messages
     */
    private static String buildConversationContext(Id conversationId) {
        List<WhatsApp_Message__c> messages = [
            SELECT Content__c, Direction__c, Message_Type__c, Timestamp__c
            FROM WhatsApp_Message__c
            WHERE Conversation__c = :conversationId
            AND Message_Type__c = 'Text'
            ORDER BY Timestamp__c DESC
            LIMIT 20
        ];

        List<String> contextLines = new List<String>();
        for (Integer i = messages.size() - 1; i >= 0; i--) {
            WhatsApp_Message__c msg = messages[i];
            String role = msg.Direction__c == WhatsAppConstants.DIRECTION_INBOUND ? 'Customer' : 'Agent';
            contextLines.add(role + ': ' + msg.Content__c);
        }

        return String.join(contextLines, '\n');
    }

    /**
     * @description Build user input string from message
     */
    private static String buildUserInput(WhatsApp_Message__c message) {
        if (message.Message_Type__c == 'Text') {
            return message.Content__c;
        } else if (message.Message_Type__c == 'Interactive') {
            return 'User selected: ' + message.Content__c;
        } else if (message.Message_Type__c == 'Location') {
            return 'User shared location: ' + message.Content__c;
        }
        return message.Content__c;
    }

    private static Boolean isMediaType(String messageType) {
        Set<String> mediaTypes = new Set<String>{'Image', 'Video', 'Audio', 'Document', 'Sticker'};
        return mediaTypes.contains(messageType);
    }

    private static void sendMediaAcknowledgment(Id conversationId, String customerPhone) {
        // Acknowledge media receipt silently - no response needed unless configured
    }

    /**
     * @description Fallback response when Agentforce is not configured or unavailable
     */
    private static String getFallbackResponse(String userInput) {
        String lower = userInput.toLowerCase();
        if (lower.contains('hello') || lower.contains('hi') || lower.contains('hey')) {
            return 'Hello! Welcome to our support. How can I help you today?';
        } else if (lower.contains('help')) {
            return 'I\'m here to help! Please describe what you need assistance with.';
        } else if (lower.contains('thank')) {
            return 'You\'re welcome! Is there anything else I can help you with?';
        } else if (lower.contains('bye') || lower.contains('goodbye')) {
            return 'Goodbye! Feel free to reach out anytime.';
        }
        return 'Thank you for your message. Let me look into that for you. Could you provide more details?';
    }
}
