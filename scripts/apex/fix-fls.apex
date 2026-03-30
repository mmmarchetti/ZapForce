// Fix FLS for all WhatsApp custom fields on System Administrator profile
String profileId = UserInfo.getProfileId();
PermissionSet ps = [SELECT Id FROM PermissionSet WHERE ProfileId = :profileId LIMIT 1];

// Get existing FLS
Set<String> existing = new Set<String>();
for (FieldPermissions fp : [SELECT Field FROM FieldPermissions WHERE ParentId = :ps.Id]) {
    existing.add(fp.Field);
}
System.debug('Existing FLS: ' + existing.size());

// All fields that need FLS
List<String> allFields = new List<String>{
    'WhatsApp_Conversation__c.Customer_Name__c',
    'WhatsApp_Conversation__c.Session_Start_Time__c',
    'WhatsApp_Conversation__c.Session_Expiry_Time__c',
    'WhatsApp_Conversation__c.Agentforce_Session_Id__c',
    'WhatsApp_Conversation__c.Agentforce_Topic__c',
    'WhatsApp_Conversation__c.Unread_Count__c',
    'WhatsApp_Conversation__c.Message_Count__c',
    'WhatsApp_Conversation__c.Last_Message_Time__c',
    'WhatsApp_Conversation__c.Contact__c',
    'WhatsApp_Conversation__c.Case__c',
    'WhatsApp_Message__c.Content__c',
    'WhatsApp_Message__c.Context_Message_ID__c',
    'WhatsApp_Message__c.Is_Forwarded__c',
    'WhatsApp_Message__c.Reaction_Emoji__c',
    'WhatsApp_Message__c.Interactive_Type__c',
    'WhatsApp_Message__c.Interactive_Button_Text__c',
    'WhatsApp_Message__c.Template_Name__c',
    'WhatsApp_Message__c.Contact_Card_JSON__c',
    'WhatsApp_Message__c.Location_Name__c',
    'WhatsApp_Message__c.Location_Address__c',
    'WhatsApp_Message__c.Error_Code__c',
    'WhatsApp_Message__c.Error_Message__c',
    'WhatsApp_Message__c.Is_From_Agentforce__c',
    'WhatsApp_Message__c.Raw_Payload_JSON__c',
    'WhatsApp_Message__c.Latitude__c',
    'WhatsApp_Message__c.Longitude__c',
    'WhatsApp_Media__c.MIME_Type__c',
    'WhatsApp_Media__c.File_Name__c',
    'WhatsApp_Media__c.File_Size__c',
    'WhatsApp_Media__c.ContentVersion_ID__c',
    'WhatsApp_Media__c.SHA256_Hash__c',
    'WhatsApp_Media__c.ContentDocumentId__c',
    'WhatsApp_Media__c.Media_URL__c',
    'WhatsApp_Media__c.Media_URL_Expiry__c'
};

List<FieldPermissions> newFps = new List<FieldPermissions>();
for (String field : allFields) {
    if (!existing.contains(field)) {
        newFps.add(new FieldPermissions(
            ParentId = ps.Id,
            SObjectType = field.split('\\.')[0],
            Field = field,
            PermissionsRead = true,
            PermissionsEdit = true
        ));
    }
}

System.debug('Creating FLS for ' + newFps.size() + ' fields');
if (!newFps.isEmpty()) {
    Database.SaveResult[] results = Database.insert(newFps, false);
    Integer ok = 0;
    for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
            ok++;
        } else {
            System.debug('FAIL: ' + results[i].getErrors()[0].getMessage());
        }
    }
    System.debug('Successfully created FLS for ' + ok + ' fields');
} else {
    System.debug('All FLS already set');
}

// Also set FLS for Error Log and Template objects
List<String> extraFields = new List<String>{
    'WhatsApp_Error_Log__c.Error_Type__c',
    'WhatsApp_Error_Log__c.Error_Code__c',
    'WhatsApp_Error_Log__c.Error_Message__c',
    'WhatsApp_Error_Log__c.Stack_Trace__c',
    'WhatsApp_Error_Log__c.Request_Payload__c',
    'WhatsApp_Error_Log__c.Response_Payload__c',
    'WhatsApp_Error_Log__c.Related_Conversation__c',
    'WhatsApp_Error_Log__c.Related_Message__c',
    'WhatsApp_Error_Log__c.Resolved__c',
    'WhatsApp_Template__c.Template_Name__c',
    'WhatsApp_Template__c.Template_ID__c',
    'WhatsApp_Template__c.Language__c',
    'WhatsApp_Template__c.Category__c',
    'WhatsApp_Template__c.Status__c',
    'WhatsApp_Template__c.Header_Type__c',
    'WhatsApp_Template__c.Header_Text__c',
    'WhatsApp_Template__c.Body_Text__c',
    'WhatsApp_Template__c.Footer_Text__c',
    'WhatsApp_Template__c.Button_JSON__c',
    'WhatsApp_Template__c.Variable_Count__c',
    'WhatsApp_Template__c.Last_Synced__c',
    'WhatsApp_Template__c.Is_Active__c'
};

List<FieldPermissions> extraFps = new List<FieldPermissions>();
for (String field : extraFields) {
    if (!existing.contains(field)) {
        extraFps.add(new FieldPermissions(
            ParentId = ps.Id,
            SObjectType = field.split('\\.')[0],
            Field = field,
            PermissionsRead = true,
            PermissionsEdit = true
        ));
    }
}

if (!extraFps.isEmpty()) {
    Database.SaveResult[] results2 = Database.insert(extraFps, false);
    Integer ok2 = 0;
    for (Database.SaveResult r : results2) {
        if (r.isSuccess()) ok2++;
        else System.debug('FAIL extra: ' + r.getErrors()[0].getMessage());
    }
    System.debug('Extra objects FLS: ' + ok2 + '/' + extraFps.size());
}
