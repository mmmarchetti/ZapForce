// Grant Field-Level Security (Read) to wppwebhook Guest User Profile
// for all custom fields on WhatsApp objects

String permSetId = '0PSWs000008vfJZOAY'; // wppwebhook Profile PermissionSet

// Get all custom fields on our objects
List<String> objectNames = new List<String>{
    'WhatsApp_Configuration__c',
    'WhatsApp_Conversation__c',
    'WhatsApp_Message__c',
    'WhatsApp_Media__c',
    'WhatsApp_Template__c',
    'WhatsApp_Error_Log__c'
};

// Check existing field permissions
Set<String> existingFieldPerms = new Set<String>();
for (FieldPermissions fp : [
    SELECT Field FROM FieldPermissions
    WHERE ParentId = :permSetId
    AND SobjectType IN :objectNames
]) {
    existingFieldPerms.add(fp.Field);
}
System.debug('Existing field perms count: ' + existingFieldPerms.size());

// Build list of all custom fields that need Read access
List<FieldPermissions> toInsert = new List<FieldPermissions>();

for (String objName : objectNames) {
    Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objName).getDescribe().fields.getMap();
    for (String fieldName : fieldMap.keySet()) {
        Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
        // Only custom fields (ends with __c) and not formula/auto-number
        if (dfr.isCustom() && dfr.isPermissionable()) {
            String fieldKey = objName + '.' + dfr.getName();
            if (!existingFieldPerms.contains(fieldKey)) {
                FieldPermissions fp = new FieldPermissions();
                fp.ParentId = permSetId;
                fp.SobjectType = objName;
                fp.Field = fieldKey;
                fp.PermissionsRead = true;
                fp.PermissionsEdit = false;
                toInsert.add(fp);
            }
        }
    }
}

System.debug('Fields to grant Read access: ' + toInsert.size());

if (!toInsert.isEmpty()) {
    // Insert in batches to avoid DML limits
    Integer batchSize = 100;
    for (Integer i = 0; i < toInsert.size(); i += batchSize) {
        Integer endIdx = Math.min(i + batchSize, toInsert.size());
        List<FieldPermissions> batch = new List<FieldPermissions>();
        for (Integer j = i; j < endIdx; j++) {
            batch.add(toInsert[j]);
        }
        insert batch;
        System.debug('Inserted batch ' + (i/batchSize + 1) + ': ' + batch.size() + ' field permissions');
    }
    System.debug('Total field permissions granted: ' + toInsert.size());
} else {
    System.debug('All field permissions already exist');
}
