/**
 * @description Single source of truth service for retrieving the active WhatsApp configuration.
 *              Provides transaction-level caching and convenience methods for building API endpoints.
 *              Replaces duplicate getActiveConfiguration() methods across the codebase.
 */
public inherited sharing class WhatsAppConfigService {

    private static WhatsApp_Configuration__c cachedConfig;

    /**
     * @description Retrieves the active WhatsApp configuration record.
     *              Returns a cached instance if already queried within the same transaction.
     * @return The active WhatsApp_Configuration__c record
     * @throws WhatsAppConfigException if no active configuration is found
     */
    public static WhatsApp_Configuration__c getActiveConfiguration() {
        if (cachedConfig != null) {
            return cachedConfig;
        }

        List<WhatsApp_Configuration__c> configs = [
            SELECT Id,
                   Name,
                   API_Key__c,
                   Phone_Number__c,
                   API_Base_URL__c,
                   Webhook_URL__c,
                   Webhook_Verify_Token__c,
                   Business_Account_ID__c,
                   Is_Active__c,
                   Phone_Number_ID__c,
                   Display_Phone_Number__c,
                   WhatsApp_API_Version__c,
                   Agentforce_Agent_Id__c,
                   Audio_Transcription_Flow_API_Name__c,
                   Session_Timeout_Minutes__c,
                   HMAC_Validation_Enabled__c,
                   Auto_Download_Media__c,
                   SF_Client_Id__c,
                   SF_Client_Secret__c
            FROM WhatsApp_Configuration__c
            WHERE Is_Active__c = true
            LIMIT 1
        ];

        if (configs.isEmpty()) {
            throw new WhatsAppConfigException(
                'No active WhatsApp configuration found. Please create and activate a configuration record.'
            );
        }

        cachedConfig = configs[0];
        return cachedConfig;
    }

    /**
     * @description Clears the cached configuration. Useful in test methods
     *              or when configuration changes during a transaction.
     */
    public static void clearCache() {
        cachedConfig = null;
    }

    /**
     * @description Returns the WhatsApp API version from configuration,
     *              falling back to the default defined in WhatsAppConstants.
     * @return API version string (e.g., 'v21.0')
     */
    public static String getApiVersion() {
        WhatsApp_Configuration__c config = getActiveConfiguration();
        return String.isNotBlank(config.WhatsApp_API_Version__c)
            ? config.WhatsApp_API_Version__c
            : WhatsAppConstants.API_VERSION;
    }

    /**
     * @description Builds the full messages endpoint URL.
     * @return Full URL for sending messages (e.g., https://graph.facebook.com/v21.0/{phoneNumberId}/messages)
     */
    public static String getMessagesEndpoint() {
        WhatsApp_Configuration__c config = getActiveConfiguration();
        return config.API_Base_URL__c + '/' + getApiVersion() + '/' + config.Phone_Number_ID__c + WhatsAppConstants.PATH_MESSAGES;
    }

    /**
     * @description Builds the full media upload endpoint URL.
     * @return Full URL for media operations (e.g., https://graph.facebook.com/v21.0/{phoneNumberId}/media)
     */
    public static String getMediaEndpoint() {
        WhatsApp_Configuration__c config = getActiveConfiguration();
        return config.API_Base_URL__c + '/' + getApiVersion() + '/' + config.Phone_Number_ID__c + WhatsAppConstants.PATH_MEDIA;
    }

    /**
     * @description Builds the URL for retrieving or downloading a specific media item.
     * @param mediaId The WhatsApp media ID
     * @return Full URL for the media resource (e.g., https://graph.facebook.com/v21.0/{mediaId})
     */
    public static String getMediaUrlEndpoint(String mediaId) {
        WhatsApp_Configuration__c config = getActiveConfiguration();
        return config.API_Base_URL__c + '/' + getApiVersion() + '/' + mediaId;
    }

    /**
     * @description Returns the session timeout in minutes from configuration,
     *              falling back to the default (1440 minutes / 24 hours).
     * @return Session timeout in minutes
     */
    public static Integer getSessionTimeoutMinutes() {
        WhatsApp_Configuration__c config = getActiveConfiguration();
        return config.Session_Timeout_Minutes__c != null
            ? Integer.valueOf(config.Session_Timeout_Minutes__c)
            : 1440;
    }

    /**
     * @description Returns whether HMAC webhook signature validation is enabled.
     *              Defaults to true if not explicitly configured.
     * @return true if HMAC validation is enabled
     */
    public static Boolean isHmacValidationEnabled() {
        WhatsApp_Configuration__c config = getActiveConfiguration();
        return config.HMAC_Validation_Enabled__c != null
            ? config.HMAC_Validation_Enabled__c
            : true;
    }

    /**
     * @description Returns whether automatic media download is enabled.
     *              Defaults to true if not explicitly configured.
     * @return true if auto-download media is enabled
     */
    public static Boolean isAutoDownloadMediaEnabled() {
        WhatsApp_Configuration__c config = getActiveConfiguration();
        return config.Auto_Download_Media__c != null
            ? config.Auto_Download_Media__c
            : true;
    }

    /**
     * @description Returns the API name of the autolaunched Flow used for audio transcription.
     * @return Flow API name, or null/blank if not configured
     */
    public static String getAudioTranscriptionFlowApiName() {
        WhatsApp_Configuration__c config = getActiveConfiguration();
        return config.Audio_Transcription_Flow_API_Name__c;
    }

    /**
     * @description Custom exception for WhatsApp configuration errors.
     */
    public class WhatsAppConfigException extends Exception {}
}
