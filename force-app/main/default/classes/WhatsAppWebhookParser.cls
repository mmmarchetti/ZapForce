public with sharing class WhatsAppWebhookParser {

    // ── Top-level wrapper classes ──────────────────────────────────────

    public class WebhookPayload {
        public List<WebhookEntry> entries;
    }

    public class WebhookEntry {
        public String id;
        public List<WebhookChange> changes;
    }

    public class WebhookChange {
        public String field;
        public WebhookValue value;
    }

    public class WebhookValue {
        public String messagingProduct;
        public WebhookMetadata metadata;
        public List<WebhookContact> contacts;
        public List<ParsedMessage> messages;
        public List<StatusUpdate> statuses;
        public List<WebhookError> errors;
    }

    public class WebhookMetadata {
        public String displayPhoneNumber;
        public String phoneNumberId;
    }

    public class WebhookContact {
        public String waId;
        public WebhookProfile profile;
    }

    public class WebhookProfile {
        public String name;
    }

    // ── Message wrapper classes ────────────────────────────────────────

    public class ParsedMessage {
        public String id;
        public String from_field;
        public String timestamp;
        public String type;
        public TextContent text;
        public MediaContent image;
        public MediaContent video;
        public MediaContent audio;
        public MediaContent document;
        public MediaContent sticker;
        public LocationContent location;
        public List<ContactCard> contacts;
        public InteractiveContent interactive;
        public ReactionContent reaction;
        public ContextContent context;
        public Boolean isForwarded;
        public ReferralContent referral;
        public String rawJson;
    }

    public class TextContent {
        public String body;
    }

    public class MediaContent {
        public String id;
        public String mimeType;
        public String sha256;
        public String caption;
        public String filename;
        public Boolean animated;
    }

    public class LocationContent {
        public Double latitude;
        public Double longitude;
        public String name;
        public String address;
        public String url;
    }

    public class ContactCard {
        public ContactName name;
        public List<ContactPhone> phones;
        public List<ContactEmail> emails;
        public String rawJson;
    }

    public class ContactName {
        public String formattedName;
        public String firstName;
        public String lastName;
    }

    public class ContactPhone {
        public String phone;
        public String type;
        public String waId;
    }

    public class ContactEmail {
        public String email;
        public String type;
    }

    public class InteractiveContent {
        public String type;
        public ButtonReply buttonReply;
        public ListReply listReply;
    }

    public class ButtonReply {
        public String id;
        public String title;
    }

    public class ListReply {
        public String id;
        public String title;
        public String description;
    }

    public class ReactionContent {
        public String messageId;
        public String emoji;
    }

    public class ContextContent {
        public String messageId;
        public Boolean forwarded;
        public Boolean frequentlyForwarded;
    }

    public class ReferralContent {
        public String sourceUrl;
        public String sourceType;
        public String headline;
        public String body;
    }

    // ── Status wrapper classes ─────────────────────────────────────────

    public class StatusUpdate {
        public String id;
        public String status;
        public String timestamp;
        public String recipientId;
        public List<WebhookError> errors;
        public WebhookPricing pricing;
    }

    public class WebhookError {
        public Integer code;
        public String title;
        public String message;
        public String errorData;
    }

    public class WebhookPricing {
        public String pricingModel;
        public String category;
        public Boolean billable;
    }

    // ── Main parse method ──────────────────────────────────────────────

    public static WebhookPayload parse(String jsonBody) {
        if (String.isBlank(jsonBody)) {
            return null;
        }

        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        if (root == null) {
            return null;
        }

        WebhookPayload payload = new WebhookPayload();
        payload.entries = new List<WebhookEntry>();

        List<Object> entryList = (List<Object>) root.get('entry');
        if (entryList == null) {
            return payload;
        }

        for (Object entryObj : entryList) {
            Map<String, Object> entryMap = (Map<String, Object>) entryObj;
            WebhookEntry entry = new WebhookEntry();
            entry.id = getString(entryMap, 'id');
            entry.changes = new List<WebhookChange>();

            List<Object> changesList = (List<Object>) entryMap.get('changes');
            if (changesList != null) {
                for (Object changeObj : changesList) {
                    Map<String, Object> changeMap = (Map<String, Object>) changeObj;
                    WebhookChange change = new WebhookChange();
                    change.field = getString(changeMap, 'field');
                    change.value = parseValue((Map<String, Object>) changeMap.get('value'));
                    entry.changes.add(change);
                }
            }

            payload.entries.add(entry);
        }

        return payload;
    }

    // ── Convenience methods ────────────────────────────────────────────

    public static List<ParsedMessage> extractMessages(WebhookPayload payload) {
        List<ParsedMessage> allMessages = new List<ParsedMessage>();
        if (payload == null || payload.entries == null) {
            return allMessages;
        }
        for (WebhookEntry entry : payload.entries) {
            if (entry.changes == null) {
                continue;
            }
            for (WebhookChange change : entry.changes) {
                if (change.value != null && change.value.messages != null) {
                    allMessages.addAll(change.value.messages);
                }
            }
        }
        return allMessages;
    }

    public static List<StatusUpdate> extractStatuses(WebhookPayload payload) {
        List<StatusUpdate> allStatuses = new List<StatusUpdate>();
        if (payload == null || payload.entries == null) {
            return allStatuses;
        }
        for (WebhookEntry entry : payload.entries) {
            if (entry.changes == null) {
                continue;
            }
            for (WebhookChange change : entry.changes) {
                if (change.value != null && change.value.statuses != null) {
                    allStatuses.addAll(change.value.statuses);
                }
            }
        }
        return allStatuses;
    }

    // ── Private parsing helpers ────────────────────────────────────────

    private static WebhookValue parseValue(Map<String, Object> valueMap) {
        if (valueMap == null) {
            return null;
        }

        WebhookValue val = new WebhookValue();
        val.messagingProduct = getString(valueMap, 'messaging_product');
        val.metadata = parseMetadata((Map<String, Object>) valueMap.get('metadata'));
        val.contacts = parseContacts((List<Object>) valueMap.get('contacts'));
        val.messages = parseMessages((List<Object>) valueMap.get('messages'));
        val.statuses = parseStatuses((List<Object>) valueMap.get('statuses'));
        val.errors = parseErrors((List<Object>) valueMap.get('errors'));

        return val;
    }

    private static WebhookMetadata parseMetadata(Map<String, Object> metaMap) {
        if (metaMap == null) {
            return null;
        }
        WebhookMetadata meta = new WebhookMetadata();
        meta.displayPhoneNumber = getString(metaMap, 'display_phone_number');
        meta.phoneNumberId = getString(metaMap, 'phone_number_id');
        return meta;
    }

    private static List<WebhookContact> parseContacts(List<Object> contactsList) {
        List<WebhookContact> result = new List<WebhookContact>();
        if (contactsList == null) {
            return result;
        }
        for (Object cObj : contactsList) {
            Map<String, Object> cMap = (Map<String, Object>) cObj;
            WebhookContact contact = new WebhookContact();
            contact.waId = getString(cMap, 'wa_id');
            Map<String, Object> profileMap = (Map<String, Object>) cMap.get('profile');
            if (profileMap != null) {
                contact.profile = new WebhookProfile();
                contact.profile.name = getString(profileMap, 'name');
            }
            result.add(contact);
        }
        return result;
    }

    private static List<ParsedMessage> parseMessages(List<Object> msgList) {
        List<ParsedMessage> result = new List<ParsedMessage>();
        if (msgList == null) {
            return result;
        }
        for (Object msgObj : msgList) {
            Map<String, Object> msgMap = (Map<String, Object>) msgObj;
            ParsedMessage msg = new ParsedMessage();
            msg.id = getString(msgMap, 'id');
            msg.from_field = getString(msgMap, 'from');
            msg.timestamp = getString(msgMap, 'timestamp');
            msg.type = getString(msgMap, 'type');
            msg.rawJson = JSON.serialize(msgMap);

            // Context (reply threading / forwarding)
            Map<String, Object> ctxMap = (Map<String, Object>) msgMap.get('context');
            if (ctxMap != null) {
                msg.context = new ContextContent();
                msg.context.messageId = getString(ctxMap, 'id');
                msg.context.forwarded = getBoolean(ctxMap, 'forwarded');
                msg.context.frequentlyForwarded = getBoolean(ctxMap, 'frequently_forwarded');
                msg.isForwarded = msg.context.forwarded == true;
            } else {
                msg.isForwarded = false;
            }

            // Referral
            Map<String, Object> refMap = (Map<String, Object>) msgMap.get('referral');
            if (refMap != null) {
                msg.referral = new ReferralContent();
                msg.referral.sourceUrl = getString(refMap, 'source_url');
                msg.referral.sourceType = getString(refMap, 'source_type');
                msg.referral.headline = getString(refMap, 'headline');
                msg.referral.body = getString(refMap, 'body');
            }

            // Type-specific content
            if (msg.type == 'text') {
                msg.text = parseTextContent((Map<String, Object>) msgMap.get('text'));
            } else if (msg.type == 'image') {
                msg.image = parseMediaContent((Map<String, Object>) msgMap.get('image'));
            } else if (msg.type == 'video') {
                msg.video = parseMediaContent((Map<String, Object>) msgMap.get('video'));
            } else if (msg.type == 'audio') {
                msg.audio = parseMediaContent((Map<String, Object>) msgMap.get('audio'));
            } else if (msg.type == 'document') {
                msg.document = parseMediaContent((Map<String, Object>) msgMap.get('document'));
            } else if (msg.type == 'sticker') {
                msg.sticker = parseMediaContent((Map<String, Object>) msgMap.get('sticker'));
            } else if (msg.type == 'location') {
                msg.location = parseLocationContent((Map<String, Object>) msgMap.get('location'));
            } else if (msg.type == 'contacts') {
                msg.contacts = parseContactCards((List<Object>) msgMap.get('contacts'));
            } else if (msg.type == 'interactive') {
                msg.interactive = parseInteractiveContent((Map<String, Object>) msgMap.get('interactive'));
            } else if (msg.type == 'reaction') {
                msg.reaction = parseReactionContent((Map<String, Object>) msgMap.get('reaction'));
            }

            result.add(msg);
        }
        return result;
    }

    private static TextContent parseTextContent(Map<String, Object> textMap) {
        if (textMap == null) {
            return null;
        }
        TextContent tc = new TextContent();
        tc.body = getString(textMap, 'body');
        return tc;
    }

    private static MediaContent parseMediaContent(Map<String, Object> mediaMap) {
        if (mediaMap == null) {
            return null;
        }
        MediaContent mc = new MediaContent();
        mc.id = getString(mediaMap, 'id');
        mc.mimeType = getString(mediaMap, 'mime_type');
        mc.sha256 = getString(mediaMap, 'sha256');
        mc.caption = getString(mediaMap, 'caption');
        mc.filename = getString(mediaMap, 'filename');
        mc.animated = getBoolean(mediaMap, 'animated');
        return mc;
    }

    private static LocationContent parseLocationContent(Map<String, Object> locMap) {
        if (locMap == null) {
            return null;
        }
        LocationContent lc = new LocationContent();
        lc.latitude = getDouble(locMap, 'latitude');
        lc.longitude = getDouble(locMap, 'longitude');
        lc.name = getString(locMap, 'name');
        lc.address = getString(locMap, 'address');
        lc.url = getString(locMap, 'url');
        return lc;
    }

    private static List<ContactCard> parseContactCards(List<Object> contactsList) {
        List<ContactCard> result = new List<ContactCard>();
        if (contactsList == null) {
            return result;
        }
        for (Object cObj : contactsList) {
            Map<String, Object> cMap = (Map<String, Object>) cObj;
            ContactCard card = new ContactCard();
            card.rawJson = JSON.serialize(cMap);

            Map<String, Object> nameMap = (Map<String, Object>) cMap.get('name');
            if (nameMap != null) {
                card.name = new ContactName();
                card.name.formattedName = getString(nameMap, 'formatted_name');
                card.name.firstName = getString(nameMap, 'first_name');
                card.name.lastName = getString(nameMap, 'last_name');
            }

            card.phones = new List<ContactPhone>();
            List<Object> phonesList = (List<Object>) cMap.get('phones');
            if (phonesList != null) {
                for (Object pObj : phonesList) {
                    Map<String, Object> pMap = (Map<String, Object>) pObj;
                    ContactPhone cp = new ContactPhone();
                    cp.phone = getString(pMap, 'phone');
                    cp.type = getString(pMap, 'type');
                    cp.waId = getString(pMap, 'wa_id');
                    card.phones.add(cp);
                }
            }

            card.emails = new List<ContactEmail>();
            List<Object> emailsList = (List<Object>) cMap.get('emails');
            if (emailsList != null) {
                for (Object eObj : emailsList) {
                    Map<String, Object> eMap = (Map<String, Object>) eObj;
                    ContactEmail ce = new ContactEmail();
                    ce.email = getString(eMap, 'email');
                    ce.type = getString(eMap, 'type');
                    card.emails.add(ce);
                }
            }

            result.add(card);
        }
        return result;
    }

    private static InteractiveContent parseInteractiveContent(Map<String, Object> intMap) {
        if (intMap == null) {
            return null;
        }
        InteractiveContent ic = new InteractiveContent();
        ic.type = getString(intMap, 'type');

        Map<String, Object> btnMap = (Map<String, Object>) intMap.get('button_reply');
        if (btnMap != null) {
            ic.buttonReply = new ButtonReply();
            ic.buttonReply.id = getString(btnMap, 'id');
            ic.buttonReply.title = getString(btnMap, 'title');
        }

        Map<String, Object> lstMap = (Map<String, Object>) intMap.get('list_reply');
        if (lstMap != null) {
            ic.listReply = new ListReply();
            ic.listReply.id = getString(lstMap, 'id');
            ic.listReply.title = getString(lstMap, 'title');
            ic.listReply.description = getString(lstMap, 'description');
        }

        return ic;
    }

    private static ReactionContent parseReactionContent(Map<String, Object> reactMap) {
        if (reactMap == null) {
            return null;
        }
        ReactionContent rc = new ReactionContent();
        rc.messageId = getString(reactMap, 'message_id');
        rc.emoji = getString(reactMap, 'emoji');
        return rc;
    }

    private static List<StatusUpdate> parseStatuses(List<Object> statusList) {
        List<StatusUpdate> result = new List<StatusUpdate>();
        if (statusList == null) {
            return result;
        }
        for (Object sObj : statusList) {
            Map<String, Object> sMap = (Map<String, Object>) sObj;
            StatusUpdate su = new StatusUpdate();
            su.id = getString(sMap, 'id');
            su.status = getString(sMap, 'status');
            su.timestamp = getString(sMap, 'timestamp');
            su.recipientId = getString(sMap, 'recipient_id');
            su.errors = parseErrors((List<Object>) sMap.get('errors'));

            Map<String, Object> pricingMap = (Map<String, Object>) sMap.get('pricing');
            if (pricingMap != null) {
                su.pricing = new WebhookPricing();
                su.pricing.pricingModel = getString(pricingMap, 'pricing_model');
                su.pricing.category = getString(pricingMap, 'category');
                su.pricing.billable = getBoolean(pricingMap, 'billable');
            }

            result.add(su);
        }
        return result;
    }

    private static List<WebhookError> parseErrors(List<Object> errorList) {
        List<WebhookError> result = new List<WebhookError>();
        if (errorList == null) {
            return result;
        }
        for (Object eObj : errorList) {
            Map<String, Object> eMap = (Map<String, Object>) eObj;
            WebhookError err = new WebhookError();
            err.code = getInteger(eMap, 'code');
            err.title = getString(eMap, 'title');
            err.message = getString(eMap, 'message');
            err.errorData = getString(eMap, 'error_data');
            result.add(err);
        }
        return result;
    }

    // ── Primitive extraction helpers ───────────────────────────────────

    private static String getString(Map<String, Object> m, String key) {
        Object val = m.get(key);
        return val != null ? String.valueOf(val) : null;
    }

    private static Boolean getBoolean(Map<String, Object> m, String key) {
        Object val = m.get(key);
        if (val == null) {
            return null;
        }
        if (val instanceof Boolean) {
            return (Boolean) val;
        }
        return Boolean.valueOf(String.valueOf(val));
    }

    private static Integer getInteger(Map<String, Object> m, String key) {
        Object val = m.get(key);
        if (val == null) {
            return null;
        }
        if (val instanceof Integer) {
            return (Integer) val;
        }
        return Integer.valueOf(String.valueOf(val));
    }

    private static Double getDouble(Map<String, Object> m, String key) {
        Object val = m.get(key);
        if (val == null) {
            return null;
        }
        if (val instanceof Double) {
            return (Double) val;
        }
        return Double.valueOf(String.valueOf(val));
    }
}