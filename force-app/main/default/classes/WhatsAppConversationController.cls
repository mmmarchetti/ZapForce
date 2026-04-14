/**
 * @description Controller for WhatsApp Conversations tab in LWC.
 *              Handles conversation listing, message retrieval, sending, and statistics.
 */
public with sharing class WhatsAppConversationController {

    @AuraEnabled(cacheable=true)
    public static List<WhatsApp_Conversation__c> getConversations() {
        try {
            return WhatsAppConversationService.getActiveConversations(100);
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving conversations: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<WhatsApp_Message__c> getConversationMessages(String conversationId) {
        try {
            return WhatsAppMessageService.getConversationMessages(conversationId, 200);
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving messages: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void sendMessage(String conversationId, String messageText) {
        try {
            WhatsApp_Conversation__c conv = [
                SELECT Id, Customer_Phone__c FROM WhatsApp_Conversation__c WHERE Id = :conversationId LIMIT 1
            ];
            System.enqueueJob(new WhatsAppSendMessageQueueable(
                conv.Customer_Phone__c, WhatsAppConstants.TYPE_TEXT, messageText, conversationId
            ));
        } catch (Exception e) {
            throw new AuraHandledException('Error sending message: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void sendMediaMessage(String conversationId, String contentVersionId) {
        try {
            WhatsApp_Conversation__c conv = [
                SELECT Id, Customer_Phone__c FROM WhatsApp_Conversation__c WHERE Id = :conversationId LIMIT 1
            ];
            // Upload will be handled by MediaHandler
            WhatsAppMediaHandler.uploadMediaToWhatsApp(contentVersionId, conversationId, conv.Customer_Phone__c);
        } catch (Exception e) {
            throw new AuraHandledException('Error sending media: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateConversationStatus(String conversationId, String status) {
        try {
            if (status == WhatsAppConstants.CONV_STATUS_CLOSED) {
                WhatsAppConversationService.closeConversation(conversationId);
            } else {
                WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(
                    Id = conversationId, Status__c = status
                );
                update conv;
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error updating conversation: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void markConversationRead(String conversationId) {
        try {
            WhatsAppConversationService.markConversationRead(conversationId);
        } catch (Exception e) {
            throw new AuraHandledException('Error marking conversation as read: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String createCaseForConversation(String conversationId, String subject, String description) {
        try {
            WhatsApp_Conversation__c conv = [
                SELECT Id, Contact__c, Case__c FROM WhatsApp_Conversation__c WHERE Id = :conversationId LIMIT 1
            ];
            if (conv.Case__c != null) return conv.Case__c;

            Case newCase = new Case(
                Subject = subject, Description = description,
                ContactId = conv.Contact__c, Origin = 'WhatsApp', Status = 'New'
            );
            insert newCase;
            conv.Case__c = newCase.Id;
            update conv;
            return newCase.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating case: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getStatistics() {
        Map<String, Object> stats = new Map<String, Object>();
        try {
            stats.put('totalConversations', [SELECT COUNT() FROM WhatsApp_Conversation__c]);
            stats.put('activeConversations', [SELECT COUNT() FROM WhatsApp_Conversation__c WHERE Status__c = 'Active']);
            stats.put('messagesToday', [SELECT COUNT() FROM WhatsApp_Message__c WHERE CreatedDate = TODAY]);

            for (AggregateResult ar : [
                SELECT Direction__c dir, COUNT(Id) total FROM WhatsApp_Message__c
                WHERE CreatedDate = TODAY GROUP BY Direction__c
            ]) {
                String direction = (String) ar.get('dir');
                if (direction == WhatsAppConstants.DIRECTION_INBOUND) {
                    stats.put('inboundToday', ar.get('total'));
                } else if (direction == WhatsAppConstants.DIRECTION_OUTBOUND) {
                    stats.put('outboundToday', ar.get('total'));
                }
            }

            stats.put('mediaCount', [SELECT COUNT() FROM WhatsApp_Media__c WHERE CreatedDate = THIS_WEEK]);
            stats.put('errorCount', [SELECT COUNT() FROM WhatsApp_Error_Log__c WHERE Resolved__c = false]);
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving statistics: ' + e.getMessage());
        }
        return stats;
    }
}