public with sharing class WhatsAppInboundEventHandler {

    public static void handleEvents(List<WhatsApp_Inbound_Event__e> events) {
        for (WhatsApp_Inbound_Event__e evt : events) {
            try {
                processEvent(evt);
            } catch (Exception e) {
                WhatsAppErrorLogger.logWebhookError(
                    'Failed to process inbound event for phone: ' + evt.Customer_Phone__c,
                    evt.Payload_JSON__c, e
                );
            }
        }
    }

    private static void processEvent(WhatsApp_Inbound_Event__e evt) {
        // Parse the message from payload JSON
        WhatsAppWebhookParser.ParsedMessage parsed = parseMessageFromPayload(evt.Payload_JSON__c);
        if (parsed == null) {
            return;
        }

        WhatsApp_Configuration__c config = WhatsAppConfigService.getActiveConfiguration();
        String businessPhone = config.Phone_Number__c;

        // Get customer name from profile if available
        String customerName = null;
        // (Name comes from the webhook contacts array, stored in event if available)

        // Find or create conversation
        WhatsApp_Conversation__c conv = WhatsAppConversationService.findOrCreateConversation(
            evt.Customer_Phone__c, businessPhone, customerName
        );

        WhatsAppLogService.log(
            'INFO',
            'PARSED_MESSAGE_OBJECT',
            'WhatsAppInboundEventHandler.processEvent',
            'Parsed inbound message object generated successfully.',
            evt.Payload_JSON__c,
            JSON.serialize(parsed),
            null,
            null,
            conv.Id,
            null
        );

        // Create message record
        WhatsApp_Message__c msg = WhatsAppMessageService.createInboundMessage(
            parsed, conv.Id, businessPhone
        );

        // Update conversation
        WhatsAppConversationService.updateConversationOnMessage(conv.Id, true);

        // Handle media download if applicable
        if (isMediaMessage(parsed.type) && parsed != null) {
            handleMediaCreation(msg, parsed);
        }

        // Route to Agentforce (via another Queueable to allow callout)
        // For Image messages, defer Agentforce processing until media download completes
        // (WhatsAppMediaDownloadQueueable chains the Agentforce queueable after download)
        if (!Test.isRunningTest() && !isImageMessage(parsed.type)) {
            String jobId = System.enqueueJob(new WhatsAppAgentforceQueueable(conv.Id, msg.Id));
            WhatsAppLogService.logInfo(
                'AGENTFORCE_QUEUEABLE_ENQUEUED',
                'WhatsAppInboundEventHandler.processEvent',
                'Queued Agentforce processing jobId=' + jobId +
                ', conversationId=' + conv.Id +
                ', messageId=' + msg.Id
            );
        }
    }

    private static WhatsAppWebhookParser.ParsedMessage parseMessageFromPayload(String payloadJson) {
        if (String.isBlank(payloadJson)) return null;
        try {
            // The payload is a single message JSON, re-parse it
            Map<String, Object> msgMap = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
            // Re-wrap it in the webhook structure for parsing, or parse directly
            // Since we stored the raw message JSON, we need to parse it back
            WhatsAppWebhookParser.ParsedMessage parsed = new WhatsAppWebhookParser.ParsedMessage();
            parsed.id = (String) msgMap.get('id');
            parsed.from_field = (String) msgMap.get('from');
            parsed.timestamp = (String) msgMap.get('timestamp');
            parsed.type = (String) msgMap.get('type');
            parsed.rawJson = payloadJson;

            // Parse type-specific content
            if (parsed.type == WhatsAppConstants.TYPE_TEXT) {
                Map<String, Object> textObj = (Map<String, Object>) msgMap.get('text');
                if (textObj != null) {
                    parsed.text = new WhatsAppWebhookParser.TextContent();
                    parsed.text.body = (String) textObj.get('body');
                }
            } else if (parsed.type == WhatsAppConstants.TYPE_LOCATION) {
                Map<String, Object> locObj = (Map<String, Object>) msgMap.get('location');
                if (locObj != null) {
                    parsed.location = new WhatsAppWebhookParser.LocationContent();
                    parsed.location.latitude = (Double) locObj.get('latitude');
                    parsed.location.longitude = (Double) locObj.get('longitude');
                    parsed.location.name = (String) locObj.get('name');
                    parsed.location.address = (String) locObj.get('address');
                }
            } else if (parsed.type == WhatsAppConstants.TYPE_REACTION) {
                Map<String, Object> reactObj = (Map<String, Object>) msgMap.get('reaction');
                if (reactObj != null) {
                    parsed.reaction = new WhatsAppWebhookParser.ReactionContent();
                    parsed.reaction.messageId = (String) reactObj.get('message_id');
                    parsed.reaction.emoji = (String) reactObj.get('emoji');
                }
            } else if (parsed.type == WhatsAppConstants.TYPE_INTERACTIVE) {
                Map<String, Object> intObj = (Map<String, Object>) msgMap.get('interactive');
                if (intObj != null) {
                    parsed.interactive = new WhatsAppWebhookParser.InteractiveContent();
                    parsed.interactive.type = (String) intObj.get('type');
                    if (parsed.interactive.type == 'button_reply') {
                        Map<String, Object> br = (Map<String, Object>) intObj.get('button_reply');
                        if (br != null) {
                            parsed.interactive.buttonReply = new WhatsAppWebhookParser.ButtonReply();
                            parsed.interactive.buttonReply.id = (String) br.get('id');
                            parsed.interactive.buttonReply.title = (String) br.get('title');
                        }
                    } else if (parsed.interactive.type == 'list_reply') {
                        Map<String, Object> lr = (Map<String, Object>) intObj.get('list_reply');
                        if (lr != null) {
                            parsed.interactive.listReply = new WhatsAppWebhookParser.ListReply();
                            parsed.interactive.listReply.id = (String) lr.get('id');
                            parsed.interactive.listReply.title = (String) lr.get('title');
                            parsed.interactive.listReply.description = (String) lr.get('description');
                        }
                    }
                }
            }
            // Parse media types
            String mediaType = parsed.type;
            if (mediaType == WhatsAppConstants.TYPE_IMAGE || mediaType == WhatsAppConstants.TYPE_VIDEO ||
                mediaType == WhatsAppConstants.TYPE_AUDIO || mediaType == WhatsAppConstants.TYPE_DOCUMENT ||
                mediaType == WhatsAppConstants.TYPE_STICKER) {
                Map<String, Object> mediaObj = (Map<String, Object>) msgMap.get(mediaType);
                if (mediaObj != null) {
                    WhatsAppWebhookParser.MediaContent mc = new WhatsAppWebhookParser.MediaContent();
                    mc.id = (String) mediaObj.get('id');
                    mc.mimeType = (String) mediaObj.get('mime_type');
                    mc.sha256 = (String) mediaObj.get('sha256');
                    mc.caption = (String) mediaObj.get('caption');
                    mc.filename = (String) mediaObj.get('filename');
                    if (mediaType == WhatsAppConstants.TYPE_STICKER) {
                        mc.animated = (Boolean) mediaObj.get('animated');
                        parsed.sticker = mc;
                    } else if (mediaType == WhatsAppConstants.TYPE_IMAGE) {
                        parsed.image = mc;
                    } else if (mediaType == WhatsAppConstants.TYPE_VIDEO) {
                        parsed.video = mc;
                    } else if (mediaType == WhatsAppConstants.TYPE_AUDIO) {
                        parsed.audio = mc;
                    } else if (mediaType == WhatsAppConstants.TYPE_DOCUMENT) {
                        parsed.document = mc;
                    }
                }
            }
            // Parse context (replies/forwards)
            Map<String, Object> ctxObj = (Map<String, Object>) msgMap.get('context');
            if (ctxObj != null) {
                parsed.context = new WhatsAppWebhookParser.ContextContent();
                parsed.context.messageId = (String) ctxObj.get('id');
                parsed.context.forwarded = ctxObj.get('forwarded') == true;
                parsed.context.frequentlyForwarded = ctxObj.get('frequently_forwarded') == true;
                parsed.isForwarded = parsed.context.forwarded;
            }
            // Parse contacts
            List<Object> contactsList = (List<Object>) msgMap.get('contacts');
            if (contactsList != null && !contactsList.isEmpty()) {
                parsed.contacts = new List<WhatsAppWebhookParser.ContactCard>();
                for (Object cObj : contactsList) {
                    Map<String, Object> cMap = (Map<String, Object>) cObj;
                    WhatsAppWebhookParser.ContactCard card = new WhatsAppWebhookParser.ContactCard();
                    card.rawJson = JSON.serialize(cMap);
                    Map<String, Object> nameObj = (Map<String, Object>) cMap.get('name');
                    if (nameObj != null) {
                        card.name = new WhatsAppWebhookParser.ContactName();
                        card.name.formattedName = (String) nameObj.get('formatted_name');
                        card.name.firstName = (String) nameObj.get('first_name');
                        card.name.lastName = (String) nameObj.get('last_name');
                    }
                    parsed.contacts.add(card);
                }
            }

            return parsed;
        } catch (Exception e) {
            WhatsAppErrorLogger.logWebhookError('Failed to parse message payload', payloadJson, e);
            return null;
        }
    }

    private static Boolean isMediaMessage(String messageType) {
        return messageType == WhatsAppConstants.TYPE_IMAGE ||
               messageType == WhatsAppConstants.TYPE_VIDEO ||
               messageType == WhatsAppConstants.TYPE_AUDIO ||
               messageType == WhatsAppConstants.TYPE_DOCUMENT ||
               messageType == WhatsAppConstants.TYPE_STICKER;
    }

    private static Boolean isImageMessage(String messageType) {
        return messageType == WhatsAppConstants.TYPE_IMAGE;
    }

    private static void handleMediaCreation(WhatsApp_Message__c msg, WhatsAppWebhookParser.ParsedMessage parsed) {
        WhatsAppWebhookParser.MediaContent media = getMediaContent(parsed);
        if (media == null || String.isBlank(media.id)) return;

        WhatsAppLogService.log(
            'INFO',
            'PARSED_MEDIA_OBJECT',
            'WhatsAppInboundEventHandler.handleMediaCreation',
            'Parsed media object detected for inbound message.',
            JSON.serialize(parsed),
            JSON.serialize(media),
            null,
            null,
            msg.Conversation__c,
            msg.Id
        );


        WhatsApp_Media__c mediaRecord = WhatsAppMediaHandler.createMediaRecord(
            msg.Id, media.id, parsed.type, media.mimeType, media.filename, media.caption, media.sha256
        );

        
        
        WhatsAppLogService.logInfo(
            'MEDIA_RECORD_CREATED',
            'WhatsAppInboundEventHandler.handleMediaCreation',
            'Created media record for type=' + parsed.type +
            ', mediaId=' + media.id +
            ', messageId=' + msg.Id +
            ', mediaRecordId=' + mediaRecord.Id
        );

        // Queue async download if auto-download is enabled
        if (WhatsAppConfigService.isAutoDownloadMediaEnabled() && !Test.isRunningTest()) {
            String mediaJobId = System.enqueueJob(new WhatsAppMediaDownloadQueueable(mediaRecord.Id));
            WhatsAppLogService.logInfo(
                'MEDIA_DOWNLOAD_QUEUED',
                'WhatsAppInboundEventHandler.handleMediaCreation',
                'Queued media download jobId=' + mediaJobId + ', mediaRecordId=' + mediaRecord.Id
            );
        }
    }

    private static WhatsAppWebhookParser.MediaContent getMediaContent(WhatsAppWebhookParser.ParsedMessage parsed) {
        if (parsed.image != null) return parsed.image;
        if (parsed.video != null) return parsed.video;
        if (parsed.audio != null) return parsed.audio;
        if (parsed.document != null) return parsed.document;
        if (parsed.sticker != null) return parsed.sticker;
        return null;
    }
}