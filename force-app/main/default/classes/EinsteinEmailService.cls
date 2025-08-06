/**
 * Einstein Email Service - Native Salesforce AI Implementation
 * Uses Salesforce Einstein for secure, on-platform email generation
 */
public class EinsteinEmailService {
    
    public class EmailDraftResponse {
        @AuraEnabled public String draftContent;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
    }
    
    @AuraEnabled
    public static EmailDraftResponse generateDraftWithEinstein(String recordId, String emailType) {
        EmailDraftResponse response = new EmailDraftResponse();
        
        try {
            // Get record data
            Map<String, Object> recordData = getRecordData(recordId);
            
            // Use Einstein Intent API or Flow-based generation
            String emailContent = generateEmailWithFlow(recordData, emailType);
            
            if (String.isNotBlank(emailContent)) {
                response.draftContent = emailContent;
                response.success = true;
                
                // Save using native Salesforce encryption (no custom encryption needed)
                saveDraftNative(recordId, emailType, emailContent);
            } else {
                response.success = false;
                response.errorMessage = 'Einstein email generation failed';
            }
            
        } catch (Exception e) {
            response.success = false;
            response.errorMessage = 'Error: ' + e.getMessage();
            System.debug('Error in generateDraftWithEinstein: ' + e.getMessage());
        }
        
        return response;
    }
    
    private static Map<String, Object> getRecordData(String recordId) {
        Map<String, Object> recordData = new Map<String, Object>();
        
        try {
            // Get SObject type
            Id recordIdObj = (Id) recordId;
            String objectType = recordIdObj.getSObjectType().getDescribe().getName();
            
            // Dynamic SOQL based on object type
            String soql = 'SELECT ';
            
            switch on objectType {
                when 'Lead' {
                    soql += 'Name, Email, Phone, Company FROM Lead WHERE Id = :recordId';
                }
                when 'Account' {
                    soql += 'Name, Phone, Industry FROM Account WHERE Id = :recordId';
                }
                when 'Contact' {
                    soql += 'Name, Email, Phone, Account.Name FROM Contact WHERE Id = :recordId';
                }
                when 'Opportunity' {
                    soql += 'Name, Account.Name, StageName, Amount FROM Opportunity WHERE Id = :recordId';
                }
                when else {
                    soql += 'Name FROM ' + objectType + ' WHERE Id = :recordId';
                }
            }
            
            List<SObject> records = Database.query(soql);
            if (!records.isEmpty()) {
                SObject record = records[0];
                
                // Convert SObject to Map for easier handling
                Map<String, Object> fieldMap = record.getPopulatedFieldsAsMap();
                recordData.putAll(fieldMap);
                recordData.put('ObjectType', objectType);
            }
            
        } catch (Exception e) {
            System.debug('Error getting record data: ' + e.getMessage());
        }
        
        return recordData;
    }
    
    private static String generateEmailWithFlow(Map<String, Object> recordData, String emailType) {
        try {
            // Create Flow inputs
            Map<String, Object> flowInputs = new Map<String, Object>();
            flowInputs.put('recordData', JSON.serialize(recordData));
            flowInputs.put('emailType', emailType);
            
            // Call Flow (you'll create this flow in the next step)
            Flow.Interview emailFlow = Flow.Interview.createInterview('Einstein_Email_Generator', flowInputs);
            emailFlow.start();
            
            // Get output from Flow
            String generatedEmail = (String) emailFlow.getVariableValue('generatedEmailContent');
            
            return generatedEmail;
            
        } catch (Exception e) {
            System.debug('Error in Flow-based generation: ' + e.getMessage());
            
            // Fallback to template-based generation
            return generateTemplateEmail(recordData, emailType);
        }
    }
    
