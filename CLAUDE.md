# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WhatsApp Salesforce Integration - A comprehensive application that connects WhatsApp Business API with Salesforce Agentforce. The project enables bidirectional communication between WhatsApp users and Salesforce's AI agent, with full support for all WhatsApp message types (text, media, location, contacts, interactive, templates, reactions, stickers), conversation management, and error tracking.

## Architecture

### Data Model (7 Custom Objects + 2 Platform Events)

**WhatsApp_Configuration__c** - API credentials and settings
- API Key, Phone Number, Webhook URL, Business Account ID, Phone Number ID, Display Phone Number, API Version, Agentforce Agent Id, Session Timeout, HMAC Validation toggle, Auto Download Media toggle

**WhatsApp_Conversation__c** - Conversation tracking
- Customer Phone, Status, Customer Name, Session Start/Expiry, Agentforce Session Id/Topic, Contact lookup, Case lookup, Lead lookup, Escalated To User, Conversation Origin, Unread Count, Message Count, Last Message Time

**WhatsApp_Message__c** - All WhatsApp message types (text, image, video, audio, document, location, contact, sticker, interactive, template, reaction, contacts, system)
- Message ID, Sender/Recipient Phone, Direction, Status, Type, Content, Timestamp, Latitude/Longitude, Location Name/Address, Context Message ID, Is Forwarded, Reaction Emoji, Interactive Type/Button, Template Name, Sticker Animated, Contact Card JSON, Error Code/Message, Is From Agentforce, Raw Payload JSON
- `Message_ID__c` is currently a Long Text Area (1000)
- Lookup: Message -> Conversation

**WhatsApp_Media__c** - Media file storage
- Media ID, Media Type, MIME Type, File Name, File Size, Download Status, ContentVersion ID, ContentDocumentId, Media URL, Media URL Expiry, SHA256 Hash, Duration Seconds, Is Voice Note
- Lookup: Media -> Message

**WhatsApp_Template__c** - Template storage
- Template Name, Template ID, Language, Category, Status, Header Type/Text, Body Text, Footer Text, Button JSON, Variable Count, Last Synced, Is Active

**WhatsApp_Error_Log__c** - Error tracking
- Error Type, Error Code, Error Message, Stack Trace, Request/Response Payload, Related Conversation/Message, Resolved

**WhatsApp_Log__c** - Structured operational logging (INFO/WARN/ERROR)
- Level, Action, Source, Details, Request/Response Payload, Stack Trace, Status Code, Related Conversation lookup, Related Message lookup
- List Views: All Logs, Error Logs, Warning Logs

**WhatsApp_Inbound_Event__e** - Platform Event for inbound messages

**WhatsApp_Outbound_Event__e** - Platform Event for outbound messages

### Apex Classes (33 production + 12 test = 45 .cls files locally)

Note: Only WhatsApp-related classes are kept in the local project. The org contains additional SDO/B2B/Community classes that are not part of this project.

**Utility:**
- `WhatsAppConstants` - All picklist values, API paths, string constants
- `WhatsAppErrorLogger` - Creates WhatsApp_Error_Log__c records (legacy error logging)
- `WhatsAppLogService` - Structured logging to WhatsApp_Log__c (INFO/WARN/ERROR levels with action, source, details, payloads, status codes)
- `WhatsAppConfigService` - Cached config access (`inherited sharing`), endpoint builders, defaults
- `WhatsAppHmacValidator` - HMAC-SHA256 webhook signature validation (`Crypto.generateMac()`)
- `WhatsAppWebhookParser` - Parse all webhook message types into typed wrappers

**Core Services:**
- `WhatsAppAPIService` - HTTP callouts (send text/media/location/contacts/interactive/template/reaction/sticker, mark as read, download media). Logs via both `WhatsAppLogService` and `WhatsAppErrorLogger`
- `WhatsAppWebhookHandler` - `@RestResource` (`without sharing`) webhook endpoint with HMAC validation, publishes Platform Events, comprehensive logging via `WhatsAppLogService`
- `WhatsAppMediaHandler` - Media download/upload, ContentVersion storage, multipart/form-data upload via hex encoding
- `WhatsAppMessageService` - Message CRUD for all message types. `updateMessageStatus` scans recent 2000 records (Message_ID__c is LongTextArea, not queryable in WHERE)
- `WhatsAppConversationService` - Find/create conversations, session management, 24hr window

