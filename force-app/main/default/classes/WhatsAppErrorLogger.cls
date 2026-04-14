public with sharing class WhatsAppErrorLogger {

    private static final Integer MAX_ERROR_MESSAGE_LENGTH = 500;
    private static final Integer MAX_ERROR_CODE_LENGTH = 50;
    private static final Integer MAX_LONG_TEXT_LENGTH = 131072;

    public static void logError(
        String errorType,
        String errorCode,
        String errorMessage,
        String requestPayload,
        String responsePayload,
        String stackTrace,
        Id relatedConversationId,
        Id relatedMessageId
    ) {
        WhatsApp_Error_Log__c errorLog = new WhatsApp_Error_Log__c();
        errorLog.Error_Type__c = errorType;
        errorLog.Error_Code__c = truncate(errorCode, MAX_ERROR_CODE_LENGTH);
        errorLog.Error_Message__c = truncate(errorMessage, MAX_ERROR_MESSAGE_LENGTH);
        errorLog.Request_Payload__c = truncate(requestPayload, MAX_LONG_TEXT_LENGTH);
        errorLog.Response_Payload__c = truncate(responsePayload, MAX_LONG_TEXT_LENGTH);
        errorLog.Stack_Trace__c = truncate(stackTrace, MAX_LONG_TEXT_LENGTH);
        errorLog.Related_Conversation__c = relatedConversationId;
        errorLog.Related_Message__c = relatedMessageId;

        Database.insert(errorLog, false);
    }

    public static void logError(String errorType, String errorMessage, Exception ex) {
        logError(
            errorType,
            null,
            errorMessage + ': ' + ex.getMessage(),
            null,
            null,
            ex.getStackTraceString(),
            null,
            null
        );
    }

    public static void logApiError(
        String errorCode,
        String errorMessage,
        String requestPayload,
        String responsePayload
    ) {
        logError(
            WhatsAppConstants.ERROR_API,
            errorCode,
            errorMessage,
            requestPayload,
            responsePayload,
            null,
            null,
            null
        );
    }

    public static void logWebhookError(String errorMessage, String payload, Exception ex) {
        logError(
            WhatsAppConstants.ERROR_WEBHOOK,
            null,
            errorMessage + ': ' + ex.getMessage(),
            payload,
            null,
            ex.getStackTraceString(),
            null,
            null
        );
    }

    public static void logMediaError(String errorMessage, Id relatedMessageId, Exception ex) {
        logError(
            WhatsAppConstants.ERROR_MEDIA,
            null,
            errorMessage + ': ' + ex.getMessage(),
            null,
            null,
            ex.getStackTraceString(),
            null,
            relatedMessageId
        );
    }

    public static void logAgentforceError(String errorMessage, Id conversationId, Exception ex) {
        logError(
            WhatsAppConstants.ERROR_AGENTFORCE,
            null,
            errorMessage + ': ' + ex.getMessage(),
            null,
            null,
            ex.getStackTraceString(),
            conversationId,
            null
        );
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