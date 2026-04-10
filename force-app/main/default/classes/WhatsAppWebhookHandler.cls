/**
 * @description REST endpoint for receiving WhatsApp webhooks.
 *              Handles verification (GET) and incoming messages/statuses (POST).
 *              Delegates parsing to WhatsAppWebhookParser, publishes Platform Events
 *              for inbound messages, and updates statuses via WhatsAppMessageService.
 * URL: /services/apexrest/whatsapp/webhook
 */
@RestResource(urlMapping='/whatsapp/webhook/*')
global without sharing class WhatsAppWebhookHandler {

    /**
     * @description Handle webhook verification (GET request).
     *              WhatsApp sends this during initial setup to confirm ownership.
     * @return The hub.challenge value on success, or 'Forbidden' on failure
     */
    @HttpGet
    global static void handleVerification() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String mode = req.params.get('hub.mode');
        String token = req.params.get('hub.verify_token');
        String challenge = req.params.get('hub.challenge');

        if (mode == WhatsAppConstants.WEBHOOK_MODE_SUBSCRIBE) {
            try {
                WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();

                if (config != null && token == config.Webhook_Verify_Token__c) {
                    WhatsAppLogService.logInfo(
                        'WEBHOOK_VERIFICATION_SUCCESS',
                        'WhatsAppWebhookHandler.handleVerification',
                        'Webhook token validated successfully.'
                    );
                    res.statusCode = 200;
                    res.addHeader('Content-Type', 'text/plain');
                    res.responseBody = Blob.valueOf(challenge);
                    return;
                }
            } catch (Exception e) {
                WhatsAppLogService.logError(
                    'WEBHOOK_VERIFICATION_EXCEPTION',
                    'WhatsAppWebhookHandler.handleVerification',
                    'Exception during webhook verification: ' + e.getMessage(),
                    null,
                    null,
                    e.getStackTraceString(),
                    500
                );
                // No active config found - fall through to 403
            }
        }

        WhatsAppLogService.logWarn(
            'WEBHOOK_VERIFICATION_FAILED',
            'WhatsAppWebhookHandler.handleVerification',
            'Invalid verification request. mode=' + mode,
            403
        );
        res.statusCode = 403;
        res.addHeader('Content-Type', 'text/plain');
        res.responseBody = Blob.valueOf('Forbidden');
    }

    /**
     * @description Handle incoming webhook messages and status updates (POST request).
     *              Validates HMAC signature if enabled, parses the payload, publishes
     *              Platform Events for messages, and updates statuses.
     *              Always returns 200 to prevent WhatsApp retries.
     */
    @HttpPost
    global static void handleIncomingMessage() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestBody = '';

        try {
            requestBody = req.requestBody.toString();

            // HMAC signature validation
            if (WhatsAppConfigService.isHmacValidationEnabled()) {
                WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();
                String appSecret = config.Webhook_Verify_Token__c;

                if (!WhatsAppHmacValidator.validateFromRequest(req, appSecret)) {
                    WhatsAppLogService.logWarn(
                        'WEBHOOK_HMAC_VALIDATION_FAILED',
                        'WhatsAppWebhookHandler.handleIncomingMessage',
                        'Incoming webhook rejected due to invalid HMAC signature.',
                        401
                    );
                    res.statusCode = 401;
                    res.responseBody = Blob.valueOf('{"status":"unauthorized"}');
                    return;
                }
            }

            // Parse payload using the dedicated parser
            WhatsAppWebhookParser.WebhookPayload payload = WhatsAppWebhookParser.parse(requestBody);

            WhatsAppLogService.logInfo(
                'WEBHOOK_PARSED',
                'WhatsAppWebhookHandler.handleIncomingMessage',
                'Received webhook payload with ' + requestBody
            );
            // Extract messages and statuses
            List<WhatsAppWebhookParser.ParsedMessage> messages = WhatsAppWebhookParser.extractMessages(payload);
            List<WhatsAppWebhookParser.StatusUpdate> statuses = WhatsAppWebhookParser.extractStatuses(payload);

            // Publish Platform Events for each inbound message
            if (!messages.isEmpty()) {
                List<WhatsApp_Inbound_Event__e> events = new List<WhatsApp_Inbound_Event__e>();

                for (WhatsAppWebhookParser.ParsedMessage msg : messages) {
                    WhatsApp_Inbound_Event__e evt = new WhatsApp_Inbound_Event__e();
                    evt.Conversation_ID__c = '';
                    // evt.Message_ID__c = msg.id;
                    evt.Customer_Phone__c = msg.from_field;
                    evt.Message_Type__c = msg.type;
                    evt.Message_Content__c = getMessageContent(msg);
                    evt.Payload_JSON__c = msg.rawJson;
                    events.add(evt);
                }

                if (!events.isEmpty()) {
                    List<Database.SaveResult> results = EventBus.publish(events);
                    for (Database.SaveResult sr : results) {
                        WhatsAppLogService.logInfo('PLATFORM_EVENT_RESULT', 'WhatsAppWebhookHandler.handleIncomingMessage', 'Published Platform Event: ' + sr.getId());
                        if (!sr.isSuccess()) {
                            WhatsAppLogService.logWarn(
                                'PLATFORM_EVENT_PUBLISH_FAILED',
                                'WhatsAppWebhookHandler.handleIncomingMessage',
                                'Failed to publish Platform Event: ' + sr.getErrors(),
                                400
                            );
                            System.debug('Failed to publish Platform Event: ' + sr.getErrors());
                        }
                    }
                }
            }

            // Process status updates
            if (!statuses.isEmpty()) {
                for (WhatsAppWebhookParser.StatusUpdate statusUpdate : statuses) {
                    try {
                        WhatsAppMessageService.updateMessageStatus(statusUpdate.id, statusUpdate.status);
                    } catch (Exception statusEx) {
                        WhatsAppErrorLogger.logWebhookError(
                            'Error updating message status for ' + statusUpdate.id,
                            requestBody,
                            statusEx
                        );
                    }
                }
            }

            WhatsAppLogService.logInfo(
                'WEBHOOK_PROCESSED',
                'WhatsAppWebhookHandler.handleIncomingMessage',
                'Processed webhook with messages=' + String.valueOf(messages.size()) +
                ', statuses=' + String.valueOf(statuses.size())
            );

        } catch (Exception e) {
            WhatsAppLogService.logError(
                'WEBHOOK_PROCESSING_EXCEPTION',
                'WhatsAppWebhookHandler.handleIncomingMessage',
                'Error processing incoming webhook: ' + e.getMessage(),
                requestBody,
                null,
                e.getStackTraceString(),
                500
            );
            WhatsAppErrorLogger.logWebhookError('Error processing webhook', requestBody, e);
        }

        // Always return 200 - WhatsApp will retry on non-2xx responses
        res.statusCode = 200;
        res.responseBody = Blob.valueOf('{"status":"ok"}');
    }

    /**
     * @description Extracts a human-readable content string from a parsed message.
     *              Returns the text body for text messages, or a descriptive label
     *              for other message types (e.g., caption or type name).
     * @param msg The parsed message
     * @return Content string for the Platform Event
     */
    private static String getMessageContent(WhatsAppWebhookParser.ParsedMessage msg) {
        if (msg.type == WhatsAppConstants.TYPE_TEXT && msg.text != null) {
            return msg.text.body;
        } else if (msg.type == WhatsAppConstants.TYPE_IMAGE && msg.image != null) {
            return String.isNotBlank(msg.image.caption) ? msg.image.caption : 'image';
        } else if (msg.type == WhatsAppConstants.TYPE_VIDEO && msg.video != null) {
            return String.isNotBlank(msg.video.caption) ? msg.video.caption : 'video';
        } else if (msg.type == WhatsAppConstants.TYPE_AUDIO) {
            return 'audio';
        } else if (msg.type == WhatsAppConstants.TYPE_DOCUMENT && msg.document != null) {
            return String.isNotBlank(msg.document.caption) ? msg.document.caption : 'document';
        } else if (msg.type == WhatsAppConstants.TYPE_LOCATION && msg.location != null) {
            String locLabel = 'location';
            if (String.isNotBlank(msg.location.name)) {
                locLabel = msg.location.name;
            }
            return locLabel;
        } else if (msg.type == WhatsAppConstants.TYPE_STICKER) {
            return 'sticker';
        } else if (msg.type == WhatsAppConstants.TYPE_CONTACTS) {
            return 'contacts';
        } else if (msg.type == WhatsAppConstants.TYPE_INTERACTIVE && msg.interactive != null) {
            if (msg.interactive.buttonReply != null) {
                return msg.interactive.buttonReply.title;
            } else if (msg.interactive.listReply != null) {
                return msg.interactive.listReply.title;
            }
            return 'interactive';
        } else if (msg.type == WhatsAppConstants.TYPE_REACTION && msg.reaction != null) {
            return msg.reaction.emoji;
        }

        return msg.type;
    }
}
