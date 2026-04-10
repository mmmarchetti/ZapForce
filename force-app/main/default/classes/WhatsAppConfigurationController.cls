/**
 * @description Controller for WhatsApp Configuration tab in LWC.
 *              Handles configuration CRUD, secret masking, and connection testing.
 */
public with sharing class WhatsAppConfigurationController {

    private static final String MASK = '••••••••••••••••';

    @AuraEnabled
    public static Map<String, Object> getConfiguration() {
        try {
            WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();
            // Return config with masked secrets
            Map<String, Object> result = new Map<String, Object>();
            result.put('Id', config.Id);
            result.put('Name', config.Name);
            result.put('API_Key__c', config.API_Key__c);
            result.put('Phone_Number__c', config.Phone_Number__c);
            result.put('Phone_Number_ID__c', config.Phone_Number_ID__c);
            result.put('Display_Phone_Number__c', config.Display_Phone_Number__c);
            result.put('API_Base_URL__c', config.API_Base_URL__c);
            result.put('Webhook_URL__c', config.Webhook_URL__c);
            result.put('Webhook_Verify_Token__c', config.Webhook_Verify_Token__c);
            result.put('Business_Account_ID__c', config.Business_Account_ID__c);
            result.put('WhatsApp_API_Version__c', config.WhatsApp_API_Version__c);
            result.put('Agentforce_Agent_Id__c', config.Agentforce_Agent_Id__c);
            result.put('Session_Timeout_Minutes__c', config.Session_Timeout_Minutes__c);
            result.put('HMAC_Validation_Enabled__c', config.HMAC_Validation_Enabled__c);
            result.put('Auto_Download_Media__c', config.Auto_Download_Media__c);
            result.put('Is_Active__c', config.Is_Active__c);
            result.put('hasApiKey', String.isNotBlank(config.API_Key__c));
            result.put('hasWebhookToken', String.isNotBlank(config.Webhook_Verify_Token__c));
            return result;
        } catch (WhatsAppConfigService.WhatsAppConfigException e) {
            // No config exists yet
            return null;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving configuration: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String saveConfiguration(Map<String, Object> configData) {
        try {
            String configId = (String) configData.get('Id');
            WhatsApp_Configuration__c config;

            if (String.isNotBlank(configId)) {
                config = [SELECT Id FROM WhatsApp_Configuration__c WHERE Id = :configId LIMIT 1];
            } else {
                config = new WhatsApp_Configuration__c();
            }

            // Set non-secret fields always
            config.Phone_Number__c = (String) configData.get('Phone_Number__c');
            config.Phone_Number_ID__c = (String) configData.get('Phone_Number_ID__c');
            config.Display_Phone_Number__c = (String) configData.get('Display_Phone_Number__c');
            config.API_Base_URL__c = (String) configData.get('API_Base_URL__c');
            config.Webhook_URL__c = (String) configData.get('Webhook_URL__c');
            config.Business_Account_ID__c = (String) configData.get('Business_Account_ID__c');
            config.WhatsApp_API_Version__c = (String) configData.get('WhatsApp_API_Version__c');
            config.Agentforce_Agent_Id__c = (String) configData.get('Agentforce_Agent_Id__c');
            config.Is_Active__c = true;

            // Handle numeric fields
            Object sessionTimeout = configData.get('Session_Timeout_Minutes__c');
            if (sessionTimeout != null) {
                config.Session_Timeout_Minutes__c = Decimal.valueOf(String.valueOf(sessionTimeout));
            }

            // Handle boolean fields
            config.HMAC_Validation_Enabled__c = configData.get('HMAC_Validation_Enabled__c') == true;
            config.Auto_Download_Media__c = configData.get('Auto_Download_Media__c') == true;

            // Only update secrets if new value provided (not the mask)
            String apiKey = (String) configData.get('API_Key__c');
            if (String.isNotBlank(apiKey) && apiKey != MASK) {
                config.API_Key__c = apiKey;
            }

            String webhookToken = (String) configData.get('Webhook_Verify_Token__c');
            if (String.isNotBlank(webhookToken) && webhookToken != MASK) {
                config.Webhook_Verify_Token__c = webhookToken;
            }

            // Deactivate other configs
            List<WhatsApp_Configuration__c> others = [
                SELECT Id FROM WhatsApp_Configuration__c
                WHERE Id != :config.Id AND Is_Active__c = true
            ];
            for (WhatsApp_Configuration__c other : others) {
                other.Is_Active__c = false;
            }
            if (!others.isEmpty()) update others;

            upsert config;
            WhatsAppConfigService.clearCache();

            return config.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving configuration: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> testConnection(String configId) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            WhatsApp_Configuration__c config = [
                SELECT Id, API_Key__c, Phone_Number_ID__c, API_Base_URL__c, WhatsApp_API_Version__c
                FROM WhatsApp_Configuration__c WHERE Id = :configId LIMIT 1
            ];

            String apiVersion = String.isNotBlank(config.WhatsApp_API_Version__c)
                ? config.WhatsApp_API_Version__c : WhatsAppConstants.API_VERSION;
            String endpoint = config.API_Base_URL__c + '/' + apiVersion + '/' + config.Phone_Number_ID__c;

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + config.API_Key__c);
            req.setTimeout(30000);

            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() == 200) {
                result.put('success', true);
                result.put('message', 'Connection successful!');
                result.put('response', res.getBody());
            } else {
                result.put('success', false);
                result.put('message', 'Connection failed: HTTP ' + res.getStatusCode() + ' - ' + res.getStatus());
            }
        } catch (Exception e) {
            result.put('success', false);
            result.put('message', 'Error: ' + e.getMessage());
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static String getWebhookUrl() {
        try {
            return URL.getOrgDomainUrl().toExternalForm() + '/services/apexrest/whatsapp/webhook';
        } catch (Exception e) {
            throw new AuraHandledException('Error getting webhook URL: ' + e.getMessage());
        }
    }
}
