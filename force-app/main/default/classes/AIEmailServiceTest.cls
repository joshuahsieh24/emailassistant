/**
 * Test version of AIEmailService that uses the OpenAI Gateway
 * This allows parallel testing without affecting production
 */
public class AIEmailServiceTest {
    
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
            // Get customer data
            String customerData = getCustomerData(recordId);
            
            // Create prompt for email generation
            String prompt = createEmailPrompt(emailType, customerData);
            
            // Call OpenAI Gateway instead of OpenAI directly
            String aiResponse = callOpenAIGateway(prompt);
            
            if (aiResponse != null && !String.isBlank(aiResponse)) {
                response.draftContent = aiResponse;
                response.success = true;
            } else {
                response.success = false;
                response.errorMessage = 'Failed to generate email draft';
            }
            
        } catch (Exception e) {
            response.success = false;
            response.errorMessage = 'Error: ' + e.getMessage();
            System.debug('Error in generateDraft: ' + e.getMessage());
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
    
    private static String createEmailPrompt(String emailType, String customerData) {
        String basePrompt = 'Generate a professional email draft for a ' + emailType + ' scenario. ';
        basePrompt += 'Customer information: ' + customerData + '. ';
        basePrompt += 'Make the email personal, professional, and actionable. Include a clear call to action.';
        
        return basePrompt;
    }
    
    private static String callOpenAIGateway(String prompt) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:OpenAI_Gateway_Test/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + 'your-jwt-token-here');
        
        // Create OpenAI-compatible request
        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('model', 'gpt-3.5-turbo');
        requestBody.put('max_tokens', 500);
        requestBody.put('temperature', 0.7);
        
        List<Map<String, String>> messages = new List<Map<String, String>>();
        Map<String, String> message = new Map<String, String>();
        message.put('role', 'user');
        message.put('content', prompt);
        messages.add(message);
        requestBody.put('messages', messages);
        
        req.setBody(JSON.serialize(requestBody));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('Gateway Response Status: ' + res.getStatusCode());
        System.debug('Gateway Response Body: ' + res.getBody());
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> choices = (List<Object>) responseMap.get('choices');
            
            if (choices != null && !choices.isEmpty()) {
                Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
                Map<String, Object> messageMap = (Map<String, Object>) firstChoice.get('message');
                return (String) messageMap.get('content');
            }
        } else {
            System.debug('Gateway Error: ' + res.getBody());
        }
        
        return null;
    }
} 