    private static String generateTemplateEmail(Map<String, Object> recordData, String emailType) {
        // Smart template generation based on record data and email type
        String customerName = (String) recordData.get('Name');
        String companyName = (String) recordData.get('Company');
        if (String.isBlank(companyName)) {
            companyName = (String) recordData.get('Account.Name');
        }
        
        Map<String, String> emailTemplates = new Map<String, String>{
            'Renewal' => 'Dear {customerName},\n\nI hope this email finds you well. I wanted to reach out regarding {companyName}\'s upcoming renewal.\n\nOur partnership has been valuable, and I\'d love to discuss how we can continue supporting your goals in the coming year.\n\nWould you be available for a brief call this week to discuss renewal terms?\n\nBest regards,\n[Your Name]',
            
            'Upsell' => 'Hi {customerName},\n\nI\'ve been reviewing {companyName}\'s account and noticed some exciting opportunities to enhance your current solution.\n\nBased on your usage patterns, I believe our premium features could deliver significant additional value for your team.\n\nWould you be interested in a quick demo to see how these enhancements could benefit {companyName}?\n\nLooking forward to hearing from you!\n\n[Your Name]',
            
            'Welcome' => 'Welcome to our platform, {customerName}!\n\nWe\'re excited to have {companyName} as our newest client. Your account is now set up and ready to go.\n\nTo help you get started, I\'ve scheduled a welcome call for next week. In the meantime, feel free to explore your dashboard and reach out if you have any questions.\n\nThank you for choosing us!\n\nBest,\n[Your Name]'
        };
        
        String template = emailTemplates.get(emailType);
        if (String.isBlank(template)) {
            template = 'Dear {customerName},\n\nThank you for your continued partnership with our team.\n\nI wanted to reach out regarding your account and see how we can better support {companyName}.\n\nPlease let me know if you\'d like to schedule a call to discuss.\n\nBest regards,\n[Your Name]';
        }
        
        // Replace placeholders
        template = template.replace('{customerName}', String.isNotBlank(customerName) ? customerName : 'Valued Customer');
        template = template.replace('{companyName}', String.isNotBlank(companyName) ? companyName : 'your organization');
        
        return template;
    }
    
    private static void saveDraftNative(String recordId, String emailType, String content) {
        try {
            // Use standard Salesforce object - no custom encryption needed if using Shield
            AI_Email_Draft__c draft = new AI_Email_Draft__c(
                Customer_Record_Id__c = recordId,
                Email_Type__c = emailType,
                Generated_Content__c = content, // Salesforce handles encryption automatically with Shield
                Used_By__c = UserInfo.getUserId(),
                Generated_Date__c = System.now(),
                Generation_Method__c = 'Einstein'
            );
            insert draft;
            System.debug('Einstein draft saved successfully: ' + draft.Id);
        } catch (Exception e) {
            System.debug('Error saving Einstein draft: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEinsteinDrafts(String recordId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        try {
            List<AI_Email_Draft__c> drafts = [
                SELECT Id, Email_Type__c, Generated_Content__c, Generated_Date__c, Used_By__c, Generation_Method__c
                FROM AI_Email_Draft__c 
                WHERE Customer_Record_Id__c = :recordId 
                AND Generation_Method__c = 'Einstein'
                ORDER BY Generated_Date__c DESC 
                LIMIT 10
            ];
            
            for (AI_Email_Draft__c draft : drafts) {
                Map<String, Object> draftMap = new Map<String, Object>();
                draftMap.put('Id', draft.Id);
                draftMap.put('Email_Type__c', draft.Email_Type__c);
                draftMap.put('Generated_Content__c', draft.Generated_Content__c); // Salesforce auto-decrypts if Shield enabled
                draftMap.put('Generated_Date__c', draft.Generated_Date__c);
                draftMap.put('Used_By__c', draft.Used_By__c);
                draftMap.put('Generation_Method__c', 'Einstein');
                result.add(draftMap);
            }
            
        } catch (Exception e) {
            System.debug('Error retrieving Einstein drafts: ' + e.getMessage());
        }
        return result;
    }
}