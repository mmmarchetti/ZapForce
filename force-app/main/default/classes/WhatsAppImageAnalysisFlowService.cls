/**
 * @description Thin wrapper for image analysis using Flow-based processing.
 *              Delegates to WhatsAppMediaFlowService for actual implementation.
 */
public with sharing class WhatsAppImageAnalysisFlowService {
    public static String analyzeImage(Id contentDocumentId) {
        return WhatsAppMediaFlowService.processMedia(contentDocumentId, WhatsAppMediaFlowService.forImage());
    }
}
