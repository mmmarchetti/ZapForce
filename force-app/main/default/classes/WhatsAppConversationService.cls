/**
 * @description Service class for WhatsApp conversation management including
 *              find/create operations, session tracking, 24-hour window management,
 *              and conversation lifecycle (active, idle, closed).
 */
public with sharing class WhatsAppConversationService {

    /**
     * @description Finds an existing open conversation for the customer phone or creates a new one.
     *              If an existing conversation has an expired session, it is closed and a new one is created.
     * @param customerPhone The customer's WhatsApp phone number
     * @param businessPhone The business WhatsApp phone number
     * @param customerName The customer's display name (from WhatsApp profile)
     * @return The active WhatsApp_Conversation__c record
     */
    public static WhatsApp_Conversation__c findOrCreateConversation(
        String customerPhone,
        String businessPhone,
        String customerName
    ) {
        // Query for an open conversation (not closed) for this customer phone
        List<WhatsApp_Conversation__c> existing = [
            SELECT Id,
                   Customer_Phone__c,
                   Customer_Name__c,
                   Status__c,
                   Session_Start_Time__c,
                   Session_Expiry_Time__c,
                   Unread_Count__c,
                   Message_Count__c,
                   Last_Message_Time__c
            FROM WhatsApp_Conversation__c
            WHERE Customer_Phone__c = :customerPhone
              AND Status__c != :WhatsAppConstants.CONV_STATUS_CLOSED
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            WhatsApp_Conversation__c conv = existing[0];

            // Check if session is still active
            if (isSessionActive(conv)) {
                // Update customer name if provided and different
                if (String.isNotBlank(customerName) && customerName != conv.Customer_Name__c) {
                    conv.Customer_Name__c = customerName;
                    try {
                        update conv;
                    } catch (Exception ex) {
                        WhatsAppErrorLogger.logError(
                            WhatsAppConstants.ERROR_WEBHOOK,
                            'Failed to update customer name on conversation',
                            ex
                        );
                    }
                }
                return conv;
            }

            // Session expired - close the old conversation
            closeConversation(conv.Id);
        }

        // Create a new conversation
        Integer timeoutMinutes = WhatsAppConfigService.getSessionTimeoutMinutes();
        WhatsApp_Conversation__c newConv = new WhatsApp_Conversation__c();
        newConv.Customer_Phone__c = customerPhone;
        newConv.Customer_Name__c = customerName;
        newConv.Status__c = WhatsAppConstants.CONV_STATUS_ACTIVE;
        newConv.Session_Start_Time__c = Datetime.now();
        newConv.Session_Expiry_Time__c = Datetime.now().addMinutes(timeoutMinutes);
        newConv.Unread_Count__c = 0;
        newConv.Message_Count__c = 0;

        try {
            insert newConv;
        } catch (Exception ex) {
            WhatsAppErrorLogger.logError(
                WhatsAppConstants.ERROR_WEBHOOK,
                'Failed to create new conversation',
                ex
            );
            throw ex;
        }

        return newConv;
    }

    /**
     * @description Updates conversation metadata when a new message is sent or received.
     *              Increments message count, updates last message time, and optionally
     *              increments unread count for inbound messages.
     * @param conversationId The conversation record Id
     * @param isInbound True if the message is inbound (from customer)
     */
    public static void updateConversationOnMessage(Id conversationId, Boolean isInbound) {
        if (conversationId == null) {
            return;
        }

        List<WhatsApp_Conversation__c> convs = [
            SELECT Id, Message_Count__c, Unread_Count__c, Last_Message_Time__c, Status__c
            FROM WhatsApp_Conversation__c
            WHERE Id = :conversationId
            LIMIT 1
        ];

        if (convs.isEmpty()) {
            return;
        }

        WhatsApp_Conversation__c conv = convs[0];
        conv.Last_Message_Time__c = Datetime.now();
        conv.Message_Count__c = (conv.Message_Count__c != null ? conv.Message_Count__c : 0) + 1;
        conv.Status__c = WhatsAppConstants.CONV_STATUS_ACTIVE;

        if (isInbound) {
            conv.Unread_Count__c = (conv.Unread_Count__c != null ? conv.Unread_Count__c : 0) + 1;
        }

        try {
            update conv;
        } catch (Exception ex) {
            WhatsAppErrorLogger.logError(
                WhatsAppConstants.ERROR_WEBHOOK,
                'Failed to update conversation on message',
                ex
            );
        }
    }

    /**
     * @description Marks a conversation as read by resetting the unread count to zero.
     * @param conversationId The conversation record Id
     */
    public static void markConversationRead(Id conversationId) {
        if (conversationId == null) {
            return;
        }

        WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(Id = conversationId);
        conv.Unread_Count__c = 0;

        try {
            update conv;
        } catch (Exception ex) {
            WhatsAppErrorLogger.logError(
                WhatsAppConstants.ERROR_WEBHOOK,
                'Failed to mark conversation as read',
                ex
            );
        }
    }

    /**
     * @description Checks whether a conversation's session is still active.
     *              A session is active if Session_Expiry_Time__c is null or in the future.
     * @param conv The conversation record to check
     * @return True if the session is still active
     */
    public static Boolean isSessionActive(WhatsApp_Conversation__c conv) {
        if (conv == null) {
            return false;
        }
        return conv.Session_Expiry_Time__c == null || conv.Session_Expiry_Time__c > Datetime.now();
    }

    /**
     * @description Refreshes the session timestamps on a conversation, extending
     *              the session by the configured timeout duration.
     * @param conversationId The conversation record Id
     */
    public static void refreshSession(Id conversationId) {
        if (conversationId == null) {
            return;
        }

        Integer timeoutMinutes = WhatsAppConfigService.getSessionTimeoutMinutes();
        WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(Id = conversationId);
        conv.Session_Start_Time__c = Datetime.now();
        conv.Session_Expiry_Time__c = Datetime.now().addMinutes(timeoutMinutes);

        try {
            update conv;
        } catch (Exception ex) {
            WhatsAppErrorLogger.logError(
                WhatsAppConstants.ERROR_WEBHOOK,
                'Failed to refresh conversation session',
                ex
            );
        }
    }

    /**
     * @description Closes a conversation by setting its status to Closed.
     * @param conversationId The conversation record Id
     */
    public static void closeConversation(Id conversationId) {
        if (conversationId == null) {
            return;
        }

        WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(Id = conversationId);
        conv.Status__c = WhatsAppConstants.CONV_STATUS_CLOSED;

        try {
            update conv;
        } catch (Exception ex) {
            WhatsAppErrorLogger.logError(
                WhatsAppConstants.ERROR_WEBHOOK,
                'Failed to close conversation',
                ex
            );
        }
    }

    /**
     * @description Assigns a conversation to a specific user for manual handling.
     * @param conversationId The conversation record Id
     * @param userId The user Id to assign the conversation to
     */
    public static void assignToAgent(Id conversationId, Id userId) {
        if (conversationId == null) {
            return;
        }

        WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(Id = conversationId);
        conv.Escalated_To_User__c = userId;

        try {
            update conv;
        } catch (Exception ex) {
            WhatsAppErrorLogger.logError(
                WhatsAppConstants.ERROR_WEBHOOK,
                'Failed to assign conversation to agent',
                ex
            );
        }
    }

    /**
     * @description Retrieves active and idle conversations with related record details,
     *              ordered by most recent message first.
     * @param limitCount Maximum number of conversations to return
     * @return List of WhatsApp_Conversation__c records with display fields
     */
    public static List<WhatsApp_Conversation__c> getActiveConversations(Integer limitCount) {
        return [
            SELECT Id,
                   Customer_Name__c,
                   Customer_Phone__c,
                   Status__c,
                   Last_Message_Time__c,
                   Message_Count__c,
                   Unread_Count__c,
                   Agentforce_Topic__c,
                   Contact__r.Name,
                   Case__r.CaseNumber
            FROM WhatsApp_Conversation__c
            WHERE Status__c IN (:WhatsAppConstants.CONV_STATUS_ACTIVE, :WhatsAppConstants.CONV_STATUS_IDLE)
            ORDER BY Last_Message_Time__c DESC
            LIMIT :limitCount
        ];
    }
}