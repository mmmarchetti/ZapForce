public with sharing class WhatsAppGetCustomerInfoAction {

    public class GetCustomerInfoRequest {
        @InvocableVariable(required=true label='Phone Number' description='Customer WhatsApp phone number')
        public String phoneNumber;
    }

    public class GetCustomerInfoResult {
        @InvocableVariable public Boolean found;
        @InvocableVariable public String contactId;
        @InvocableVariable public String contactName;
        @InvocableVariable public String email;
        @InvocableVariable public String accountName;
        @InvocableVariable public Integer openCaseCount;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Get WhatsApp Customer Info'
                     description='Looks up customer information by phone number'
                     category='WhatsApp')
    public static List<GetCustomerInfoResult> getCustomerInfo(List<GetCustomerInfoRequest> requests) {
        List<GetCustomerInfoResult> results = new List<GetCustomerInfoResult>();
        for (GetCustomerInfoRequest req : requests) {
            GetCustomerInfoResult result = new GetCustomerInfoResult();
            try {
                List<Contact> contacts = [
                    SELECT Id, Name, Email, Account.Name,
                           (SELECT Id FROM Cases WHERE IsClosed = false)
                    FROM Contact
                    WHERE Phone = :req.phoneNumber OR MobilePhone = :req.phoneNumber
                    LIMIT 1
                ];

                if (!contacts.isEmpty()) {
                    Contact c = contacts[0];
                    result.found = true;
                    result.contactId = c.Id;
                    result.contactName = c.Name;
                    result.email = c.Email;
                    result.accountName = c.Account != null ? c.Account.Name : null;
                    result.openCaseCount = c.Cases != null ? c.Cases.size() : 0;
                } else {
                    result.found = false;
                }
            } catch (Exception e) {
                result.found = false;
                result.errorMessage = e.getMessage();
            }
            results.add(result);
        }
        return results;
    }
}