**Agentforce:**
- `WhatsAppAgentforceHandler` - Legacy handler
- `WhatsAppAgentforceService` - Full Agentforce integration via Agent API (`https://api.salesforce.com/einstein/ai-agent/v1/`). Uses JWT tokens from Connected App Client Credentials flow. Processes text, interactive, and location messages (NOT images — those are handled separately by `WhatsAppImageAnalysisQueueable`). Includes fallback responses when Agentforce is unavailable. Uses `System.debug` instead of `WhatsAppLogService` between callouts to avoid DML-before-callout errors. Session IDs saved to conversation after all callouts complete.
- `WhatsAppAuthService` - OAuth 2.0 Client Credentials flow for async Apex contexts. Returns JWT tokens (not opaque) when Connected App has `isNamedUserJwtEnabled=true`. Falls back to `UserInfo.getSessionId()` for interactive contexts. Uses `System.debug` for logging to avoid DML between callouts.
- `WhatsAppAgentforceQueueable` - Async Agentforce callouts with structured logging

**Invocable Actions (9 - for Agentforce agents):**
- `WhatsAppSendTextAction` - Send text message
- `WhatsAppSendTemplateAction` - Send template message
- `WhatsAppSendMediaAction` - Send media message
- `WhatsAppSendLocationAction` - Send location message
- `WhatsAppSendInteractiveAction` - Send interactive buttons/lists
- `WhatsAppGetCustomerInfoAction` - Lookup customer info
- `WhatsAppGetLocationInfoAction` - Retrieve most recent customer-shared location (lat/long, name, address, Google Maps URL, formatted response)
- `WhatsAppAnalyzeImageAction` - Analyze the most recent image in a conversation using AI vision (GPT-4o via Prompt Template)
- `WhatsAppMarkReadAction` - Mark message as read
- `WhatsAppEscalateAction` - Escalate to human agent

**Image Analysis:**
- `WhatsAppImageAnalysisService` - Calls ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate() with GPT-4o multimodal vision via the `WhatsApp_Image_Analysis` Prompt Template. Passes ContentDocument reference (not raw binary). Uses 0 HTTP callouts (internal pathway). **CRITICAL: ConnectApi requires a licensed user context — fails when called from Automated Process user.**
- `WhatsAppImageAnalysisEndpoint` - `@RestResource(urlMapping='/whatsapp/image-analysis')` loopback endpoint. Called by `WhatsAppImageAnalysisQueueable` with a JWT token so the ConnectApi call executes as the Connected App's Run-As user (a licensed user), not the Automated Process user.
- `WhatsAppImageAnalysisQueueable` - Triggered by `WhatsAppMediaTrigger` when image download completes. Uses loopback HTTP callout to `WhatsAppImageAnalysisEndpoint` for the ConnectApi call, then sends the result to WhatsApp. Implements `Database.AllowsCallouts`. **DML-before-callout prevention**: all logging/DML happens AFTER both callouts (loopback + WhatsApp send).
- `WhatsAppAnalyzeImageAction` - InvocableMethod for Agentforce agents to analyze images on-demand

**Queueables:**
- `WhatsAppSendMessageQueueable` - Async HTTP send
- `WhatsAppMediaDownloadQueueable` - Async media download with structured logging. Image analysis is triggered by `WhatsAppMediaTrigger` (after update) when `ContentVersion_ID__c` is populated.

**Controllers:**
- `WhatsAppConfigurationController` - Config CRUD, returns actual secret values (LWC password input handles masking), mask guard on save prevents overwriting secrets
- `WhatsAppConversationController` - Conversations, messages, stats, case creation
- `WhatsAppTemplateController` - Template management

