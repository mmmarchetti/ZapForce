// Grant Read-only Object permissions to wppwebhook Guest User Profile
// Guest User license only allows Read access on custom objects
// Apex DML runs in system context and doesn't enforce CRUD

String permSetId = '0PSWs000008vfJZOAY'; // wppwebhook Profile PermissionSet

List<String> objects = new List<String>{
    'WhatsApp_Configuration__c',
    'WhatsApp_Conversation__c',
    'WhatsApp_Message__c',
    'WhatsApp_Media__c',
    'WhatsApp_Template__c',
    'WhatsApp_Error_Log__c'
};

// Check existing object permissions
Set<String> existingObjPerms = new Set<String>();
for (ObjectPermissions op : [
    SELECT SobjectType FROM ObjectPermissions WHERE ParentId = :permSetId AND SobjectType IN :objects
]) {
    existingObjPerms.add(op.SobjectType);
}
System.debug('Existing object perms: ' + existingObjPerms);

List<ObjectPermissions> toInsert = new List<ObjectPermissions>();

for (String objName : objects) {
    if (!existingObjPerms.contains(objName)) {
        ObjectPermissions op = new ObjectPermissions();
        op.ParentId = permSetId;
        op.SobjectType = objName;
        op.PermissionsCreate = false;
        op.PermissionsRead = true;
        op.PermissionsEdit = false;
        op.PermissionsDelete = false;
        toInsert.add(op);
        System.debug('Inserting Read permission for: ' + objName);
    } else {
        System.debug('Already has permission for: ' + objName);
    }
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Inserted ' + toInsert.size() + ' object permissions');
} else {
    System.debug('All object permissions already exist');
}

System.debug('Object permissions configured successfully');
