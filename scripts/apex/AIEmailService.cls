public class AIEmailService {
    
    // Encryption key should be stored securely - consider using Named Credentials or Custom Settings
    private static final String ENCRYPTION_KEY = 'MySecureKey123456'; // 16 characters for AES-128
    
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
            CustomerInfo customerInfo = getCustomerData(recordId);
            
            // Create anonymized prompt (no real customer data sent to OpenAI)
            String prompt = buildPrompt(emailType, customerInfo);
            
            // Call OpenAI with anonymized data
            String draftContent = callOpenAI(prompt);
            
            // Personalize the response with actual customer data
            String personalizedDraft = personalizeDraft(draftContent, customerInfo);
            
            // Save encrypted draft
            saveDraft(recordId, emailType, personalizedDraft);
            
            response.draftContent = personalizedDraft;
            response.success = true;
        } catch (Exception e) {
            response.success = false;
            response.errorMessage = e.getMessage();
            System.debug('Error generating draft: ' + e.getMessage());
        }
        return response;
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
            
            // Decrypt content and prepare for LWC consumption
            for (AI_Email_Draft__c draft : drafts) {
                Map<String, Object> draftMap = new Map<String, Object>();
                draftMap.put('Id', draft.Id);
                draftMap.put('Email_Type__c', draft.Email_Type__c);
                draftMap.put('Generated_Content__c', decryptData(draft.Generated_Content__c));
                draftMap.put('Generated_Date__c', draft.Generated_Date__c);
                draftMap.put('Used_By__c', draft.Used_By__c);
                result.add(draftMap);
            }
            
        } catch (Exception e) {
            System.debug('Error retrieving drafts: ' + e.getMessage());
        }
        return result;
    }
    
    // Inner class to hold customer information
    private class CustomerInfo {
        public String name;
        public String email;
        public String phone;
        public String recordType;
        public String companyName;
    }
    
    private static CustomerInfo getCustomerData(String recordId) {
        CustomerInfo info = new CustomerInfo();
        
        try {
            // Try Lead first
            List<Lead> leadRecords = [SELECT Name, Email, Phone, Company FROM Lead WHERE Id = :recordId LIMIT 1];
            if (!leadRecords.isEmpty()) {
                Lead lead = leadRecords[0];
                info.name = lead.Name;
                info.email = lead.Email;
                info.phone = lead.Phone;
                info.companyName = lead.Company;
                info.recordType = 'Lead';
                return info;
            }
            
            // Try Account next
            List<Account> accountRecords = [SELECT Name, Phone FROM Account WHERE Id = :recordId LIMIT 1];
            if (!accountRecords.isEmpty()) {
                Account account = accountRecords[0];
                info.name = account.Name;
                info.phone = account.Phone;
                info.companyName = account.Name;
                info.recordType = 'Account';
                return info;
            }
            
            // Try Contact
            List<Contact> contactRecords = [SELECT Name, Email, Phone, Account.Name FROM Contact WHERE Id = :recordId LIMIT 1];
            if (!contactRecords.isEmpty()) {
                Contact contact = contactRecords[0];
                info.name = contact.Name;
                info.email = contact.Email;
                info.phone = contact.Phone;
                info.companyName = contact.Account?.Name;
                info.recordType = 'Contact';
                return info;
            }
            
            // Try Opportunity
            List<Opportunity> oppRecords = [SELECT Name, Account.Name FROM Opportunity WHERE Id = :recordId LIMIT 1];
            if (!oppRecords.isEmpty()) {
                Opportunity opp = oppRecords[0];
                info.name = opp.Account?.Name;
                info.companyName = opp.Account?.Name;
                info.recordType = 'Opportunity';
                return info;
            }
            
        } catch (Exception e) {
            System.debug('Error retrieving customer data: ' + e.getMessage());
        }
        
        // Default values if no data found
        info.name = 'Valued Customer';
        info.companyName = 'Your Company';
        info.recordType = 'Unknown';
        return info;
    }
    
    private static String buildPrompt(String emailType, CustomerInfo customerInfo) {
        // Create anonymized prompt - no real customer data sent to OpenAI
        String basePrompt = 'Generate a professional {emailType} email template for a {recordType}. ' +
                           'Use placeholder text like [Customer Name] and [Company Name] for personalization. ' +
                           'Keep it concise, friendly, and include a clear call to action. ' +
                           'Make it suitable for a business context. ' +
                           'Do not include any placeholder instructions or bracketed explanations in the final output.';
        
        return basePrompt.replace('{emailType}', emailType.toLowerCase())
                        .replace('{recordType}', customerInfo.recordType.toLowerCase());
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
                    'role' => 'system',
                    'content' => 'You are a professional email assistant. Generate business emails with placeholder text for personalization. Never include real customer data.'
                },
                new Map<String, Object>{
                    'role' => 'user',
                    'content' => prompt
                }
            },
            'max_tokens' => 500,
            'temperature' => 0.7
        };
        
        req.setBody(JSON.serialize(requestBody));
        req.setTimeout(30000); // 30 second timeout
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> choices = (List<Object>) responseBody.get('choices');
            if (choices != null && !choices.isEmpty()) {
                Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
                Map<String, Object> message = (Map<String, Object>) firstChoice.get('message');
                return (String) message.get('content');
            }
        }
        
        throw new CalloutException('OpenAI API call failed: Status ' + res.getStatusCode() + ' - ' + res.getBody());
    }
    
    private static String personalizeDraft(String template, CustomerInfo customerInfo) {
        String personalizedDraft = template;
        
        // Replace common placeholders with actual customer data
        if (String.isNotBlank(customerInfo.name)) {
            personalizedDraft = personalizedDraft.replaceAll('(?i)\\[Customer Name\\]', customerInfo.name);
            personalizedDraft = personalizedDraft.replaceAll('(?i)\\[Name\\]', customerInfo.name);
        }
        
        if (String.isNotBlank(customerInfo.companyName)) {
            personalizedDraft = personalizedDraft.replaceAll('(?i)\\[Company Name\\]', customerInfo.companyName);
            personalizedDraft = personalizedDraft.replaceAll('(?i)\\[Company\\]', customerInfo.companyName);
        }
        
        // Add additional personalization based on record type
        switch on customerInfo.recordType {
            when 'Lead' {
                personalizedDraft = personalizedDraft.replaceAll('(?i)\\[Record Type\\]', 'potential customer');
            }
            when 'Account' {
                personalizedDraft = personalizedDraft.replaceAll('(?i)\\[Record Type\\]', 'valued client');
            }
            when 'Contact' {
                personalizedDraft = personalizedDraft.replaceAll('(?i)\\[Record Type\\]', 'valued contact');
            }
            when 'Opportunity' {
                personalizedDraft = personalizedDraft.replaceAll('(?i)\\[Record Type\\]', 'business opportunity');
            }
        }
        
        return personalizedDraft;
    }
    
    private static void saveDraft(String recordId, String emailType, String content) {
        try {
            // Encrypt sensitive content before saving
            String encryptedContent = encryptData(content);
            
            AI_Email_Draft__c draft = new AI_Email_Draft__c(
                Customer_Record_Id__c = recordId,
                Email_Type__c = emailType,
                Generated_Content__c = encryptedContent, // Store encrypted content
                Used_By__c = UserInfo.getUserId(),
                Generated_Date__c = System.now()
            );
            insert draft;
        } catch (Exception e) {
            System.debug('Error saving draft: ' + e.getMessage());
            // Don't throw exception here to avoid breaking the main flow
        }
    }
    
    // Utility method to encrypt sensitive data
    private static String encryptData(String data) {
        try {
            if (String.isBlank(data)) {
                return data;
            }
            
            Blob key = Blob.valueOf(ENCRYPTION_KEY);
            Blob dataBlob = Blob.valueOf(data);
            Blob encrypted = Crypto.encrypt('AES128', key, dataBlob);
            return EncodingUtil.base64Encode(encrypted);
        } catch (Exception e) {
            System.debug('Error encrypting data: ' + e.getMessage());
            return data; // Return original data if encryption fails
        }
    }
    
    // Utility method to decrypt sensitive data
    private static String decryptData(String encryptedData) {
        try {
            if (String.isBlank(encryptedData)) {
                return encryptedData;
            }
            
            Blob key = Blob.valueOf(ENCRYPTION_KEY);
            Blob encryptedBlob = EncodingUtil.base64Decode(encryptedData);
            Blob decrypted = Crypto.decrypt('AES128', key, encryptedBlob);
            return decrypted.toString();
        } catch (Exception e) {
            System.debug('Error decrypting data: ' + e.getMessage());
            return encryptedData; // Return original data if decryption fails
        }
    }
}

// Implementation Notes:
// 1. Add https://api.openai.com to Remote Site Settings in Salesforce Setup
// 2. Create a Custom Label named 'OpenAI_API_Key' and set its value to your OpenAI API key
// 3. Consider using Named Credentials instead of Custom Labels for better security
// 4. The encryption key should be stored more securely in production (Custom Settings, etc.)
// 5. You may need to create the AI_Email_Draft__c custom object if it doesn't exist