**Platform Event Handlers:**
- `WhatsAppInboundEventHandler` - Processes inbound events: parses message from payload JSON, creates conversation/message records, handles media creation, enqueues Agentforce processing. **Image messages skip Agentforce** — image analysis is handled by the `WhatsAppMediaTrigger` → `WhatsAppImageAnalysisQueueable` pipeline after download completes.
- Trigger: `WhatsAppInboundEventTrigger`
- Trigger: `WhatsAppMediaTrigger` - Fires on `WhatsApp_Media__c` after update. When `ContentVersion_ID__c` is newly populated for an Image, enqueues `WhatsAppImageAnalysisQueueable`. Follows ZeladoriaApp trigger pattern.

**Test Classes (12):**
- WhatsAppConstantsTest, WhatsAppConfigServiceTest, WhatsAppErrorLoggerTest, WhatsAppHmacValidatorTest, WhatsAppWebhookParserTest, WhatsAppAPIServiceTest, WhatsAppMessageServiceTest, WhatsAppConversationServiceTest, WhatsAppConfigurationControllerTest, WhatsAppConversationControllerTest, WhatsAppMediaHandlerTest, WhatsAppGetLocationInfoActionTest

### Lightning Web Components (5)

- `whatsappDashboard` - Parent tab container with 4 tabs
- `whatsappConfiguration` - Configuration page (password inputs handle masking client-side, show/hide toggle)
- `whatsappConversationPanel` - Real-time conversation UI with all message types
- `whatsappTemplateManager` - Template sync, preview, send
- `whatsappAnalytics` - Statistics dashboard

### Agentforce Metadata

**WhatsApp Customer Service Agent** (main agent):
- 8 GenAiFunctions wrapping the original InvocableMethod classes
- 4 GenAiPlugins (Topics): Customer Greeting, Customer Support, Template Communication, Escalation
- 1 GenAiPlanner: WhatsApp Customer Service Agent (ReAct planner)
- Agent Script: `agentforce-script.yaml`

**WhatsApp Geolocation Agent** (test agent for location sharing):
- Agent ID: `0XxWs00000134phKAA`, DeveloperName: `WhatsApp_Geolocation_Agent`
- Purpose: Requests customer to share WhatsApp location, retrieves coordinates/address, responds with Google Maps link
- 1 GenAiFunction: `WhatsAppGetLocationInfoAction` (retrieves most recent inbound location from conversation)
- Agent Script authoring bundle: `force-app/main/default/aiAuthoringBundles/WhatsApp_Geolocation_Agent/`
- Topics: `Request_Location` (asks user to share location), `Process_Location` (retrieves and responds with location details)
- Uses existing `WhatsAppGetCustomerInfoAction` and `WhatsAppSendTextAction` GenAiFunctions

**WhatsApp Image Analysis Agent** (image analysis via GPT-4o vision):
- Agent ID: `0XxWs0000013MhlKAE`, DeveloperName: `WhatsApp_Image_Analysis_Agent`
- Purpose: Greets customer and asks for an image, then analyzes it using multimodal AI vision
- Image analysis is handled outside the agent by the trigger-based pipeline (`WhatsAppMediaTrigger` → `WhatsAppImageAnalysisQueueable`)
- 1 GenAiFunction: `WhatsAppAnalyzeImageAction` (for on-demand analysis)
- Agent Script authoring bundle: `force-app/main/default/aiAuthoringBundles/WhatsApp_Image_Analysis_Agent/`
- GenAiPromptTemplate: `WhatsApp_Image_Analysis` (GPT-4o multimodal, `einstein_gpt__flex` type)

### Permission Sets (3)

- **WhatsApp_Admin** - Full CRUD all objects including config secrets
- **WhatsApp_Agent** - R/C/E conversations and messages, R-only templates/media/error/log objects, no config access
- **WhatsApp_Viewer** - Read-only all objects except config

## Development Commands

### Authentication
```bash
# Login to org (web-based login)
sf org login web --alias WhatsAppSF --instance-url https://storm-13a4609358aeb6.my.salesforce.com

# Set default org
sf config set target-org WhatsAppSF
```

