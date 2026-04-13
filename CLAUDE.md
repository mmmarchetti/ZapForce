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

**WhatsApp_Log__c** - Operational/debug logging
- Level, Action, Source, Status Code, Details, Request/Response Payload, Stack Trace
- Lookup: Related Conversation, Related Message

**WhatsApp_Inbound_Event__e** - Platform Event for inbound messages

**WhatsApp_Outbound_Event__e** - Platform Event for outbound messages

### Apex Classes (38 .cls files)

**Utility:**
- `WhatsAppConstants` - All picklist values, API paths, string constants
- `WhatsAppErrorLogger` - Creates WhatsApp_Error_Log__c records
- `WhatsAppLogService` - Creates WhatsApp_Log__c records for flow observability
- `WhatsAppConfigService` - Cached config access, endpoint builders, defaults
- `WhatsAppHmacValidator` - HMAC-SHA256 webhook signature validation (`Crypto.generateMac()`)
- `WhatsAppWebhookParser` - Parse all webhook message types into typed wrappers

**Core Services:**
- `WhatsAppAPIService` - HTTP callouts (send text/media/location/contacts/interactive/template/reaction/sticker, mark as read, download media)
- `WhatsAppWebhookHandler` - `@RestResource` webhook endpoint with HMAC validation, publishes Platform Events
- `WhatsAppMediaHandler` - Media download, ContentVersion storage, Queueable
- `WhatsAppMessageService` - Message CRUD for all message types
- `WhatsAppConversationService` - Find/create conversations, session management, 24hr window

**Agentforce:**
- `WhatsAppAgentforceHandler` - Legacy handler
- `WhatsAppAgentforceService` - Full Agentforce integration via Agents Runtime API
- `WhatsAppAgentforceQueueable` - Async Agentforce callouts

**Invocable Actions (8 - for Agentforce agent):**
- `WhatsAppSendTextAction` - Send text message
- `WhatsAppSendTemplateAction` - Send template message
- `WhatsAppSendMediaAction` - Send media message
- `WhatsAppSendLocationAction` - Send location message
- `WhatsAppSendInteractiveAction` - Send interactive buttons/lists
- `WhatsAppGetCustomerInfoAction` - Lookup customer info
- `WhatsAppMarkReadAction` - Mark message as read
- `WhatsAppEscalateAction` - Escalate to human agent

**Queueables:**
- `WhatsAppSendMessageQueueable` - Async HTTP send
- `WhatsAppMediaDownloadQueueable` - Async media download

**Controllers:**
- `WhatsAppConfigurationController` - Config CRUD with masked secrets
- `WhatsAppConversationController` - Conversations, messages, stats, case creation
- `WhatsAppTemplateController` - Template management

**Platform Event Handlers:**
- `WhatsAppInboundEventHandler` - Process inbound events
- Trigger: `WhatsAppInboundEventTrigger`

**Test Classes (11):**
- WhatsAppConstantsTest, WhatsAppConfigServiceTest, WhatsAppErrorLoggerTest, WhatsAppHmacValidatorTest, WhatsAppWebhookParserTest, WhatsAppAPIServiceTest, WhatsAppMessageServiceTest, WhatsAppConversationServiceTest, WhatsAppConfigurationControllerTest, WhatsAppConversationControllerTest, WhatsAppMediaHandlerTest

### Lightning Web Components (5)

- `whatsappDashboard` - Parent tab container with 4 tabs
- `whatsappConfiguration` - Configuration page with masked secrets
- `whatsappConversationPanel` - Real-time conversation UI with all message types
- `whatsappTemplateManager` - Template sync, preview, send
- `whatsappAnalytics` - Statistics dashboard

### Agentforce Metadata

- 8 GenAiFunctions wrapping the InvocableMethod classes
- 4 GenAiPlugins (Topics): Customer Greeting, Customer Support, Template Communication, Escalation
- 1 GenAiPlanner: WhatsApp Customer Service Agent (ReAct planner)

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
- Implement error handling with try-catch and `WhatsAppErrorLogger`
- Always validate input parameters
- Use `WhatsAppConstants` for all string literals and picklist values
- Use `WhatsAppConfigService` for cached configuration access

