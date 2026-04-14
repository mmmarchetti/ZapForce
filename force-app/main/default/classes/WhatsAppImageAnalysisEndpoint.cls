/**
 * @description REST endpoint for image analysis using ConnectApi Prompt Templates.
 *              ConnectApi.EinsteinLLM requires a licensed user context — it fails
 *              when called from the Automated Process user (Platform Event / Queueable chains).
 *              This endpoint is called via loopback HTTP from WhatsAppImageAnalysisQueueable
 *              using a JWT token from the Connected App, which runs the request as the
 *              Connected App's Run-As user (a real licensed user).
 */
@RestResource(urlMapping='/whatsapp/image-analysis')
global without sharing class WhatsAppImageAnalysisEndpoint {

    @HttpPost
    global static void analyzeImage() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        try {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            String contentDocumentId = (String) body.get('contentDocumentId');

            if (String.isBlank(contentDocumentId)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                    'error' => 'contentDocumentId is required'
                }));
                return;
            }

            String result = WhatsAppImageAnalysisService.analyzeImageByDocument(contentDocumentId);

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'result' => result
            }));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'error' => e.getMessage()
            }));
        }
    }
}
