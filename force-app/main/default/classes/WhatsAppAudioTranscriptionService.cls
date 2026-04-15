/**
 * @description Thin wrapper for audio transcription using Flow-based processing.
 *              Delegates to WhatsAppMediaFlowService for actual implementation.
 */
public with sharing class WhatsAppAudioTranscriptionService {
    public static String transcribeAudio(Id contentDocumentId) {
        return WhatsAppMediaFlowService.processMedia(contentDocumentId, WhatsAppMediaFlowService.forAudio());
    }
}
