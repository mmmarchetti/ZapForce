# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WhatsApp Salesforce Integration - A comprehensive application that connects WhatsApp Business API with Salesforce Agentforce. The project enables bidirectional communication between WhatsApp users and Salesforce's AI agent, with full support for media, geolocation, and conversation management.

**Key Components:**
- WhatsApp API integration layer (Apex classes)
- Custom objects for storing WhatsApp data (messages, media, conversations, configuration)
- Lightning Web Components for user interface
- Agentforce integration for AI-powered conversations
- Real-time webhook handling for incoming WhatsApp messages

## Architecture

### Data Model
- **WhatsApp_Configuration__c**: Stores API credentials and settings (API Key, Phone Number, Webhook URL, API Base URL)
- **WhatsApp_Conversation__c**: Tracks conversations with metadata (participants, status, last message time)
- **WhatsApp_Message__c**: Stores individual messages with full metadata (sender, recipient, content, timestamp, status, related conversation)
- **WhatsApp_Media__c**: Handles media files (photos, videos, audio, documents) with WhatsApp media IDs and local storage references
- **Lookup relationships**: Message → Conversation, Media → Message

### API Integration Layer (Apex)
- **WhatsAppAPIService**: Core HTTP callout class for WhatsApp Business API operations
  - Send messages (text, media, location)
  - Download media files
  - Retrieve message status
  - Handle API authentication
- **WhatsAppMessageHandler**: Processes incoming webhook payloads
  - Parse webhook JSON
  - Create/update message records
  - Handle media downloads
  - Trigger Agentforce responses
- **WhatsAppMediaHandler**: Manages media file operations
  - Download from WhatsApp servers
  - Store as ContentVersion/Files in Salesforce
  - Generate preview URLs
  - Handle different media types
- **WhatsAppConfigurationController**: Aura-enabled controller for configuration UI
  - CRUD operations for configuration
  - Validation of API credentials
  - Test connection functionality

### User Interface (Lightning Web Components)
- **whatsappConfiguration**: Configuration page for API settings
- **whatsappMessageViewer**: Display message history
- **whatsappConversationPanel**: Real-time conversation interface
- **whatsappMediaGallery**: Media viewer and gallery

### Agentforce Integration
- **WhatsAppAgentforceHandler**: Routes WhatsApp messages to Agentforce
- **Flow integration**: Processes responses from Agentforce back to WhatsApp
- **Event-driven architecture**: Uses Platform Events for real-time processing

## Development Commands

### Authentication
```bash
# Login to org (use web-based login)
sf org login web --alias WhatsAppSF --instance-url https://storm-13a4609358aeb6.lightning.force.com/

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

### Apex Classes
- Use `@AuraEnabled` for methods exposed to LWC
- Implement proper error handling with try-catch blocks
- Use `@future(callout=true)` for async callouts
- Always validate input parameters
- Use Custom Metadata Types or Custom Settings for configuration when possible

### Remote Site Settings
The following remote sites must be configured for WhatsApp API:
- https://graph.facebook.com (WhatsApp Business API)
- Any custom WhatsApp API endpoint URLs

### Named Credentials (Recommended)
Use Named Credentials for WhatsApp API authentication instead of hardcoded credentials:
- Create Named Credential: `WhatsApp_API`
- Reference in Apex: `callout:WhatsApp_API/v1/messages`

### Security Considerations
- Never commit API keys or tokens to the repository
- Use Protected Custom Settings or Custom Metadata Types for sensitive data
- Implement proper CRUD/FLS checks in Apex
- Validate webhook signatures to ensure requests are from WhatsApp
- Use HTTPS for all webhook endpoints

### Webhook Handling
- Endpoint: Configure in Salesforce Site or Experience Cloud
- Webhook class must be `@RestResource`
- URL pattern: `/services/apexrest/whatsapp/webhook`
- Verify webhook token on GET requests (WhatsApp verification)
- Process POST requests for incoming messages

### Media Handling
- Use ContentVersion for storing media files
- Store WhatsApp media IDs for reference
- Implement expiration logic (WhatsApp media URLs expire)
- Handle large files appropriately (size limits)

### Agentforce Integration
- Use Platform Events for real-time message routing
- Implement queueable pattern for Agentforce API calls
- Store conversation context for multi-turn interactions
- Handle conversation state (active, idle, closed)

## File Locations

### Apex Classes
`force-app/main/default/classes/`
- All business logic and API integration code
- Test classes with `Test` suffix

### Custom Objects
`force-app/main/default/objects/`
- Object definitions with `__c` suffix
- Fields, validation rules, page layouts

### Lightning Web Components
`force-app/main/default/lwc/`
- Each component in its own folder
- HTML, JS, XML, CSS files

### Flows
`force-app/main/default/flows/`
- Agentforce routing flows
- Automation flows

### Permission Sets
`force-app/main/default/permissionsets/`
- Access control definitions

## Testing Guidelines

- Test classes must cover at least 75% code coverage
- Use Test.startTest() and Test.stopTest() for governor limit resets
- Mock HTTP callouts using HttpCalloutMock
- Test both success and error scenarios
- Use @testSetup for test data creation
- Test user permissions and sharing

## Common Issues and Solutions

### Issue: Callout exceptions
- Verify Remote Site Settings are configured
- Check API credentials in configuration
- Review callout logs for detailed error messages

### Issue: Webhook not receiving messages
- Verify webhook URL is publicly accessible
- Check SSL certificate is valid
- Verify webhook token matches WhatsApp configuration
- Review debug logs for incoming requests

### Issue: Media download failures
- WhatsApp media URLs expire after 5 minutes
- Implement immediate download upon message receipt
- Store media IDs for later reference retrieval

### Issue: Agentforce timeout
- Implement timeout handling with configurable values
- Use queueable/future methods for long-running operations
- Implement fallback responses

## API Version

This project uses Salesforce API version 60.0 (Spring '24). Update `sourceApiVersion` in `sfdx-project.json` if targeting a different version.

## Dependencies

- Salesforce Agentforce (Einstein AI)
- WhatsApp Business API account
- Publicly accessible webhook endpoint
