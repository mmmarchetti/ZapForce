/**
 * @description Generic service for invoking Flow-based media processing (audio, image, etc.).
 *              Uses configuration wrapper pattern to handle media-specific settings.
 *              Eliminates code duplication between audio transcription and image analysis.
 */
public with sharing class WhatsAppMediaFlowService {
    /**
     * @description Configuration wrapper for media-specific settings
     */
    public class MediaFlowConfig {
        public String flowApiName;
        public String outputKey;
        public String logPrefix;
    }

    /**
     * @description Factory method for audio transcription configuration
     */
    public static MediaFlowConfig forAudio() {
        MediaFlowConfig config = new MediaFlowConfig();
        config.flowApiName = WhatsAppConfigService.getAudioTranscriptionFlowApiName();
        config.outputKey = 'transcription';
        config.logPrefix = 'AUDIO_TRANSCRIPTION';
        return config;
    }

    /**
     * @description Factory method for image analysis configuration
     */
    public static MediaFlowConfig forImage() {
        MediaFlowConfig config = new MediaFlowConfig();
        config.flowApiName = WhatsAppConfigService.getImageAnalysisFlowApiName();
        config.outputKey = 'analysis';
        config.logPrefix = 'IMAGE_ANALYSIS';
        return config;
    }

    /**
     * @description Factory method for file processing configuration
     */
    public static MediaFlowConfig forFile() {
        MediaFlowConfig config = new MediaFlowConfig();
        config.flowApiName = WhatsAppConfigService.getFileProcessingFlowApiName();
        config.outputKey = 'content';
        config.logPrefix = 'FILE_PROCESSING';
        return config;
    }

    /**
     * @description Generic method to process media by invoking configured Flow
     * @param contentDocumentId The ContentDocument ID of the media file
     * @param config Media-specific configuration (flow name, output key, log prefix)
     * @return The output string from the Flow, or null if processing failed
     */
    public static String processMedia(Id contentDocumentId, MediaFlowConfig config) {
        if (String.isBlank(config.flowApiName)) {
            WhatsAppLogService.logWarn(
                config.logPrefix + '_FLOW_NOT_CONFIGURED',
                'WhatsAppMediaFlowService.processMedia',
                'No flow configured for ' + config.logPrefix + '.',
                null
            );
            return null;
        }

        try {
            Invocable.Action action = Invocable.Action.createCustomAction('flow', config.flowApiName);
            action.setInvocationParameter('contentDocumentId', String.valueOf(contentDocumentId));

            List<Invocable.Action.Result> results = action.invoke();
            if (results == null || results.isEmpty()) {
                WhatsAppLogService.logWarn(
                    config.logPrefix + '_FLOW_NO_RESULT',
                    'WhatsAppMediaFlowService.processMedia',
                    'Flow returned no results for flow=' +
                        config.flowApiName +
                        ', contentDocumentId=' +
                        String.valueOf(contentDocumentId),
                    null
                );
                return null;
            }

            Invocable.Action.Result first = results[0];
            if (!first.isSuccess()) {
                WhatsAppLogService.log(
                    'WARN',
                    config.logPrefix + '_FLOW_FAILED',
                    'WhatsAppMediaFlowService.processMedia',
                    'Flow execution failed for flow=' +
                        config.flowApiName +
                        ', contentDocumentId=' +
                        String.valueOf(contentDocumentId),
                    JSON.serialize(
                        new Map<String, Object>{
                            'flowApiName' => config.flowApiName,
                            'contentDocumentId' => String.valueOf(contentDocumentId)
                        }
                    ),
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
                    config.logPrefix + '_FLOW_EMPTY_OUTPUT',
                    'WhatsAppMediaFlowService.processMedia',
                    'Flow succeeded but output parameters are null for flow=' +
                        config.flowApiName +
                        ', contentDocumentId=' +
                        String.valueOf(contentDocumentId),
                    null
                );
                return null;
            }

            WhatsAppLogService.log(
                'INFO',
                config.logPrefix + '_FLOW_OUTPUT',
                'WhatsAppMediaFlowService.processMedia',
                'Flow succeeded and returned output parameters.',
                JSON.serialize(
                    new Map<String, Object>{
                        'flowApiName' => config.flowApiName,
                        'contentDocumentId' => String.valueOf(contentDocumentId)
                    }
                ),
                JSON.serialize(outputs),
                null,
                null,
                null,
                null
            );

            if (outputs.containsKey(config.outputKey)) {
                return (String) outputs.get(config.outputKey);
            }

            WhatsAppLogService.logWarn(
                config.logPrefix + '_FLOW_MISSING_OUTPUT_KEY',
                'WhatsAppMediaFlowService.processMedia',
                'Flow output does not contain "' + config.outputKey + '" key for flow=' + config.flowApiName,
                null
            );
            return null;
        } catch (Exception e) {
            WhatsAppLogService.logError(
                config.logPrefix + '_EXCEPTION',
                'WhatsAppMediaFlowService.processMedia',
                'Media flow execution failed: ' + e.getMessage(),
                null,
                null,
                e.getStackTraceString(),
                null
            );
            return null;
        }
    }
}
