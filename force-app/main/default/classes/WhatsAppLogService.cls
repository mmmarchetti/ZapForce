public with sharing class WhatsAppLogService {

    private static final Integer MAX_TEXT_LENGTH = 255;
    private static final Integer MAX_LONG_TEXT_LENGTH = 131072;

    public static void logInfo(String action, String source, String details) {
        log('INFO', action, source, details, null, null, null, null, null, null);
    }

    public static void logWarn(String action, String source, String details, Integer statusCode) {
        log('WARN', action, source, details, null, null, null, statusCode, null, null);
    }


    public static void logError(
        String action,
        String source,
        String details,
        String requestPayload,
        String responsePayload,
        String stackTrace,
        Integer statusCode
    ) {
        log('ERROR', action, source, details, requestPayload, responsePayload, stackTrace, statusCode, null, null);
    }

    public static void log(
        String level,
        String action,
        String source,
        String details,
        String requestPayload,
        String responsePayload,
        String stackTrace,
        Integer statusCode,
        Id relatedConversationId,
        Id relatedMessageId
    ) {
        try {
            WhatsApp_Log__c logRecord = new WhatsApp_Log__c();
            logRecord.Level__c = level;
            logRecord.Action__c = truncate(action, MAX_TEXT_LENGTH);
            logRecord.Source__c = truncate(source, MAX_TEXT_LENGTH);
            logRecord.Details__c = truncate(details, MAX_LONG_TEXT_LENGTH);
            logRecord.Request_Payload__c = truncate(requestPayload, MAX_LONG_TEXT_LENGTH);
            logRecord.Response_Payload__c = truncate(responsePayload, MAX_LONG_TEXT_LENGTH);
            logRecord.Stack_Trace__c = truncate(stackTrace, MAX_LONG_TEXT_LENGTH);
            logRecord.Status_Code__c = statusCode;
            logRecord.Related_Conversation__c = relatedConversationId;
            logRecord.Related_Message__c = relatedMessageId;

            Database.insert(logRecord, false);
        } catch (Exception e) {
            // Intentionally swallow logging failures to avoid impacting core flow.
        }
    }

    private static String truncate(String value, Integer maxLength) {
        if (value == null) {
            return null;
        }
        if (value.length() > maxLength) {
            return value.substring(0, maxLength);
        }
        return value;
    }
}
