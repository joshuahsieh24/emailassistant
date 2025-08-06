// Debug script to test AIEmailService
String recordId = '001XXXXXXXXXXXXXXX'; // Replace with actual record ID
String emailType = 'Renewal';

try {
    AIEmailService.EmailDraftResponse response = AIEmailService.generateDraft(recordId, emailType);
    System.debug('Response: ' + response);
    System.debug('Success: ' + response.success);
    System.debug('Content: ' + response.draftContent);
    System.debug('Error: ' + response.errorMessage);
} catch (Exception e) {
    System.debug('Exception: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
} 