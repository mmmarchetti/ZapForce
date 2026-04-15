# WhatsApp Integration Demo Script

## Overview
This script demonstrates the full WhatsApp-Salesforce integration, showing how location, images, audio, and documents are automatically processed in real-time.

**Demo Duration**: ~10-15 minutes  
**Prerequisites**: WhatsApp app on phone, demo files ready (image, PDF)

---

## Opening (2 minutes)

### Introduction
"Today I'm going to show you our WhatsApp-Salesforce integration. This is a fully functional integration that connects WhatsApp Business API with Salesforce Agentforce, with automatic processing for all media types."

**Show on screen**: The architecture diagram or CLAUDE.md overview

"The integration handles:
- Text conversations with AI agents
- Location sharing with Google Maps integration
- Image analysis using GPT-4o vision
- Audio transcription
- Document processing (PDFs, Word, Excel)

All of this happens automatically - no manual intervention needed."

### Starting the Demo
**Action**: Open WhatsApp and navigate to the business number

**Say**: "Let me connect to our demo agent. I'll send the first message to initiate the conversation."

**Type in WhatsApp**: 
```
Hi
```

**What happens**: 
- Message arrives at webhook endpoint
- WhatsAppWebhookHandler validates HMAC signature
- Platform Event (WhatsApp_Inbound_Event__e) is published
- WhatsAppInboundEventHandler creates conversation and message records
- WhatsAppAgentforceQueueable routes to the Demo Agent
- Agent responds with welcome message

**Agent's response** (expected):
```
Hello! I'm the WhatsApp Integration Demo Agent. I can guide you through testing: location sharing, image analysis, audio transcription, and document processing. What would you like to try?
```

**Say to audience**: 
"Notice how fast that was - the message went through multiple layers: webhook validation, platform events, conversation tracking, and AI agent processing. All in under 2 seconds."

---

## Demo 1: Location Sharing (3 minutes)

**Type in WhatsApp**:
```
Let's start with location sharing
```

**Agent's response** (expected):
Agent explains how to share location and what will happen.

**Say to audience**:
"Now I'm going to share my actual location. The agent is conversational - it guides me through the process."

**Action**: 
1. Tap the + (or paperclip) icon in WhatsApp
2. Select "Location"
3. Choose "Share Live Location" or "Send Your Current Location"
4. Send

**What happens behind the scenes** (explain while waiting):
"Behind the scenes, several things are happening:
1. WhatsApp sends the location coordinates to our webhook
2. The system creates a WhatsApp_Message__c record with type 'location'
3. Latitude, longitude, location name, and address are stored
4. The system generates a Google Maps URL
5. All this data is formatted and sent to Agentforce
6. The agent receives the formatted location info and can respond intelligently"

**Show on screen** (if possible):
- WhatsApp_Message__c record with location fields populated
- WhatsApp_Log__c showing the processing flow

**Agent's response** (expected):
Agent explains what happened and shows the Google Maps link.

**Say to audience**:
"The agent now has full context - it knows where I am, can see the Google Maps link, and this location is permanently stored in Salesforce linked to this conversation. Sales reps could use this for field service, delivery coordination, or customer location tracking."

**Type in WhatsApp**:
```
Great! What else can we try?
```

---

## Demo 2: Image Analysis (3 minutes)

**Type in WhatsApp**:
```
Show me the image analysis
```

**Agent's response** (expected):
Agent explains how to send an image and what will happen.

**Say to audience**:
"This next demo is really impressive - we're using GPT-4o's vision capabilities to automatically analyze any image a customer sends."

**Action**: 
1. Tap the + (or paperclip) icon
2. Select "Photo & Video Library" (or "Camera")
3. Choose a prepared image (e.g., product photo, document, receipt)
4. Send

**What happens behind the scenes** (explain while waiting):
"This is a more complex pipeline:
1. WhatsApp sends the image with a media ID
2. WhatsAppMediaDownloadQueueable downloads the actual image file
3. The image is stored as a ContentVersion in Salesforce Files
4. WhatsAppMediaTrigger fires when the download completes
5. WhatsAppImageAnalysisQueueable is enqueued
6. It calls the WhatsApp_Image_Analysis_Template Flow
7. The Flow uses a GenAi Prompt Template with GPT-4o vision
8. The analysis is returned as text
9. A new inbound message is created with the analysis
10. Agentforce receives it and responds to the customer"

**Time estimate**: "This usually takes 3-5 seconds because we're downloading the image, processing it with AI vision, and routing the results."

