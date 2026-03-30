public with sharing class WhatsAppEscalateAction {

    public class EscalateRequest {
        @InvocableVariable(required=true label='Conversation ID')
        public String conversationId;

        @InvocableVariable(label='Subject' description='Case subject for escalation')
        public String subject;

        @InvocableVariable(label='Description' description='Case description')
        public String description;

        @InvocableVariable(label='Notify Customer' description='Send notification to customer')
        public Boolean notifyCustomer;
    }

    public class EscalateResult {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String caseId;
        @InvocableVariable public String caseNumber;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Escalate WhatsApp Conversation'
                     description='Creates a Case and escalates the WhatsApp conversation to a human agent'
                     category='WhatsApp')
    public static List<EscalateResult> escalate(List<EscalateRequest> requests) {
        List<EscalateResult> results = new List<EscalateResult>();
        for (EscalateRequest req : requests) {
            EscalateResult result = new EscalateResult();
            try {
                WhatsApp_Conversation__c conv = [
                    SELECT Id, Contact__c, Case__c, Customer_Phone__c
                    FROM WhatsApp_Conversation__c
                    WHERE Id = :req.conversationId
                    LIMIT 1
                ];

                // Create case if none exists
                Id caseId = conv.Case__c;
                if (caseId == null) {
                    Case newCase = new Case(
                        Subject = String.isNotBlank(req.subject) ? req.subject : 'WhatsApp Escalation',
                        Description = req.description,
                        ContactId = conv.Contact__c,
                        Origin = 'WhatsApp',
                        Status = 'New',
                        Priority = 'Medium'
                    );
                    insert newCase;
                    caseId = newCase.Id;

                    conv.Case__c = caseId;
                    update conv;
                }

                Case theCase = [SELECT Id, CaseNumber FROM Case WHERE Id = :caseId LIMIT 1];
                result.caseId = caseId;
                result.caseNumber = theCase.CaseNumber;
                result.success = true;

                // Notify customer if requested
                if (req.notifyCustomer == true) {
                    String notifyMsg = 'Your conversation has been escalated to a human agent. ' +
                                      'Your case reference is: ' + theCase.CaseNumber + '. ' +
                                      'An agent will be with you shortly.';
                    WhatsAppAPIService.sendTextMessage(conv.Customer_Phone__c, notifyMsg);
                }

            } catch (Exception e) {
                result.success = false;
                result.errorMessage = e.getMessage();
            }
            results.add(result);
        }
        return results;
    }
}
