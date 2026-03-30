/**
 * @description Controller for WhatsApp Templates tab in LWC.
 *              Handles template listing, syncing from API, and sending template messages.
 */
public with sharing class WhatsAppTemplateController {

    @AuraEnabled(cacheable=true)
    public static List<WhatsApp_Template__c> getTemplates() {
        try {
            return [
                SELECT Id, Name, Template_Name__c, Template_ID__c, Language__c,
                       Category__c, Status__c, Header_Type__c, Header_Text__c,
                       Body_Text__c, Footer_Text__c, Button_JSON__c,
                       Variable_Count__c, Last_Synced__c, Is_Active__c
                FROM WhatsApp_Template__c
                WHERE Is_Active__c = true
                ORDER BY Template_Name__c ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving templates: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String syncTemplatesFromApi() {
        try {
            WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();
            String endpoint = config.API_Base_URL__c + '/' +
                WhatsAppConfigService.getApiVersion() + '/' +
                config.Business_Account_ID__c + WhatsAppConstants.PATH_TEMPLATES;

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + config.API_Key__c);
            req.setTimeout(WhatsAppConstants.DEFAULT_TIMEOUT);

            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() != 200) {
                throw new AuraHandledException('API error: ' + res.getStatus());
            }

            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> templates = (List<Object>) responseMap.get('data');

            if (templates == null || templates.isEmpty()) {
                return 'No templates found.';
            }

            // Get existing templates by Template_ID__c
            Map<String, WhatsApp_Template__c> existingMap = new Map<String, WhatsApp_Template__c>();
            for (WhatsApp_Template__c t : [SELECT Id, Template_ID__c FROM WhatsApp_Template__c]) {
                existingMap.put(t.Template_ID__c, t);
            }

            List<WhatsApp_Template__c> toUpsert = new List<WhatsApp_Template__c>();
            for (Object tObj : templates) {
                Map<String, Object> t = (Map<String, Object>) tObj;
                String templateId = (String) t.get('id');

                WhatsApp_Template__c tmpl = existingMap.containsKey(templateId)
                    ? existingMap.get(templateId)
                    : new WhatsApp_Template__c();

                tmpl.Template_Name__c = (String) t.get('name');
                tmpl.Template_ID__c = templateId;
                tmpl.Language__c = (String) t.get('language');
                tmpl.Category__c = (String) t.get('category');
                tmpl.Status__c = (String) t.get('status');
                tmpl.Is_Active__c = tmpl.Status__c == WhatsAppConstants.TEMPLATE_APPROVED;
                tmpl.Last_Synced__c = System.now();

                // Parse components
                List<Object> components = (List<Object>) t.get('components');
                Integer varCount = 0;
                if (components != null) {
                    for (Object cObj : components) {
                        Map<String, Object> comp = (Map<String, Object>) cObj;
                        String compType = (String) comp.get('type');
                        if (compType == 'HEADER') {
                            tmpl.Header_Type__c = (String) comp.get('format');
                            tmpl.Header_Text__c = (String) comp.get('text');
                        } else if (compType == 'BODY') {
                            tmpl.Body_Text__c = (String) comp.get('text');
                            // Count variables like {{1}}, {{2}}
                            String bodyText = tmpl.Body_Text__c;
                            if (String.isNotBlank(bodyText)) {
                                varCount += bodyText.countMatches('{{');
                            }
                        } else if (compType == 'FOOTER') {
                            tmpl.Footer_Text__c = (String) comp.get('text');
                        } else if (compType == 'BUTTONS') {
                            tmpl.Button_JSON__c = JSON.serialize(comp.get('buttons'));
                        }
                    }
                }
                tmpl.Variable_Count__c = varCount;
                toUpsert.add(tmpl);
            }

            upsert toUpsert;
            return 'Synced ' + toUpsert.size() + ' templates successfully.';

        } catch (Exception e) {
            throw new AuraHandledException('Error syncing templates: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void sendTemplateMessage(String conversationId, String templateId, String variablesJson) {
        try {
            WhatsApp_Template__c tmpl = [
                SELECT Template_Name__c, Language__c FROM WhatsApp_Template__c WHERE Id = :templateId LIMIT 1
            ];
            WhatsApp_Conversation__c conv = [
                SELECT Customer_Phone__c FROM WhatsApp_Conversation__c WHERE Id = :conversationId LIMIT 1
            ];

            List<Map<String, Object>> components = new List<Map<String, Object>>();
            if (String.isNotBlank(variablesJson)) {
                components = (List<Map<String, Object>>) JSON.deserializeUntyped(variablesJson);
            }

            Map<String, Object> params = new Map<String, Object>{
                'templateName' => tmpl.Template_Name__c,
                'languageCode' => tmpl.Language__c,
                'components' => components
            };

            System.enqueueJob(new WhatsAppSendMessageQueueable(
                conv.Customer_Phone__c, WhatsAppConstants.TYPE_TEMPLATE,
                'Template: ' + tmpl.Template_Name__c, conversationId, params
            ));
        } catch (Exception e) {
            throw new AuraHandledException('Error sending template: ' + e.getMessage());
        }
    }
}