**Show on screen** (if possible):
- WhatsApp_Media__c record showing ContentVersion_ID__c populated
- WhatsApp_Log__c showing IMAGE_ANALYSIS_* entries
- The actual image in Salesforce Files

**Agent's response** (expected):
Agent receives the AI analysis and explains what was detected in the image.

**Say to audience**:
"The agent just received a detailed description of the image - what objects are visible, colors, text, context - everything. This could be used for:
- Product identification in retail
- Damage assessment for insurance claims
- Receipt processing for expense reports
- Quality control in manufacturing
- Visual troubleshooting in customer support"

**Type in WhatsApp**:
```
That's amazing! Next demo?
```

---

## Demo 3: Audio Transcription (2 minutes)

**Type in WhatsApp**:
```
Let's try audio transcription
```

**Agent's response** (expected):
Agent explains how to send a voice message.

**Say to audience**:
"Voice messages are very popular in many regions - this feature makes them searchable and actionable in Salesforce."

**Action**: 
1. Tap and hold the microphone icon in WhatsApp
2. Record a message: "This is a test of the audio transcription feature. It converts my voice to text automatically."
3. Release to send

**What happens behind the scenes** (explain while waiting):
"Similar to images:
1. Audio file is downloaded to Salesforce
2. WhatsAppMediaHandler detects it's an audio file
3. Calls the configured audio transcription Flow
4. The Flow transcribes speech to text (using your configured AI service)
5. Transcription is sent back as a text message
6. Agentforce receives and processes it"

**Show on screen** (if possible):
- WhatsApp_Media__c record with audio metadata
- WhatsApp_Log__c showing AUDIO_TRANSCRIPTION_* entries

**Agent's response** (expected):
Agent receives the transcription and acknowledges it.

**Say to audience**:
"The agent can now respond to what I said in the voice message. The transcription is stored permanently, making voice messages searchable in Salesforce. This is huge for:
- Customer service quality monitoring
- Compliance and record-keeping
- Multilingual support (transcribe then translate)
- Voice-based orders or requests"

**Type in WhatsApp**:
```
Perfect! One more to go
```

---

## Demo 4: Document Processing (3 minutes)

**Type in WhatsApp**:
```
Show me document processing
```

**Agent's response** (expected):
Agent explains how to send a document.

**Say to audience**:
"Last but not least - automatic document processing. This works with PDFs, Word documents, Excel files, and more."

**Action**: 
1. Tap the + (or paperclip) icon
2. Select "Document"
3. Choose a prepared PDF (e.g., invoice, contract, product spec)
4. Send

**What happens behind the scenes** (explain while waiting):
"Document processing pipeline:
1. File is downloaded to Salesforce ContentVersion
2. WhatsAppMediaHandler detects it's a document type
3. Calls the WhatsApp_File_Processing_Template Flow
4. The Flow uses GPT-4o to analyze the document content
5. Generates a structured summary: document type, main subject, key info, notable details
6. Summary is sent back as a text message
7. Agentforce receives it and has full context about the document"

**Time estimate**: "This takes 5-10 seconds depending on document size."

**Show on screen** (if possible):
- WhatsApp_Media__c record with document metadata
- The actual file in Salesforce Files
- WhatsApp_Log__c showing processing

**Agent's response** (expected):
Agent receives the document analysis and explains what was found.

**Say to audience**:
"The agent now understands the document content without having to actually open it. Use cases:
- Contract review and approval workflows
- Invoice processing and verification
- Compliance document validation
- Product spec clarification
- Order form processing

The document is permanently stored in Salesforce Files, linked to this conversation, and the summary is searchable."

---

## Wrap-up (2 minutes)

**Type in WhatsApp**:
```
Thank you for the demo!
```

**Agent's response** (expected):
Agent wraps up and asks if there's anything else.

**Type in WhatsApp**:
```
No, that's all. Goodbye!
```

### Closing Points

**Say to audience**:
"So what did we just see?

**Architecture Highlights:**
1. **Zero manual intervention** - Everything is automated
2. **Real-time processing** - Sub-second response times for text, 3-10 seconds for media
3. **Secure webhook validation** - HMAC-SHA256 signature verification
4. **Platform Events** - Decoupled, scalable architecture
5. **Queueable patterns** - Async processing for media
6. **Flow-based extensibility** - Admins can customize AI processing without code
7. **Full audit trail** - Every message, media file, and log entry is stored

**Key Components:**
- 7 custom objects for data model
- 33 Apex classes for business logic
- 5 Lightning Web Components for UI
- Platform Events for message routing
- Trigger-based media processing
- Agentforce AI integration
- Flow templates for AI features

