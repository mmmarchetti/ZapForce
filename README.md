# WhatsApp Salesforce Integration

A comprehensive Salesforce application that integrates WhatsApp Business API with Salesforce Agentforce, enabling bidirectional communication, media handling, and AI-powered conversations.

## Features

- **WhatsApp API Integration**: Connect to WhatsApp Business API with configurable credentials
- **Media Support**: Handle photos, videos, audio, and documents from WhatsApp
- **Geolocation**: Support for location sharing from WhatsApp
- **Agentforce Integration**: Enable AI-powered conversations through Salesforce Agentforce
- **Custom Configuration**: User-friendly interface to configure WhatsApp API settings
- **Message Management**: Store and manage all WhatsApp messages, media, and metadata in Salesforce
- **Real-time Conversations**: Handle real-time WhatsApp conversations within Salesforce

## Project Structure

```
force-app/main/default/
├── classes/              # Apex classes for API integration and business logic
├── objects/              # Custom objects for WhatsApp data storage
├── lwc/                  # Lightning Web Components for UI
├── triggers/             # Apex triggers for automation
├── tabs/                 # Custom tabs
├── applications/         # Lightning applications
├── flexipages/           # Lightning pages
├── flows/                # Flows for Agentforce integration
└── permissionsets/       # Permission sets for access control
```

## Prerequisites

- Salesforce org with API access
- WhatsApp Business API account
- Salesforce CLI (sf)
- Node.js and npm (for LWC development)

## Setup

1. Authenticate with your Salesforce org
2. Deploy the metadata to your org
3. Configure WhatsApp API credentials in the configuration page
4. Assign appropriate permission sets to users

## Commands

See CLAUDE.md for detailed development commands and guidelines.

## License

Proprietary
