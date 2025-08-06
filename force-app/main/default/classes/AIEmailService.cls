public class AIEmailService {
    
    public class EmailDraftResponse {
        @AuraEnabled public String draftContent;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
    }
    
    @AuraEnabled
    public static EmailDraftResponse generateDraft(String recordId, String emailType) {
        EmailDraftResponse response = new EmailDraftResponse();
        response.success = false;
        
        try {
            // Get customer data from the record
            String customerData = getCustomerData(recordId);
            
            // Create email prompt
            String prompt = createEmailPrompt(emailType, customerData);
            
            // Call OpenAI API directly (no server required)
            String aiResponse = callOpenAIGateway(prompt);
            
            if (aiResponse != null && !String.isBlank(aiResponse)) {
                response.draftContent = aiResponse;
                response.success = true;
                
                // Save the draft to the custom object
                saveDraft(recordId, emailType, aiResponse);
            } else {
                response.errorMessage = 'Failed to generate content from OpenAI';
            }
            
        } catch (Exception e) {
            response.errorMessage = e.getMessage();
            System.debug('Error generating draft: ' + e.getMessage());
        }
        
        return response;
    }
    
    private static String createEmailPrompt(String emailType, String customerData) {
        String basePrompt = 'Generate a professional email draft for a ' + emailType + ' scenario. ';
        basePrompt += 'Customer information: ' + customerData + '. ';
        basePrompt += 'Make the email personal, professional, and actionable. Include a clear call to action.';
        
        return basePrompt;
    }
    
    private static String callOpenAIGateway(String prompt) {
        try {
            HttpRequest request = new HttpRequest();
            request.setEndpoint('https://api.openai.com/v1/chat/completions');
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            
            // Get API key from custom label
            String apiKey = System.Label.OpenAI_API_Key;
            request.setHeader('Authorization', 'Bearer ' + apiKey);
            
            // Create request body
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
            
            request.setBody(JSON.serialize(requestBody));
            
            Http http = new Http();
            HttpResponse httpResponse = http.send(request);
            
            if (httpResponse.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(httpResponse.getBody());
                List<Object> choices = (List<Object>) responseMap.get('choices');
                
                if (choices != null && choices.size() > 0) {
                    Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
                    Map<String, Object> message = (Map<String, Object>) firstChoice.get('message');
                    return (String) message.get('content');
                }
            }
        } catch (Exception e) {
            System.debug('Error calling OpenAI: ' + e.getMessage());
        }
        
        return null;
    }
    
    private static String getCustomerData(String recordId) {
        try {
            // Try to get Lead data first
            List<Lead> leads = [SELECT Name, Email, Phone, Company FROM Lead WHERE Id = :recordId LIMIT 1];
            if (!leads.isEmpty()) {
                Lead l = leads[0];
                return 'Lead Name: ' + l.Name + 
                       ', Email: ' + (l.Email != null ? l.Email : 'N/A') + 
                       ', Phone: ' + (l.Phone != null ? l.Phone : 'N/A') + 
                       ', Company: ' + (l.Company != null ? l.Company : 'N/A');
            }
            
            // Try Contact
            List<Contact> contacts = [SELECT Name, Email, Phone, Account.Name FROM Contact WHERE Id = :recordId LIMIT 1];
            if (!contacts.isEmpty()) {
                Contact c = contacts[0];
                return 'Contact Name: ' + c.Name + 
                       ', Email: ' + (c.Email != null ? c.Email : 'N/A') + 
                       ', Phone: ' + (c.Phone != null ? c.Phone : 'N/A') + 
                       ', Company: ' + (c.Account != null && c.Account.Name != null ? c.Account.Name : 'N/A');
            }
            
            // Try Account
            List<Account> accounts = [SELECT Name, Phone FROM Account WHERE Id = :recordId LIMIT 1];
            if (!accounts.isEmpty()) {
                Account a = accounts[0];
                return 'Account Name: ' + a.Name + 
                       ', Phone: ' + (a.Phone != null ? a.Phone : 'N/A');
            }
            
        } catch (Exception e) {
            System.debug('Error getting customer data: ' + e.getMessage());
        }
        
        return 'Customer information not available';
    }
    
    private static void saveDraft(String recordId, String emailType, String content) {
        try {
            AI_Email_Draft__c draft = new AI_Email_Draft__c();
            draft.Customer_Record_Id__c = recordId;
            draft.Email_Type__c = emailType;
            draft.Generated_Content__c = content;
            draft.Generated_Date__c = System.now();
            draft.Used_By__c = UserInfo.getUserId();
            
            insert draft;
            System.debug('Draft saved successfully: ' + draft.Id);
        } catch (Exception e) {
            System.debug('Error saving draft: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getSavedDrafts(String recordId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        
        try {
            List<AI_Email_Draft__c> drafts = [
                SELECT Id, Email_Type__c, Generated_Content__c, Generated_Date__c, Used_By__c
                FROM AI_Email_Draft__c 
                WHERE Customer_Record_Id__c = :recordId 
                ORDER BY Generated_Date__c DESC 
                LIMIT 10
            ];
            
            for (AI_Email_Draft__c draft : drafts) {
                Map<String, Object> draftMap = new Map<String, Object>();
                draftMap.put('Id', draft.Id);
                draftMap.put('Email_Type__c', draft.Email_Type__c);
                draftMap.put('Generated_Content__c', draft.Generated_Content__c);
                draftMap.put('Generated_Date__c', draft.Generated_Date__c);
                draftMap.put('Used_By__c', draft.Used_By__c);
                result.add(draftMap);
            }
            
        } catch (Exception e) {
            System.debug('Error retrieving drafts: ' + e.getMessage());
        }
        
        return result;
    }
}