**What's unique:**
- Complete WhatsApp Business API integration
- All message types supported (text, media, location, contacts, interactive, templates)
- Automatic media processing with AI
- Agentforce conversation management
- Real customer conversations in Salesforce

**Business Value:**
- Customers stay on their preferred channel (WhatsApp)
- AI handles routine inquiries 24/7
- Rich media creates actionable data
- Full CRM integration for context
- Searchable conversation history
- Automated workflows triggered by messages

Questions?"

---

## Backup Scenarios

### If Something Doesn't Work

**If the agent doesn't respond:**
- Check WhatsApp_Log__c for errors
- Verify webhook URL is accessible
- Check Agentforce agent is active
- Show the troubleshooting process itself as part of the demo

**If media processing is slow:**
- Explain that external APIs (OpenAI, etc.) can have latency
- Show the queued jobs in Setup → Apex Jobs
- Demonstrate the async architecture as a feature

**If image analysis fails:**
- Check that the Prompt Template is activated
- Verify the Flow is Active (not Draft)
- Show the error handling in WhatsApp_Log__c
- Explain the importance of error logging

### Technical Deep-Dive (if requested)

**Show in Salesforce:**
1. **Data Model**: WhatsApp_Conversation__c, WhatsApp_Message__c, WhatsApp_Media__c records
2. **Logs**: WhatsApp_Log__c with action codes and timestamps
3. **Platform Events**: Event monitoring in Setup
4. **Apex Jobs**: Show queueables in execution
5. **Flows**: WhatsApp_Image_Analysis_Template structure
6. **Prompt Templates**: WhatsApp_Image_Analysis configuration
7. **Agent**: WhatsApp_Demo_Agent topics and instructions

**Show the Code** (if technical audience):
- `WhatsAppWebhookHandler.cls` - Webhook entry point
- `WhatsAppAgentforceService.cls` - AI integration
- `WhatsAppMediaHandler.cls` - Media download logic
- `WhatsAppImageAnalysisQueueable.cls` - Async processing
- `WhatsAppMediaFlowService.cls` - Generic Flow invocation pattern

---

## Demo Checklist

**Before Demo:**
- [ ] Verify WhatsApp business number is accessible
- [ ] Activate WhatsApp_Demo_Agent
- [ ] Prepare demo files: 1 image, 1 PDF
- [ ] Test webhook connectivity
- [ ] Clear any old test conversations
- [ ] Open Salesforce tabs: WhatsApp_Log__c list view, Conversations, Messages
- [ ] Charge phone (voice demos use battery)
- [ ] Connect to stable WiFi

**During Demo:**
- [ ] Share phone screen (if remote demo)
- [ ] Share Salesforce screen to show records
- [ ] Speak clearly and explain each step
- [ ] Show backend processing while waiting
- [ ] Reference architecture components
- [ ] Highlight business value for each feature

**After Demo:**
- [ ] Show final conversation record in Salesforce
- [ ] Show all media files stored in ContentVersion
- [ ] Show logs for full audit trail
- [ ] Answer questions
- [ ] Provide documentation (CLAUDE.md)

---

## Common Questions & Answers

**Q: How much does this cost?**
A: Costs include: WhatsApp Business API fees (per message), Salesforce licenses (Platform or Enterprise), and AI API costs (OpenAI for vision/transcription). Typical cost per conversation: $0.10-$0.50.

**Q: Does this scale?**
A: Yes - Platform Events and Queueable patterns scale to thousands of conversations. We handle bursts via async processing and governor limits are well within bounds.

**Q: What about privacy/GDPR?**
A: All data is stored in Salesforce with standard security. Messages can be encrypted at rest, audit trails exist for access, and customers can request deletion. WhatsApp itself is end-to-end encrypted.

**Q: Can we customize the agent responses?**
A: Absolutely - the agent uses Agent Script (code-first) or the UI Builder. The instructions are fully customizable. You can also change the AI models, add custom actions, or integrate with external systems.

**Q: What about languages?**
A: WhatsApp supports 60+ languages. Agentforce supports multilingual conversations. The AI models (GPT-4o) handle 50+ languages for vision and transcription.

**Q: Can this integrate with Service Cloud?**
A: Yes - conversations can create Cases, link to Contacts, route to Omni-Channel queues, and trigger any standard Salesforce automation (Flows, Process Builder, Apex).

**Q: How hard was this to build?**
A: The core integration is about 3000 lines of Apex, 5 LWCs, and configuration. Development time: 2-3 weeks for core features, 1-2 weeks for AI enhancements. It's production-ready and following Salesforce best practices.