### Deployment
```bash
# Deploy all metadata to org
sf project deploy start

# Deploy specific directory
sf project deploy start --source-dir force-app/main/default/classes

# Deploy specific file
sf project deploy start --source-dir force-app/main/default/classes/WhatsAppAPIService.cls
```

### Retrieval
```bash
# Retrieve all metadata from org
sf project retrieve start --manifest manifest/package.xml

# Retrieve specific metadata types
sf project retrieve start --metadata ApexClass,CustomObject,LightningComponentBundle

# Retrieve specific components
sf project retrieve start --metadata ApexClass:WhatsAppAPIService
```

### Testing
```bash
# Run all tests
sf apex run test --test-level RunLocalTests --result-format human --code-coverage

# Run specific test class
sf apex run test --tests WhatsAppAPIServiceTest --result-format human --code-coverage

# Run tests with detailed output
sf apex run test --tests WhatsAppAPIServiceTest --result-format tap --code-coverage --output-dir test-results
```

### Development Workflow
```bash
# Open org in browser
sf org open

# View logs
sf apex get log --log-id <logId>

# Execute anonymous Apex
sf apex run --file scripts/apex/test-script.apex

# List metadata in org
sf org list metadata --metadata-type CustomObject
```

### Data Management
```bash
# Export data
sf data export tree --query "SELECT Id, Name FROM WhatsApp_Message__c" --output-dir data

# Import data
sf data import tree --plan data/plan.json
```

## Important Patterns and Conventions

