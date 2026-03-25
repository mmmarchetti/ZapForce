/**
 * @description Controller for WhatsApp Configuration Lightning Web Component
 */
public with sharing class WhatsAppConfigurationController {

    /**
     * @description Get active WhatsApp configuration
     * @return WhatsApp_Configuration__c Configuration record
     */
    @AuraEnabled(cacheable=true)
    public static WhatsApp_Configuration__c getConfiguration() {
        try {
            List<WhatsApp_Configuration__c> configs = [
                SELECT Id, Name, API_Key__c, Phone_Number__c, API_Base_URL__c,
                       Webhook_URL__c, Webhook_Verify_Token__c, Business_Account_ID__c,
                       Is_Active__c, CreatedDate, LastModifiedDate
                FROM WhatsApp_Configuration__c
                WHERE Is_Active__c = true
                LIMIT 1
            ];

            return configs.isEmpty() ? null : configs[0];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving configuration: ' + e.getMessage());
        }
    }

    /**
     * @description Save WhatsApp configuration
     * @param config Configuration record to save
     * @return String Configuration record ID
     */
    @AuraEnabled
    public static String saveConfiguration(WhatsApp_Configuration__c config) {
        try {
            // Deactivate other configurations
            List<WhatsApp_Configuration__c> existingConfigs = [
                SELECT Id, Is_Active__c
                FROM WhatsApp_Configuration__c
                WHERE Id != :config.Id AND Is_Active__c = true
            ];

            for (WhatsApp_Configuration__c existingConfig : existingConfigs) {
                existingConfig.Is_Active__c = false;
            }

            if (!existingConfigs.isEmpty()) {
                update existingConfigs;
            }

            // Save the new/updated configuration
            if (config.Id != null) {
                update config;
            } else {
                config.Is_Active__c = true;
                insert config;
            }

            return config.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving configuration: ' + e.getMessage());
        }
    }

    /**
     * @description Test WhatsApp API connection
     * @param configId Configuration record ID
     * @return Map<String, Object> Test result
     */
    @AuraEnabled
    public static Map<String, Object> testConnection(String configId) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            WhatsApp_Configuration__c config = [
                SELECT Id, API_Key__c, Phone_Number__c, API_Base_URL__c
                FROM WhatsApp_Configuration__c
                WHERE Id = :configId
                LIMIT 1
            ];

            // Test API connection by getting phone number info
            String endpoint = config.API_Base_URL__c + '/' + config.Phone_Number__c;

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + config.API_Key__c);
            req.setTimeout(30000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                result.put('success', true);
                result.put('message', 'Connection successful!');
                result.put('response', res.getBody());
            } else {
                result.put('success', false);
                result.put('message', 'Connection failed: ' + res.getStatus());
                result.put('statusCode', res.getStatusCode());
            }

        } catch (Exception e) {
            result.put('success', false);
            result.put('message', 'Error: ' + e.getMessage());
        }

        return result;
    }

    /**
     * @description Get webhook endpoint URL
     * @return String Webhook URL
     */
    @AuraEnabled(cacheable=true)
    public static String getWebhookUrl() {
        try {
            String baseUrl = URL.getOrgDomainUrl().toExternalForm();
            return baseUrl + '/services/apexrest/whatsapp/webhook';
        } catch (Exception e) {
            throw new AuraHandledException('Error getting webhook URL: ' + e.getMessage());
        }
    }

    /**
     * @description Get all conversations
     * @return List<WhatsApp_Conversation__c> List of conversations
     */
    @AuraEnabled(cacheable=true)
    public static List<WhatsApp_Conversation__c> getConversations() {
        try {
            return [
                SELECT Id, Name, Customer_Phone__c, Status__c,
                       Last_Message_Time__c, Message_Count__c,
                       Contact__r.Name, Case__r.CaseNumber,
                       CreatedDate
                FROM WhatsApp_Conversation__c
                ORDER BY Last_Message_Time__c DESC
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving conversations: ' + e.getMessage());
        }
    }

    /**
     * @description Update conversation status
     * @param conversationId Conversation ID
     * @param status New status
     */
    @AuraEnabled
    public static void updateConversationStatus(String conversationId, String status) {
        try {
            WhatsApp_Conversation__c conv = new WhatsApp_Conversation__c(
                Id = conversationId,
                Status__c = status
            );
            update conv;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating conversation: ' + e.getMessage());
        }
    }

    /**
     * @description Send message from UI
     * @param conversationId Conversation ID
     * @param messageText Message text
     */
    @AuraEnabled
    public static void sendMessage(String conversationId, String messageText) {
        try {
            WhatsApp_Conversation__c conv = [
                SELECT Id, Customer_Phone__c
                FROM WhatsApp_Conversation__c
                WHERE Id = :conversationId
                LIMIT 1
            ];

            WhatsAppAPIService.sendTextMessage(conv.Customer_Phone__c, messageText, conversationId);
        } catch (Exception e) {
            throw new AuraHandledException('Error sending message: ' + e.getMessage());
        }
    }

    /**
     * @description Get conversation statistics
     * @return Map<String, Object> Statistics data
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getStatistics() {
        Map<String, Object> stats = new Map<String, Object>();

        try {
            // Total conversations
            Integer totalConversations = [SELECT COUNT() FROM WhatsApp_Conversation__c];
            stats.put('totalConversations', totalConversations);

            // Active conversations
            Integer activeConversations = [
                SELECT COUNT()
                FROM WhatsApp_Conversation__c
                WHERE Status__c = 'Active'
            ];
            stats.put('activeConversations', activeConversations);

            // Total messages today
            Integer messagesToday = [
                SELECT COUNT()
                FROM WhatsApp_Message__c
                WHERE CreatedDate = TODAY
            ];
            stats.put('messagesToday', messagesToday);

            // Inbound vs Outbound today
            AggregateResult[] directionStats = [
                SELECT Direction__c, COUNT(Id) total
                FROM WhatsApp_Message__c
                WHERE CreatedDate = TODAY
                GROUP BY Direction__c
            ];

            for (AggregateResult ar : directionStats) {
                String direction = (String) ar.get('Direction__c');
                Integer count = (Integer) ar.get('total');
                if (direction == 'Inbound') {
                    stats.put('inboundToday', count);
                } else if (direction == 'Outbound') {
                    stats.put('outboundToday', count);
                }
            }

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving statistics: ' + e.getMessage());
        }

        return stats;
    }
}
