trigger WhatsAppMediaTrigger on WhatsApp_Media__c (after update) {

    List<Id> imageMediaIds = new List<Id>();

    for (WhatsApp_Media__c media : Trigger.new) {
        WhatsApp_Media__c oldMedia = Trigger.oldMap.get(media.Id);

        // Detect when an image download completes (ContentVersion_ID__c just populated)
        if (media.Media_Type__c == 'Image' &&
            media.ContentVersion_ID__c != null &&
            oldMedia.ContentVersion_ID__c == null) {
            imageMediaIds.add(media.Id);
        }
    }

    if (!imageMediaIds.isEmpty() && !Test.isRunningTest()) {
        System.enqueueJob(new WhatsAppImageAnalysisQueueable(imageMediaIds));
    }
}