### Remote Site Settings
- https://graph.facebook.com (WhatsApp Business API)
- https://lookaside.fbsbx.com (WhatsApp media CDN download URLs)

### Webhook Handling
- Webhook class: `WhatsAppWebhookHandler` (`@RestResource`)
- URL pattern: `/services/apexrest/whatsapp/webhook`
- HMAC-SHA256 signature validation on POST requests (`WhatsAppHmacValidator`)
- Verify webhook token on GET requests (WhatsApp verification challenge)
- Publishes Platform Events for async processing

### Media Handling
- Use ContentVersion for storing media files in Salesforce
- Store WhatsApp media IDs for reference
- WhatsApp media URLs expire - download immediately via Queueable
- Auto Download Media toggle in configuration
- Audio inbound is supported and stored as Salesforce Files (`ContentVersion`/`ContentDocument`)
- `whatsappConversationPanel` supports inline `<audio>` playback when media download is completed

### Agentforce Integration
- Platform Events (`WhatsApp_Inbound_Event__e`, `WhatsApp_Outbound_Event__e`) for real-time message routing
- Agents Runtime API via `WhatsAppAgentforceService`
- `WhatsAppAgentforceQueueable` for async callouts
- 24-hour conversation window management
- Session tracking with Agentforce Session Id/Topic on conversations
- 8 InvocableMethod actions exposed as GenAiFunctions

### Security
- Never commit API keys or tokens to the repository
- HMAC validation using `Crypto.generateMac()` for webhook authenticity
- Configuration secrets masked in UI (`WhatsAppConfigurationController`)
- Implement proper CRUD/FLS checks in Apex
- Use HTTPS for all webhook endpoints

## File Locations

| Path | Contents |
|------|----------|
| `force-app/main/default/classes/` | Apex classes and test classes (`Test` suffix) |
| `force-app/main/default/objects/` | Custom object definitions, fields, validation rules |
| `force-app/main/default/lwc/` | Lightning Web Components (5 components) |
| `force-app/main/default/triggers/` | Platform Event triggers |
| `force-app/main/default/permissionsets/` | 3 permission sets (Admin, Agent, Viewer) |
| `force-app/main/default/tabs/` | Custom tabs (includes `WhatsApp_Log__c` and `WhatsApp_Media__c`) |
| `force-app/main/default/remoteSiteSettings/` | Remote Site Settings for API and media CDN |
| `force-app/main/default/genAiFunctions/` | 8 GenAiFunction definitions |
| `force-app/main/default/genAiPlugins/` | 4 GenAiPlugin (Topic) definitions |
| `force-app/main/default/genAiPlanners/` | 1 GenAiPlanner definition |
| `scripts/apex/` | Test data scripts and utility scripts |

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
2. Configure Remote Site Settings for:
   - `https://graph.facebook.com`
   - `https://lookaside.fbsbx.com`
3. Set up WhatsApp Configuration record via the Configuration tab
4. Configure the webhook URL in WhatsApp Business Platform

## Common Issues and Solutions

### Callout exceptions
- Verify Remote Site Settings are configured for both:
  - `graph.facebook.com` (API)
  - `lookaside.fbsbx.com` (media downloads)
- Check API credentials in WhatsApp_Configuration__c
- Review `WhatsApp_Error_Log__c` records for details

### Webhook not receiving messages
- Verify webhook URL is publicly accessible
- Check SSL certificate is valid
- Verify HMAC validation toggle and secret match WhatsApp configuration
- Review debug logs for incoming requests

### Media download failures
- WhatsApp media URLs expire after 5 minutes
- Ensure Auto Download Media is enabled in configuration
- Check `WhatsAppMediaDownloadQueueable` execution in Apex Jobs
- Store media IDs for later re-download if needed

### Agentforce timeout
- Timeout handling is configurable via Session Timeout field
- Uses Queueable pattern for long-running operations
- Check `WhatsApp_Error_Log__c` for Agentforce-related errors

### Field-Level Security issues
- Run `sf apex run --file scripts/apex/fix-fls.apex` to fix FLS after deployment

## API Version

This project uses Salesforce API version 62.0. Update `sourceApiVersion` in `sfdx-project.json` if targeting a different version.

## Dependencies

- Salesforce Agentforce (Einstein AI)
- WhatsApp Business API account
- Publicly accessible webhook endpoint
