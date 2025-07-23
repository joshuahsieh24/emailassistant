public class AIEmailService {
    public class EmailDraftRequest {
        @AuraEnabled public String recordId;
        @AuraEnabled public String emailType;
        @AuraEnabled public String customerName;
        @AuraEnabled public String customerData;
    }
    public class EmailDraftResponse {
        @AuraEnabled public String draftContent;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
    }
    @AuraEnabled
    public static EmailDraftResponse generateDraft(String recordId, String emailType) {
        EmailDraftResponse response = new EmailDraftResponse();
        try {
            String customerData = getCustomerData(recordId);
            String prompt = buildPrompt(emailType, customerData);
            String draftContent = callOpenAI(prompt);
            saveDraft(recordId, emailType, draftContent);
            response.draftContent = draftContent;
            response.success = true;
        } catch (Exception e) {
            response.success = false;
            response.errorMessage = e.getMessage();
            System.debug('Error generating draft: ' + e.getMessage());
        }
        return response;
    }
    private static String getCustomerData(String recordId) {
        // Try Lead first
        List<SObject> leadRecords = Database.query('SELECT Name, Phone, Email FROM Lead WHERE Id = :recordId LIMIT 1');
        if (!leadRecords.isEmpty()) {
            SObject lead = leadRecords[0];
            return 'Lead Name: ' + lead.get('Name') + ', Phone: ' + lead.get('Phone') + ', Email: ' + lead.get('Email');
        }
        // Try Account next
        List<SObject> accountRecords = Database.query('SELECT Name, Phone FROM Account WHERE Id = :recordId LIMIT 1');
        if (!accountRecords.isEmpty()) {
            SObject account = accountRecords[0];
            return 'Account Name: ' + account.get('Name') + ', Phone: ' + account.get('Phone');
        }
        return 'No customer data found';
    }
    private static String buildPrompt(String emailType, String customerData) {
        String basePrompt = 'Generate a professional {emailType} email with the following customer information: {customerData}. ' +
                           'Keep it concise, friendly, and include a clear call to action. ' +
                           'Do not include any placeholder text or bracketed instructions.';
        return basePrompt.replace('{emailType}', emailType)
                        .replace('{customerData}', customerData);
    }
    private static String callOpenAI(String prompt) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.openai.com/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        // Set Bearer token from Custom Label
        String apiKey = Label.OpenAI_API_Key;
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        Map<String, Object> requestBody = new Map<String, Object>{
            'model' => 'gpt-3.5-turbo',
            'messages' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'role' => 'user',
                    'content' => prompt
                }
            },
            'max_tokens' => 500,
            'temperature' => 0.7
        };
        req.setBody(JSON.serialize(requestBody));
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> choices = (List<Object>) responseBody.get('choices');
            Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
            Map<String, Object> message = (Map<String, Object>) firstChoice.get('message');
            return (String) message.get('content');
        } else {
            throw new CalloutException('OpenAI API call failed: ' + res.getBody());
        }
    }
    private static void saveDraft(String recordId, String emailType, String content) {
        AI_Email_Draft__c draft = new AI_Email_Draft__c(
            Customer_Record_Id__c = recordId,
            Email_Type__c = emailType,
            Generated_Content__c = content,
            Used_By__c = UserInfo.getUserId(),
            Generated_Date__c = System.now()
        );
        insert draft;
    }
}
// Note: Add https://api.openai.com to Remote Site Settings in Salesforce Setup.
// Note: Create a Custom Label named 'OpenAI_API_Key' and set its value to your OpenAI API key. 