### Apex Patterns
- Use `@AuraEnabled` for methods exposed to LWC
- Use `@InvocableMethod` for Agentforce actions
- Use Queueable pattern for async callouts (not `@future`)
- **Dual logging**: Use `WhatsAppLogService` for structured operational logs (INFO/WARN/ERROR to WhatsApp_Log__c) AND `WhatsAppErrorLogger` for error-specific records (WhatsApp_Error_Log__c)
- Always validate input parameters
- Use `WhatsAppConstants` for all string literals and picklist values
- Use `WhatsAppConfigService` for cached configuration access (`inherited sharing` — inherits caller's sharing context)
- `WhatsAppWebhookHandler` uses `without sharing` — required for Guest User access via public Site
- Avoid DML before callouts in Agentforce processing (use `getContactIdForRouting` pattern)
- **ConnectApi requires licensed user context**: `ConnectApi.EinsteinLLM` fails when called from the Automated Process user (Platform Event triggers, Queueables chained from them). Use a **loopback callout** pattern: `@RestResource` endpoint + JWT token from Connected App to run ConnectApi as the Run-As user.
- **Loopback callout pattern**: When async code runs as Automated Process but needs a licensed user context, call a REST endpoint on the same org using a JWT token from `WhatsAppAuthService.getAgentforceAccessToken()`. The endpoint executes as the Connected App's Run-As user. Example: `WhatsAppImageAnalysisQueueable` → `WhatsAppImageAnalysisEndpoint`.
- **GenAiPromptTemplate deployment**: Metadata deploy creates the template but runtime activation must be done manually via the Prompt Builder UI. Without activation, ConnectApi returns empty generations (no error). Use model `sfdc_ai__DefaultGPT4Omni` (not deprecated `sfdc_ai__DefaultOpenAIGPT4`).

### Remote Site Settings
- https://graph.facebook.com (WhatsApp Business API)
- https://storm-13a4609358aeb6.my.salesforce.com (loopback callouts for image analysis endpoint)

### Webhook Handling
- Webhook class: `WhatsAppWebhookHandler` (`@RestResource`, `without sharing`)
- URL pattern: `/services/apexrest/whatsapp/webhook`
- **Public Site**: Classic Visualforce Site `wppwebhook` exposes endpoint publicly
- **Public URL**: `https://storm-13a4609358aeb6.my.salesforce-sites.com/wppwebhook/services/apexrest/whatsapp/webhook`
- GET verification: Returns `hub.challenge` as plain text (HTTP 200, Content-Type: text/plain)
- POST messages: HMAC-SHA256 signature validation via `WhatsAppHmacValidator`, publishes Platform Events
- Always returns HTTP 200 on POST to prevent WhatsApp retries
- Guest User profile (`wppwebhook Profile`) has: 29 Apex class access (including WhatsAppGetLocationInfoAction, WhatsAppLogService), Read on 6+ objects, FLS on 67+ fields

### Media Handling
- Use ContentVersion for storing media files in Salesforce
- Store WhatsApp media IDs for reference
- WhatsApp media URLs expire - download immediately via `WhatsAppMediaDownloadQueueable`
- Auto Download Media toggle in configuration
- Upload to WhatsApp uses multipart/form-data with hex-encoding for binary fidelity (`WhatsAppMediaHandler.uploadMediaToWhatsApp`)
- Comprehensive MIME type mapping (images, video, audio, documents, stickers)
- **Image analysis trigger**: `WhatsAppMediaTrigger` fires on `WhatsApp_Media__c` after update when `ContentVersion_ID__c` is populated for images, enqueuing `WhatsAppImageAnalysisQueueable`

### Agentforce Integration
- Platform Events (`WhatsApp_Inbound_Event__e`, `WhatsApp_Outbound_Event__e`) for real-time message routing
- **Agent API** via `WhatsAppAgentforceService` (`https://api.salesforce.com/einstein/ai-agent/v1/`)
  - Session create: `POST /agents/{agentId}/sessions` with `externalSessionKey`, `instanceConfig.endpoint`, `bypassUser`
  - Message send: `POST /sessions/{sessionId}/messages` with `message.sequenceId`, `message.type`, `message.text`
  - Response parsing: messages array with `type: "Inform"` and `message` field
- **Authentication**: Connected App Client Credentials flow → JWT tokens (requires `isNamedUserJwtEnabled=true`)
  - Required scopes: `Api`, `RefreshToken`, `Chatbot`, `SFAP` (maps to `api`, `chatbot_api`, `sfap_api`)
  - Token must be JWT format (`eyJ...`), not opaque — standard Salesforce tokens (`00D...!AQE...`) get 404 on api.salesforce.com
  - Connected App: `WhatsApp_Agentforce_Auth` (ID: `0H4Ws000001neTZKAY`)
  - Run As user must be set via UI (Setup → App Manager → Manage → Edit Policies → Client Credentials Flow)
- **DML-before-callout prevention**: All logging between callouts uses `System.debug` instead of `WhatsAppLogService`. Session ID saved to conversation after all callouts complete via `pendingSessionId` pattern.
- `WhatsAppAgentforceQueueable` for async callouts from Platform Event trigger context
- Processes text, interactive, and location messages; image messages are handled separately by `WhatsAppImageAnalysisQueueable`; other media messages get silent acknowledgment
- Location messages pass full field data to Agentforce via `buildUserInput()`
- Fallback responses when Agentforce is unavailable or unconfigured
- 24-hour conversation window management
- Session tracking with Agentforce Session Id on conversations
- 10 InvocableMethod actions exposed as GenAiFunctions (9 original + WhatsAppAnalyzeImageAction)
- Three published agents: WhatsApp_Customer_Service_Agent (main), WhatsApp_Geolocation_Agent (location test), WhatsApp_Image_Analysis_Agent (image analysis)
- Agent Script authoring bundles in `aiAuthoringBundles/` — validate with `sf agent validate authoring-bundle`, publish with `sf agent publish authoring-bundle --skip-retrieve`

### Image Analysis Pipeline
- **Architecture**: Trigger-based pipeline following ZeladoriaApp pattern (decoupled from Agentforce flow)
- **Flow**: Image arrives → download queued (Agentforce skipped) → download completes → `WhatsApp_Media__c` updated → `WhatsAppMediaTrigger` fires → `WhatsAppImageAnalysisQueueable` enqueued → loopback HTTP to `WhatsAppImageAnalysisEndpoint` (JWT-authenticated, runs as licensed user) → ConnectApi Prompt Template with GPT-4o vision → result sent to WhatsApp
- **Prompt Template**: `WhatsApp_Image_Analysis` (GenAiPromptTemplate, type `einstein_gpt__flex`, model `sfdc_ai__DefaultGPT4Omni`). Input: `SOBJECT://ContentDocument` reference. Must be activated via Prompt Builder UI after metadata deploy.
- **ConnectApi pattern**: `ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate()` with `Map<String, String>{ 'id' => contentDocumentId, 'type' => 'ContentDocument' }` wrapped in `ConnectApi.WrappedValue`, key `Input:Image`, `applicationName = 'PromptBuilderPreview'`
- **ConnectApi limitation**: Requires a licensed user context. Fails silently (returns empty generations or throws exception) when called from the Automated Process user. Solution: loopback callout via `@RestResource` endpoint authenticated with JWT token from Connected App (runs as Run-As user).
- **DML-before-callout**: The Queueable makes two sequential callouts (loopback analysis + WhatsApp send). All DML (logging, message creation) must happen AFTER both callouts. Use `System.debug` for interim logging.
- **Race condition prevention**: Image messages skip immediate Agentforce routing in `WhatsAppInboundEventHandler`. Analysis only triggers after download completes (via trigger on `ContentVersion_ID__c` population).

### Security
- Never commit API keys or tokens to the repository
- HMAC validation using `Crypto.generateMac()` for webhook authenticity (POST only, not GET verification)
- Configuration secrets: actual values returned to LWC (password input handles masking), mask guard on save prevents overwriting
- `API_Key__c` is LongTextArea(500) to support long Meta tokens (295+ chars)
- `without sharing` on webhook handler, `inherited sharing` on config service — Guest User needs sharing bypass
- Use HTTPS for all webhook endpoints

## File Locations

| Path | Contents |
|------|----------|
| `force-app/main/default/classes/` | WhatsApp Apex classes only (29 production + 12 test). Non-WhatsApp classes exist in org but not locally |
| `force-app/main/default/objects/` | Custom object definitions (7), fields, validation rules, list views |
| `force-app/main/default/lwc/` | Lightning Web Components (5 components) |
| `force-app/main/default/triggers/` | Platform Event triggers + WhatsAppMediaTrigger (image download completion) |
| `force-app/main/default/pages/` | Visualforce pages (WhatsAppWebhookHome — Site home page) |
| `force-app/main/default/sites/` | Force.com Site definitions |
| `force-app/main/default/permissionsets/` | 3 permission sets (Admin, Agent, Viewer) |
| `force-app/main/default/genAiFunctions/` | 10 GenAiFunction definitions (8 original + WhatsAppGetLocationInfoAction + WhatsAppAnalyzeImageAction) |
| `force-app/main/default/genAiPlugins/` | 4 GenAiPlugin (Topic) definitions |
| `force-app/main/default/genAiPlanners/` | 1 GenAiPlanner definition |
| `force-app/main/default/genAiPromptTemplates/` | 1 GenAiPromptTemplate (WhatsApp_Image_Analysis — multimodal vision with GPT-4o) |
| `force-app/main/default/aiAuthoringBundles/` | Agent Script bundles (WhatsApp_Geolocation_Agent, WhatsApp_Image_Analysis_Agent) |
| `scripts/apex/` | Setup scripts: fix-fls.apex, configure-guest-profile.apex, configure-guest-object-perms.apex, configure-guest-fls.apex, test-image-agent-e2e.apex |

## Testing Guidelines

- Test classes must cover at least 75% code coverage
- Use `Test.startTest()` and `Test.stopTest()` for governor limit resets
- Mock HTTP callouts using `HttpCalloutMock`
- Test both success and error scenarios
- Use `@testSetup` for test data creation
- Test user permissions and sharing

## Post-Deployment Steps

After deploying to a new org:
1. Run `scripts/apex/fix-fls.apex` to set Field-Level Security on all custom fields
2. Configure Remote Site Settings for `https://graph.facebook.com`
3. Create a classic Force.com Site (Visualforce type) for public webhook access
4. Run Guest User profile scripts to grant Apex class access, object perms, and FLS:
   - `scripts/apex/configure-guest-profile.apex` (Apex class access)
   - `scripts/apex/configure-guest-object-perms.apex` (Object Read permissions)
   - `scripts/apex/configure-guest-fls.apex` (Field-Level Security)
5. Set up WhatsApp Configuration record via the Configuration tab
6. Configure the webhook URL in WhatsApp Business Platform (use the Site URL, not the org URL)

## Common Issues and Solutions

### Callout exceptions
- Verify Remote Site Settings are configured for both:
  - `graph.facebook.com` (API)
  - `lookaside.fbsbx.com` (media downloads)
- Check API credentials in WhatsApp_Configuration__c
- Review `WhatsApp_Error_Log__c` and `WhatsApp_Log__c` records for details

### Webhook not receiving messages
- Verify webhook URL uses the public Site URL (`.salesforce-sites.com`), not the org URL (`.my.salesforce.com`)
- Check SSL certificate is valid
- Verify HMAC validation toggle and secret match WhatsApp configuration
- Check `WhatsApp_Log__c` for WEBHOOK_VERIFICATION_FAILED or WEBHOOK_HMAC_VALIDATION_FAILED entries
- Ensure Guest User profile has Apex class access to `WhatsAppWebhookHandler`

### Media download failures
- WhatsApp media URLs expire after 5 minutes
- Ensure Auto Download Media is enabled in configuration
- Check `WhatsAppMediaDownloadQueueable` execution in Apex Jobs
- Store media IDs for later re-download if needed

### Agentforce timeout
- Timeout handling is configurable via Session Timeout field
- Uses Queueable pattern for long-running operations
- Check `WhatsApp_Log__c` for AGENTFORCE_* entries and `WhatsApp_Error_Log__c` for Agentforce-related errors
- Fallback responses are returned when agent is unavailable

### Message_ID__c not queryable
- `Message_ID__c` on WhatsApp_Message__c is a LongTextArea — cannot be used in SOQL WHERE clauses
- `updateMessageStatus` scans recent 2000 records and matches in Apex as a workaround

### Image analysis not working
- **ConnectApi returns empty/fails silently**: Prompt Template must be activated via Prompt Builder UI (Setup → Einstein → Prompt Builder). Metadata deploy alone is not enough.
- **"You have uncommitted work pending"**: DML-before-callout error. Ensure no `WhatsAppLogService` calls between the loopback callout and the WhatsApp send callout in `WhatsAppImageAnalysisQueueable`. Use `System.debug` between callouts.
- **ConnectApi fails in Queueable context**: ConnectApi.EinsteinLLM requires a licensed user. Queueables from Platform Event triggers run as Automated Process user. Use the loopback callout pattern via `WhatsAppImageAnalysisEndpoint`.
- **Race condition (image still downloading)**: Image messages must NOT be sent to Agentforce immediately. The `WhatsAppMediaTrigger` ensures analysis only happens after download completes.
- **Model deprecated**: Use `sfdc_ai__DefaultGPT4Omni`, not `sfdc_ai__DefaultOpenAIGPT4`

### Field-Level Security issues
- Run `sf apex run --file scripts/apex/fix-fls.apex` to fix FLS after deployment

## API Version

This project uses Salesforce API version 62.0. Update `sourceApiVersion` in `sfdx-project.json` if targeting a different version.

### Logging and Debugging
- `WhatsApp_Log__c` stores structured operational logs with action codes (e.g., `WEBHOOK_PARSED`, `SEND_MESSAGE_SUCCESS`, `AGENTFORCE_QUEUEABLE_ENQUEUED`)
- Use List Views: "All Logs", "Error Logs", "Warning Logs" for quick filtering
- `WhatsApp_Error_Log__c` stores error-specific records with error type/code
- Both logging systems are used in parallel throughout the codebase

## Dependencies

- Salesforce Agentforce (Einstein AI)
- WhatsApp Business API account
- Classic Force.com Site (Visualforce type) for public webhook endpoint
- Meta System User token with `whatsapp_business_management` and `whatsapp_business_messaging` scopes
