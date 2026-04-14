public with sharing class WhatsAppAudioTranscriptionService {

    public static String transcribeAudio(Id contentDocumentId) {
        String flowApiName = WhatsAppConfigService.getAudioTranscriptionFlowApiName();
        if (String.isBlank(flowApiName)) {
            WhatsAppLogService.logWarn(
                'AUDIO_TRANSCRIPTION_FLOW_NOT_CONFIGURED',
                'WhatsAppAudioTranscriptionService.transcribeAudio',
                'No flow configured in Audio_Transcription_Flow_API_Name__c.',
                null
            );
            return null;
        }

        try {
            Invocable.Action action = Invocable.Action.createCustomAction('flow', flowApiName);
            action.setInvocationParameter('contentDocumentId', String.valueOf(contentDocumentId));

            List<Invocable.Action.Result> results = action.invoke();
            if (results == null || results.isEmpty()) {
                WhatsAppLogService.logWarn(
                    'AUDIO_TRANSCRIPTION_FLOW_NO_RESULT',
                    'WhatsAppAudioTranscriptionService.transcribeAudio',
                    'Flow returned no results for flow=' + flowApiName +
                    ', contentDocumentId=' + String.valueOf(contentDocumentId),
                    null
                );
                return null;
            }

            Invocable.Action.Result first = results[0];
            if (!first.isSuccess()) {
                WhatsAppLogService.log(
                    'WARN',
                    'AUDIO_TRANSCRIPTION_FLOW_FAILED',
                    'WhatsAppAudioTranscriptionService.transcribeAudio',
                    'Flow execution failed for flow=' + flowApiName +
                    ', contentDocumentId=' + String.valueOf(contentDocumentId),
                    JSON.serialize(new Map<String, Object>{
                        'flowApiName' => flowApiName,
                        'contentDocumentId' => String.valueOf(contentDocumentId)
                    }),
                    JSON.serialize(first),
                    null,
                    null,
                    null,
                    null
                );
                return null;
            }

            Map<String, Object> outputs = first.getOutputParameters();
            if (outputs == null) {
                WhatsAppLogService.logWarn(
                    'AUDIO_TRANSCRIPTION_FLOW_EMPTY_OUTPUT',
                    'WhatsAppAudioTranscriptionService.transcribeAudio',
                    'Flow succeeded but output parameters are null for flow=' + flowApiName +
                    ', contentDocumentId=' + String.valueOf(contentDocumentId),
                    null
                );
                return null;
            }

            WhatsAppLogService.log(
                'INFO',
                'AUDIO_TRANSCRIPTION_FLOW_OUTPUT',
                'WhatsAppAudioTranscriptionService.transcribeAudio',
                'Flow succeeded and returned output parameters.',
                JSON.serialize(new Map<String, Object>{
                    'flowApiName' => flowApiName,
                    'contentDocumentId' => String.valueOf(contentDocumentId)
                }),
                JSON.serialize(outputs),
                null,
                null,
                null,
                null
            );

            if (outputs.containsKey('transcription')) {
                return (String) outputs.get('transcription');
            }

            WhatsAppLogService.logWarn(
                'AUDIO_TRANSCRIPTION_FLOW_MISSING_TRANSCRIPTION_KEY',
                'WhatsAppAudioTranscriptionService.transcribeAudio',
                'Flow output does not contain "transcription" key for flow=' + flowApiName,
                null
            );
            return null;
        } catch (Exception e) {
            WhatsAppLogService.logError(
                'AUDIO_TRANSCRIPTION_EXCEPTION',
                'WhatsAppAudioTranscriptionService.transcribeAudio',
                'Transcription flow execution failed: ' + e.getMessage(),
                null,
                null,
                e.getStackTraceString(),
                null
            );
            return null;
        }
    }
}
