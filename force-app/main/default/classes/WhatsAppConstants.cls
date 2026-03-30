/**
 * @description Utility class containing all string constants, picklist values,
 *              API paths, and configuration defaults used across the WhatsApp integration.
 *              Centralizes hardcoded strings throughout the codebase.
 */
public with sharing class WhatsAppConstants {

    // ─── API Configuration ───────────────────────────────────────────────
    public static final String API_VERSION = 'v21.0';
    public static final String GRAPH_API_BASE = 'https://graph.facebook.com';
    public static final String MESSAGE_PRODUCT = 'whatsapp';
    public static final String RECIPIENT_TYPE = 'individual';

    // ─── Message Directions ──────────────────────────────────────────────
    public static final String DIRECTION_INBOUND = 'Inbound';
    public static final String DIRECTION_OUTBOUND = 'Outbound';

    // ─── Message Types ───────────────────────────────────────────────────
    public static final String TYPE_TEXT = 'text';
    public static final String TYPE_IMAGE = 'image';
    public static final String TYPE_VIDEO = 'video';
    public static final String TYPE_AUDIO = 'audio';
    public static final String TYPE_DOCUMENT = 'document';
    public static final String TYPE_LOCATION = 'location';
    public static final String TYPE_CONTACT = 'contact';
    public static final String TYPE_STICKER = 'sticker';
    public static final String TYPE_INTERACTIVE = 'interactive';
    public static final String TYPE_TEMPLATE = 'template';
    public static final String TYPE_REACTION = 'reaction';
    public static final String TYPE_CONTACTS = 'contacts';
    public static final String TYPE_SYSTEM = 'system';

    // ─── Message Statuses ────────────────────────────────────────────────
    public static final String STATUS_SENT = 'Sent';
    public static final String STATUS_DELIVERED = 'Delivered';
    public static final String STATUS_READ = 'Read';
    public static final String STATUS_FAILED = 'Failed';
    public static final String STATUS_RECEIVED = 'Received';
    public static final String STATUS_PENDING = 'Pending';

    // ─── Conversation Statuses ───────────────────────────────────────────
    public static final String CONV_STATUS_ACTIVE = 'Active';
    public static final String CONV_STATUS_IDLE = 'Idle';
    public static final String CONV_STATUS_CLOSED = 'Closed';

    // ─── Download Statuses ───────────────────────────────────────────────
    public static final String DOWNLOAD_PENDING = 'Pending';
    public static final String DOWNLOAD_DOWNLOADING = 'Downloading';
    public static final String DOWNLOAD_COMPLETED = 'Completed';
    public static final String DOWNLOAD_FAILED = 'Failed';

    // ─── Media Types ─────────────────────────────────────────────────────
    public static final String MEDIA_IMAGE = 'image';
    public static final String MEDIA_VIDEO = 'video';
    public static final String MEDIA_AUDIO = 'audio';
    public static final String MEDIA_DOCUMENT = 'document';
    public static final String MEDIA_STICKER = 'sticker';

    // ─── Interactive Types ───────────────────────────────────────────────
    public static final String INTERACTIVE_BUTTON_REPLY = 'button_reply';
    public static final String INTERACTIVE_LIST_REPLY = 'list_reply';
    public static final String INTERACTIVE_CTA_URL = 'cta_url';
    public static final String INTERACTIVE_FLOW = 'flow';

    // ─── Conversation Origins ────────────────────────────────────────────
    public static final String ORIGIN_USER_INITIATED = 'user_initiated';
    public static final String ORIGIN_BUSINESS_INITIATED = 'business_initiated';
    public static final String ORIGIN_REFERRAL = 'referral';

    // ─── Template Categories ─────────────────────────────────────────────
    public static final String TEMPLATE_MARKETING = 'MARKETING';
    public static final String TEMPLATE_UTILITY = 'UTILITY';
    public static final String TEMPLATE_AUTHENTICATION = 'AUTHENTICATION';

    // ─── Template Statuses ───────────────────────────────────────────────
    public static final String TEMPLATE_APPROVED = 'APPROVED';
    public static final String TEMPLATE_PENDING = 'PENDING';
    public static final String TEMPLATE_REJECTED = 'REJECTED';

    // ─── Error Types ─────────────────────────────────────────────────────
    public static final String ERROR_API = 'API_ERROR';
    public static final String ERROR_WEBHOOK = 'WEBHOOK_ERROR';
    public static final String ERROR_MEDIA = 'MEDIA_ERROR';
    public static final String ERROR_AGENTFORCE = 'AGENTFORCE_ERROR';
    public static final String ERROR_VALIDATION = 'VALIDATION_ERROR';

    // ─── API Paths ───────────────────────────────────────────────────────
    public static final String PATH_MESSAGES = '/messages';
    public static final String PATH_MEDIA = '/media';
    public static final String PATH_TEMPLATES = '/message_templates';

    // ─── Webhook Fields ──────────────────────────────────────────────────
    public static final String WEBHOOK_MODE_SUBSCRIBE = 'subscribe';

    // ─── Default Timeouts ────────────────────────────────────────────────
    public static final Integer DEFAULT_TIMEOUT = 60000;
    public static final Integer DEFAULT_SESSION_TIMEOUT_MINUTES = 1440;

    // ─── Security ────────────────────────────────────────────────────────
    public static final String HMAC_ALGORITHM = 'HmacSHA256';
}
