// Configure Guest User Profile for wppwebhook Site
// Grants Apex class access, object CRUD, and FLS for all WhatsApp custom objects

String profileId = '00eWs0000059biDIAQ'; // wppwebhook Profile

// Step 1: Grant Apex Class Access
List<String> apexClasses = new List<String>{
    'WhatsAppConstants',
    'WhatsAppErrorLogger',
    'WhatsAppConfigService',
    'WhatsAppHmacValidator',
    'WhatsAppWebhookParser',
    'WhatsAppAPIService',
    'WhatsAppWebhookHandler',
    'WhatsAppMediaHandler',
    'WhatsAppMessageService',
    'WhatsAppConversationService',
    'WhatsAppAgentforceHandler',
    'WhatsAppAgentforceService',
    'WhatsAppAgentforceQueueable',
    'WhatsAppSendTextAction',
    'WhatsAppSendTemplateAction',
    'WhatsAppSendMediaAction',
    'WhatsAppSendLocationAction',
    'WhatsAppSendInteractiveAction',
    'WhatsAppGetCustomerInfoAction',
    'WhatsAppMarkReadAction',
    'WhatsAppEscalateAction',
    'WhatsAppSendMessageQueueable',
    'WhatsAppMediaDownloadQueueable',
    'WhatsAppConfigurationController',
    'WhatsAppConversationController',
    'WhatsAppTemplateController',
    'WhatsAppInboundEventHandler',
    'WhatsAppGetLocationInfoAction',
    'WhatsAppLogService',
    'WhatsAppAuthService'
};

// Query existing class IDs
Map<String, Id> classNameToId = new Map<String, Id>();
for (ApexClass ac : [SELECT Id, Name FROM ApexClass WHERE Name IN :apexClasses]) {
    classNameToId.put(ac.Name, ac.Id);
}
System.debug('Found ' + classNameToId.size() + ' Apex classes');

// Check existing access
Set<Id> classIds = new Set<Id>(classNameToId.values());
Set<Id> alreadyGranted = new Set<Id>();
for (SetupEntityAccess sea : [
    SELECT SetupEntityId FROM SetupEntityAccess
    WHERE ParentId IN (SELECT Id FROM PermissionSet WHERE ProfileId = :profileId)
    AND SetupEntityId IN :classIds
]) {
    alreadyGranted.add(sea.SetupEntityId);
}
System.debug('Already granted: ' + alreadyGranted.size());

// Get the PermissionSet for this profile
Id permSetId;
List<PermissionSet> psets = [SELECT Id FROM PermissionSet WHERE ProfileId = :profileId AND IsOwnedByProfile = true LIMIT 1];
if (!psets.isEmpty()) {
    permSetId = psets[0].Id;
} else {
    System.debug('ERROR: No permission set found for profile');
}
System.debug('Permission Set ID: ' + permSetId);

// Insert missing access records
List<SetupEntityAccess> toInsert = new List<SetupEntityAccess>();
for (String className : classNameToId.keySet()) {
    Id classId = classNameToId.get(className);
    if (!alreadyGranted.contains(classId)) {
        toInsert.add(new SetupEntityAccess(
            ParentId = permSetId,
            SetupEntityId = classId
        ));
        System.debug('Granting access to: ' + className);
    } else {
        System.debug('Already has access: ' + className);
    }
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Granted Apex class access to ' + toInsert.size() + ' classes');
} else {
    System.debug('All Apex classes already have access');
}
