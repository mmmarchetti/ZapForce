/**
 * @description Authentication service for Salesforce API calls from async Apex contexts.
 *              Uses Connected App Client Credentials flow to obtain access tokens
 *              when UserInfo.getSessionId() is unavailable (Queueable, Platform Event triggers).
 *              Falls back to UserInfo.getSessionId() for interactive contexts.
 */
public with sharing class WhatsAppAuthService {

    private static String cachedAccessToken;

    /**
     * @description Gets a valid access token for the Agentforce Runtime API.
     *              Tries Connected App Client Credentials flow first (works in async),
     *              then falls back to UserInfo.getSessionId() for interactive contexts.
     * @return A valid access token, or null if unable to obtain one
     */
    public static String getAgentforceAccessToken() {
        if (cachedAccessToken != null) {
            return cachedAccessToken;
        }

        WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();

        // Prefer Connected App Client Credentials flow (works in async context)
        if (String.isNotBlank(config.SF_Client_Id__c) && String.isNotBlank(config.SF_Client_Secret__c)) {
            cachedAccessToken = requestTokenViaClientCredentials(config);
            if (cachedAccessToken != null) {
                return cachedAccessToken;
            }
        }

        // Fallback to session ID (works in interactive/synchronous contexts only)
        String sessionId = UserInfo.getSessionId();
        if (String.isNotBlank(sessionId)) {
            cachedAccessToken = sessionId;
            return cachedAccessToken;
        }

        // Use System.debug to avoid DML that would prevent subsequent callouts
        System.debug('AUTH_NO_TOKEN_AVAILABLE: Unable to obtain access token. ' +
            'Connected App credentials not configured and no active user session.');
        return null;
    }

    /**
     * @description Clears the cached access token.
     */
    public static void clearCache() {
        cachedAccessToken = null;
    }

    /**
     * @description Requests an access token using OAuth 2.0 Client Credentials flow
     *              against the org's own token endpoint.
     */
    private static String requestTokenViaClientCredentials(WhatsApp_Configuration__c config) {
        try {
            String tokenEndpoint = URL.getOrgDomainUrl().toExternalForm() + '/services/oauth2/token';

            HttpRequest req = new HttpRequest();
            req.setEndpoint(tokenEndpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(
                'grant_type=client_credentials' +
                '&client_id=' + EncodingUtil.urlEncode(config.SF_Client_Id__c, 'UTF-8') +
                '&client_secret=' + EncodingUtil.urlEncode(config.SF_Client_Secret__c, 'UTF-8')
            );
            req.setTimeout(30000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> tokenResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String accessToken = (String) tokenResponse.get('access_token');
                // Use System.debug instead of WhatsAppLogService to avoid DML between callouts
                System.debug('AUTH_TOKEN_ACQUIRED: Successfully acquired access token via Client Credentials flow');
                return accessToken;
            }

            // Use System.debug to avoid DML between callouts (token request is typically
            // followed by Agent API callouts in the same transaction)
            System.debug('AUTH_TOKEN_REQUEST_FAILED: HTTP ' + res.getStatusCode() + ' - ' + res.getBody());
        } catch (Exception e) {
            System.debug('AUTH_TOKEN_EXCEPTION: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
        return null;
    }
}
