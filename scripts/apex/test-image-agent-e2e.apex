/**
 * End-to-end test: WhatsApp Image Analysis Agent
 *
 * Tests the full flow:
 * 1. Create session with Image Analysis Agent
 * 2. Send "hello" → agent should ask for an image
 * 3. Pre-analyze the image via WhatsAppImageAnalysisService (like processMessage does)
 * 4. Send "Customer sent an image. Image analysis result: [result]" → agent responds
 * 5. Display all responses
 *
 * Uses conversation a0GWs00000GzGhlMAF which has a completed image download.
 */

String AGENT_API_BASE = 'https://api.salesforce.com/einstein/ai-agent/v1';
String agentId = '0XxWs0000013MhlKAE'; // Image Analysis Agent
String conversationId = 'a0GWs00000GzGhlMAF'; // Conversation with downloaded image
Integer sequenceId = 0;

System.debug('========================================');
System.debug('  IMAGE ANALYSIS AGENT - E2E TEST');
System.debug('========================================');

// Step 0: Verify the image and pre-analyze it
List<WhatsApp_Media__c> images = [
    SELECT Id, Download_Status__c, ContentVersion_ID__c, MIME_Type__c
    FROM WhatsApp_Media__c
    WHERE Message__r.Conversation__c = :conversationId
      AND Media_Type__c = 'Image'
      AND Message__r.Direction__c = 'Inbound'
    ORDER BY CreatedDate DESC
    LIMIT 1
];
if (images.isEmpty()) {
    System.debug('ERROR: No image found in conversation');
    return;
}
System.debug('Image: ' + images[0].Id + ' | Status: ' + images[0].Download_Status__c);

// Pre-analyze the image using Prompt Template (like processMessage does)
ContentVersion cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :images[0].ContentVersion_ID__c LIMIT 1];
System.debug('ContentDocumentId: ' + cv.ContentDocumentId);
String imageAnalysis = WhatsAppImageAnalysisService.analyzeImageByDocument(cv.ContentDocumentId);
System.debug('Pre-analysis result: ' + imageAnalysis);

// Step 1: Get auth token
System.debug('\n--- STEP 1: Authenticating ---');
String token = WhatsAppAuthService.getAgentforceAccessToken();
if (String.isBlank(token)) {
    System.debug('ERROR: No token');
    return;
}
System.debug('Token: OK');

// Step 2: Create agent session
System.debug('\n--- STEP 2: Creating Session ---');
String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
Blob b = Crypto.generateAesKey(128);
String hex = EncodingUtil.convertToHex(b);
String sessionKey = hex.substring(0,8) + '-' + hex.substring(8,12) + '-' +
                    hex.substring(12,16) + '-' + hex.substring(16,20) + '-' +
                    hex.substring(20,32);

HttpRequest req = new HttpRequest();
req.setEndpoint(AGENT_API_BASE + '/agents/' + agentId + '/sessions');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setHeader('Authorization', 'Bearer ' + token);
req.setBody(JSON.serialize(new Map<String, Object>{
    'externalSessionKey' => sessionKey,
    'instanceConfig' => new Map<String, Object>{ 'endpoint' => instanceUrl },
    'bypassUser' => true
}));
req.setTimeout(120000);

Http http = new Http();
HttpResponse res = http.send(req);
if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
    System.debug('ERROR: Session creation failed: HTTP ' + res.getStatusCode());
    return;
}
Map<String, Object> sessionResp = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
String sessionId = (String) sessionResp.get('sessionId');
System.debug('Session: ' + sessionId);

// Step 3: Send "hello"
System.debug('\n--- STEP 3: Sending "hello" ---');
sequenceId++;
req = new HttpRequest();
req.setEndpoint(AGENT_API_BASE + '/sessions/' + sessionId + '/messages');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setHeader('Authorization', 'Bearer ' + token);
req.setBody(JSON.serialize(new Map<String, Object>{
    'message' => new Map<String, Object>{ 'sequenceId' => sequenceId, 'type' => 'Text', 'text' => 'hello' },
    'variables' => new List<Map<String, Object>>{
        new Map<String, Object>{ 'name' => 'conversationId', 'type' => 'Text', 'value' => conversationId }
    }
}));
req.setTimeout(120000);

res = http.send(req);
System.debug('HTTP ' + res.getStatusCode());
if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
    Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    List<Object> messages = (List<Object>) respMap.get('messages');
    if (messages != null) {
        for (Object msgObj : messages) {
            Map<String, Object> msg = (Map<String, Object>) msgObj;
            String text = (String) msg.get('message');
            if (String.isBlank(text)) text = (String) msg.get('text');
            System.debug('>> AGENT (greeting): ' + text);
        }
    }
}

// Step 4: Send image with pre-analysis (simulating processMessage behavior)
System.debug('\n--- STEP 4: Sending image with analysis ---');
sequenceId++;
String userInput = 'Customer sent an image.';
if (String.isNotBlank(imageAnalysis) && !imageAnalysis.startsWith('Error:')) {
    userInput += ' Image analysis result: ' + imageAnalysis;
}
System.debug('User input: ' + userInput.abbreviate(200));

req = new HttpRequest();
req.setEndpoint(AGENT_API_BASE + '/sessions/' + sessionId + '/messages');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setHeader('Authorization', 'Bearer ' + token);
req.setBody(JSON.serialize(new Map<String, Object>{
    'message' => new Map<String, Object>{ 'sequenceId' => sequenceId, 'type' => 'Text', 'text' => userInput },
    'variables' => new List<Map<String, Object>>{
        new Map<String, Object>{ 'name' => 'conversationId', 'type' => 'Text', 'value' => conversationId }
    }
}));
req.setTimeout(120000);

res = http.send(req);
System.debug('HTTP ' + res.getStatusCode());
if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
    Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    List<Object> messages = (List<Object>) respMap.get('messages');
    if (messages != null) {
        for (Object msgObj : messages) {
            Map<String, Object> msg = (Map<String, Object>) msgObj;
            String text = (String) msg.get('message');
            if (String.isBlank(text)) text = (String) msg.get('text');
            System.debug('>> AGENT (image response): ' + text);
        }
    }
}

// Step 5: End session
System.debug('\n--- STEP 5: Ending session ---');
req = new HttpRequest();
req.setEndpoint(AGENT_API_BASE + '/sessions/' + sessionId);
req.setMethod('DELETE');
req.setHeader('Authorization', 'Bearer ' + token);
req.setTimeout(30000);
res = http.send(req);

System.debug('\n========================================');
System.debug('  TEST COMPLETE');
System.debug('========================================');
