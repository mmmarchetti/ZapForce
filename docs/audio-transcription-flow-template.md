# Audio Transcription Flow Template

This template defines the minimum contract expected by `WhatsAppAudioTranscriptionService`.

## Flow Type

- **Autolaunched Flow** (no screens)
- **API Name**: set this value in `WhatsApp_Configuration__c.Audio_Transcription_Flow_API_Name__c`

## Input Variable

Create one Flow variable:

- **API Name**: `contentDocumentId`
- **Data Type**: `Text`
- **Available for input**: `true`
- **Available for output**: `false`

## Output Variable

Create one Flow variable:

- **API Name**: `transcription`
- **Data Type**: `Text`
- **Available for input**: `false`
- **Available for output**: `true`

## Suggested Flow Steps

1. **Get ContentDocument**
   - Object: `ContentDocument`
   - Filter: `Id Equals {!contentDocumentId}`
2. **Get Latest ContentVersion**
   - Object: `ContentVersion`
   - Filter: `ContentDocumentId Equals {!contentDocumentId}`
   - Sort: `CreatedDate Desc`
   - Store first record only
3. **Call your transcription action**
   - Could be Apex Action, External Service, Prompt/AI action, or HTTP-callout-backed invocable
   - Input should use file reference from the ContentVersion retrieved above
4. **Set output**
   - Assignment: `transcription = <text returned by your transcription step>`
5. **Finish**

## Validation Notes

- Return plain text only in `transcription`.
- If transcription fails, you can return empty text; Apex will log `AUDIO_TRANSCRIPTION_EMPTY`.
- Keep output length reasonable (WhatsApp text limits apply when sent onward to Agentforce response flow).
