/**
 * @description Service class for Agentforce integration.
 *              Handles routing WhatsApp messages to Salesforce Agentforce,
 *              managing conversation sessions, and processing AI responses.
 */
public with sharing class WhatsAppAgentforceService {

    /** Agent API base URL */
    private static final String AGENT_API_BASE = 'https://api.salesforce.com/einstein/ai-agent/v1';

    /** Sequence counter for agent messages within a session */
    private static Integer sequenceCounter = 0;

    /** Holds the session ID from the most recent session creation (for deferred save) */
    private static String pendingSessionId;

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
                       Latitude__c, Longitude__c, Location_Name__c, Location_Address__c,
                       Conversation__r.Customer_Phone__c, Conversation__r.Contact__c,
                       Conversation__r.Case__c, Conversation__r.Agentforce_Session_Id__c,
                       Conversation__r.Customer_Name__c
                FROM WhatsApp_Message__c
                WHERE Id = :messageId
                LIMIT 1
            ];

            // Only process text, interactive, and location messages for Agentforce
            // Image messages are handled by WhatsAppMediaTrigger → WhatsAppImageAnalysisQueueable
            if (message.Message_Type__c != 'Text' &&
                message.Message_Type__c != 'Interactive' &&
                message.Message_Type__c != 'Location') {
                // For media messages, send acknowledgment
                if (isMediaType(message.Message_Type__c)) {
                    sendMediaAcknowledgment(conversationId, message.Conversation__r.Customer_Phone__c);
                }
                return;
            }

            // Avoid DML before callouts: use existing contact only during routing.
            Id contactId = getContactIdForRouting(
                message.Sender_Phone__c,
                message.Conversation__r.Contact__c
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
                String waMessageId;
                try {
                    waMessageId = WhatsAppAPIService.sendTextMessage(
                        message.Conversation__r.Customer_Phone__c,
                        agentResponse
                    );
                } catch (Exception sendEx) {
                    System.debug('AGENTFORCE_WHATSAPP_SEND_ERROR: ' + sendEx.getMessage());
                }

                // Always save session ID after all callouts complete (even if WhatsApp send failed)
                if (String.isNotBlank(pendingSessionId)) {
                    WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(
                        Id = conversationId,
                        Agentforce_Session_Id__c = pendingSessionId
                    );
                    update conv;
                    pendingSessionId = null;
                }

                // Record the outbound message if WhatsApp send succeeded
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
                    outMsg.Is_From_Agentforce__c = true;
                    update outMsg;

                    WhatsAppConversationService.updateConversationOnMessage(conversationId, false);
                    WhatsAppLogService.logInfo(
                        'AGENTFORCE_RESPONSE_SENT_TO_WHATSAPP',
                        'WhatsAppAgentforceService.processMessage',
                        'Sent Agentforce response back to customer. waMessageId=' + waMessageId
                    );
                }
            } else {
                // Save session ID even when agent returns empty response
                if (String.isNotBlank(pendingSessionId)) {
                    WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(
                        Id = conversationId,
                        Agentforce_Session_Id__c = pendingSessionId
                    );
                    update conv;
                    pendingSessionId = null;
                }
                WhatsAppLogService.logWarn(
                    'AGENTFORCE_EMPTY_RESPONSE',
                    'WhatsAppAgentforceService.processMessage',
                    'Agentforce returned empty response for conversationId=' + conversationId,
                    null
                );
            }

        } catch (Exception e) {
            WhatsAppLogService.logError(
                'AGENTFORCE_PROCESSING_EXCEPTION',
                'WhatsAppAgentforceService.processMessage',
                'Failed processing message through Agentforce: ' + e.getMessage(),
                null,
                null,
                e.getStackTraceString(),
                null
            );
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
            // Use System.debug to avoid DML before WhatsApp API callout
            System.debug('AGENTFORCE_ROUTING_EXCEPTION: ' + e.getMessage() + '\n' + e.getStackTraceString());
            return 'I apologize, but I\'m having trouble processing your request right now. A human agent will assist you shortly.';
        }
    }

    /**
     * @description Invoke the Agentforce Agent API to get a response.
     *              Uses api.salesforce.com/einstein/ai-agent/v1/ endpoints
     *              with JWT tokens from Connected App Client Credentials flow.
     */
    private static String invokeAgentRuntime(String agentId, String userInput,
                                              String context, Id contactId,
                                              Id conversationId, String sessionId) {
        try {
            // Create or continue session
            if (String.isBlank(sessionId)) {
                sessionId = createAgentSession(agentId, conversationId);
            }

            if (String.isBlank(sessionId)) {
                return getFallbackResponse(userInput);
            }

            // Send message to agent session
            // POST https://api.salesforce.com/einstein/ai-agent/v1/sessions/{sessionId}/messages
            String endpoint = AGENT_API_BASE + '/sessions/' + sessionId + '/messages';

            Map<String, Object> requestBody = new Map<String, Object>{
                'message' => new Map<String, Object>{
                    'sequenceId' => getNextSequenceId(conversationId),
                    'type' => 'Text',
                    'text' => userInput
                },
                'variables' => new List<Map<String, Object>>()
            };

            // Add variables if available
            List<Map<String, Object>> variables = (List<Map<String, Object>>) requestBody.get('variables');
            // Pass conversationId so agent actions can use it
            variables.add(new Map<String, Object>{
                'name' => 'conversationId',
                'type' => 'Text',
                'value' => String.valueOf(conversationId)
            });
            if (contactId != null) {
                variables.add(new Map<String, Object>{
                    'name' => 'ContactId',
                    'type' => 'Text',
                    'value' => String.valueOf(contactId)
                });
            }
            if (String.isNotBlank(context)) {
                variables.add(new Map<String, Object>{
                    'name' => 'ConversationContext',
                    'type' => 'Text',
                    'value' => context
                });
            }

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + WhatsAppAuthService.getAgentforceAccessToken());
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(WhatsAppConstants.DEFAULT_TIMEOUT);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                return parseAgentResponse(res.getBody());
            } else {
                // Use System.debug to avoid DML before WhatsApp API callout
                System.debug('AGENTFORCE_MESSAGE_HTTP_ERROR: HTTP ' + res.getStatusCode() + ' - ' + res.getBody());
                return getFallbackResponse(userInput);
            }

        } catch (Exception e) {
            // Use System.debug to avoid DML before WhatsApp API callout
            System.debug('AGENTFORCE_RUNTIME_EXCEPTION: ' + e.getMessage() + '\n' + e.getStackTraceString());
            return getFallbackResponse(userInput);
        }
    }

    /**
     * @description Create a new Agentforce session via the Agent API.
     *              POST https://api.salesforce.com/einstein/ai-agent/v1/agents/{agentId}/sessions
     */
    private static String createAgentSession(String agentId, Id conversationId) {
        try {
            String endpoint = AGENT_API_BASE + '/agents/' + agentId + '/sessions';
            String instanceUrl = URL.getOrgDomainUrl().toExternalForm();

            Map<String, Object> requestBody = new Map<String, Object>{
                'externalSessionKey' => generateSessionKey(),
                'instanceConfig' => new Map<String, Object>{
                    'endpoint' => instanceUrl
                },
                'bypassUser' => true
            };

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + WhatsAppAuthService.getAgentforceAccessToken());
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(WhatsAppConstants.DEFAULT_TIMEOUT);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String newSessionId = (String) responseMap.get('sessionId');

                // Save for deferred DML after all callouts complete
                pendingSessionId = newSessionId;

                // Use System.debug to avoid DML between callouts (session create → message send)
                System.debug('AGENTFORCE_SESSION_CREATED: agentId=' + agentId + ', sessionId=' + newSessionId);
                return newSessionId;
            }

            // Error path — no more callouts expected after this, safe to use DML logging
            System.debug('AGENTFORCE_SESSION_CREATION_HTTP_ERROR: HTTP ' + res.getStatusCode() + ' for agentId=' + agentId);
        } catch (Exception e) {
            System.debug('AGENTFORCE_SESSION_CREATION_EXCEPTION: ' + e.getMessage());
        }
        return null;
    }

    /**
     * @description Generate a unique session key for agent sessions
     */
    private static String generateSessionKey() {
        Blob b = Crypto.generateAesKey(128);
        String hex = EncodingUtil.convertToHex(b);
        return hex.substring(0,8) + '-' + hex.substring(8,12) + '-' +
               hex.substring(12,16) + '-' + hex.substring(16,20) + '-' +
               hex.substring(20,32);
    }

    /**
     * @description Get next sequence ID for agent messages
     */
    private static Integer getNextSequenceId(Id conversationId) {
        sequenceCounter++;
        return sequenceCounter;
    }

    /**
     * @description Parse the response from Agentforce Agent API.
     *              The Agent API returns messages with type 'Inform' and a 'message' field.
     */
    private static String parseAgentResponse(String responseBody) {
        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

            List<Object> messages = (List<Object>) responseMap.get('messages');
            if (messages != null && !messages.isEmpty()) {
                List<String> responseParts = new List<String>();
                for (Object msgObj : messages) {
                    Map<String, Object> msg = (Map<String, Object>) msgObj;
                    // Agent API uses 'message' field (not 'text') and 'type' like 'Inform'
                    String text = (String) msg.get('message');
                    if (String.isBlank(text)) {
                        // Fallback to 'text' field for compatibility
                        text = (String) msg.get('text');
                    }
                    if (String.isNotBlank(text)) {
                        responseParts.add(text);
                    }
                }
                if (!responseParts.isEmpty()) {
                    return String.join(responseParts, '\n');
                }
            }

        } catch (Exception e) {
            WhatsAppErrorLogger.logAgentforceError(
                'Failed to parse agent response', null, e
            );
        }
        return null;
    }

    private static Id getContactIdForRouting(String phoneNumber, Id conversationContactId) {
        if (conversationContactId != null) {
            return conversationContactId;
        }
        List<Contact> contacts = [
            SELECT Id
            FROM Contact
            WHERE Phone = :phoneNumber OR MobilePhone = :phoneNumber
            LIMIT 1
        ];
        return contacts.isEmpty() ? null : contacts[0].Id;
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
            SELECT Content__c, Direction__c, Message_Type__c, Timestamp__c,
                   Latitude__c, Longitude__c, Location_Name__c, Location_Address__c
            FROM WhatsApp_Message__c
            WHERE Conversation__c = :conversationId
            AND Message_Type__c IN ('Text', 'Location', 'Interactive')
            ORDER BY Timestamp__c DESC
            LIMIT 20
        ];

        List<String> contextLines = new List<String>();
        for (Integer i = messages.size() - 1; i >= 0; i--) {
            WhatsApp_Message__c msg = messages[i];
            String role = msg.Direction__c == WhatsAppConstants.DIRECTION_INBOUND ? 'Customer' : 'Agent';
            String content = msg.Content__c;
            if (msg.Message_Type__c == 'Location') {
                content = buildUserInput(msg);
            } else if (msg.Message_Type__c == 'Interactive') {
                content = 'User selected: ' + msg.Content__c;
            }
            contextLines.add(role + ': ' + content);
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
            String locationInfo = 'User shared location:';
            if (message.Latitude__c != null && message.Longitude__c != null) {
                locationInfo += ' Latitude=' + message.Latitude__c + ', Longitude=' + message.Longitude__c;
            }
            if (String.isNotBlank(message.Location_Name__c)) {
                locationInfo += ', Name=' + message.Location_Name__c;
            }
            if (String.isNotBlank(message.Location_Address__c)) {
                locationInfo += ', Address=' + message.Location_Address__c;
            }
            return locationInfo;
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
        if (lower.contains('hello') || lower.contains('hi') || lower.contains('hey') ||
            lower.contains('ola') || lower.contains('oi') || lower.contains('bom dia') ||
            lower.contains('hola') || lower.contains('buenas')) {
            return 'Hello! Welcome to our support. How can I help you today?';
        } else if (lower.contains('help') || lower.contains('ajuda') || lower.contains('ayuda')) {
            return 'I\'m here to help! Please describe what you need assistance with.';
        } else if (lower.contains('thank') || lower.contains('obrigado') || lower.contains('obrigada') ||
                   lower.contains('gracias')) {
            return 'You\'re welcome! Is there anything else I can help you with?';
        } else if (lower.contains('bye') || lower.contains('goodbye') || lower.contains('tchau') ||
                   lower.contains('adeus') || lower.contains('adios')) {
            return 'Goodbye! Feel free to reach out anytime.';
        }
        return 'Thank you for your message. Let me look into that for you. Could you provide more details?';
    }
}