public with sharing class ComplaintFormController {
    
    @AuraEnabled
    public static ComplaintResult createComplaintCase(String complaintData) {
        ComplaintResult result = new ComplaintResult();
        
        try {
            // Parse the incoming JSON data
            Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(complaintData);
            
            // Create or find contact
            Contact citizenContact = createOrFindContact(
                (String) dataMap.get('contactName'),
                (String) dataMap.get('contactEmail'),
                (String) dataMap.get('contactPhone')
            );
            
            // Create the case
            Case newCase = new Case();
            newCase.Subject = generateSubject((String) dataMap.get('issueType'), (String) dataMap.get('description'));
            newCase.Description = (String) dataMap.get('description');
            newCase.Origin = 'Web';
            newCase.Status = 'New';
            newCase.ContactId = citizenContact.Id;
            
            // Set custom fields
            newCase.Issue_Type__c = (String) dataMap.get('issueType');
            newCase.Subtype__c = (String) dataMap.get('subtype');
            newCase.Severity__c = (String) dataMap.get('severity');
            newCase.Source_Channel__c = 'Web Portal';
            newCase.Address__c = (String) dataMap.get('address');
            
            // Set coordinates if available
            if (dataMap.get('latitude') != null) {
                newCase.Latitude__c = Double.valueOf(dataMap.get('latitude'));
            }
            if (dataMap.get('longitude') != null) {
                newCase.Longitude__c = Double.valueOf(dataMap.get('longitude'));
            }
            
            // Generate tracking token
            newCase.Public_Tracking_Token__c = generateTrackingToken();
            
            // Set SLA due date based on severity
            newCase.SLA_Due__c = calculateSLADueDate((String) dataMap.get('severity'));
            
            insert newCase;
            
            // Create action log entry
            createActionLog(newCase.Id, 'Case Created', 'Complaint submitted via web portal by ' + citizenContact.Name);
            
            // Return success result
            result.success = true;
            result.caseId = newCase.Id;
            result.trackingNumber = newCase.Public_Tracking_Token__c;
            result.message = 'Case created successfully';
            
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
            System.debug('Error creating case: ' + e.getMessage());
        }
        
        return result;
    }
    
    @AuraEnabled
    public static Boolean uploadFile(String parentId, String fileName, String base64Data, String contentType) {
        try {
            // Create ContentVersion (the file)
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.ContentLocation = 'S'; // S = Salesforce
            cv.IsMajorVersion = true;
            
            insert cv;
            
            // Get the ContentDocument Id
            ContentVersion insertedCV = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            
            // Create ContentDocumentLink to associate with the Case
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = insertedCV.ContentDocumentId;
            cdl.LinkedEntityId = parentId; // Case Id
            cdl.ShareType = 'V'; // Viewer permission
            cdl.Visibility = 'AllUsers';
            
            insert cdl;
            
            // Log the file upload
            createActionLog(parentId, 'Photo Uploaded', 'Photo uploaded: ' + fileName);
            
            return true;
            
        } catch (Exception e) {
            System.debug('Error uploading file: ' + e.getMessage());
            return false;
        }
    }
    
    private static Contact createOrFindContact(String name, String email, String phone) {
        // First try to find existing contact by email
        List<Contact> existingContacts = [
            SELECT Id, Name, Email, Phone 
            FROM Contact 
            WHERE Email = :email 
            LIMIT 1
        ];
        
        if (!existingContacts.isEmpty()) {
            Contact existing = existingContacts[0];
            // Update phone if provided and different
            if (String.isNotBlank(phone) && existing.Phone != phone) {
                existing.Phone = phone;
                update existing;
            }
            return existing;
        }
        
        // Create new contact
        Contact newContact = new Contact();
        newContact.FirstName = getFirstName(name);
        newContact.LastName = getLastName(name);
        newContact.Email = email;
        newContact.Phone = phone;
        
        insert newContact;
        return newContact;
    }
    
    private static String getFirstName(String fullName) {
        if (String.isBlank(fullName)) return 'Unknown';
        List<String> nameParts = fullName.split(' ');
        return nameParts[0];
    }
    
    private static String getLastName(String fullName) {
        if (String.isBlank(fullName)) return 'Citizen';
        List<String> nameParts = fullName.split(' ');
        if (nameParts.size() > 1) {
            // Join all parts except the first one
            List<String> lastNameParts = new List<String>();
            for (Integer i = 1; i < nameParts.size(); i++) {
                lastNameParts.add(nameParts[i]);
            }
            return String.join(lastNameParts, ' ');
        }
        return 'Citizen';
    }
    
    private static String generateSubject(String issueType, String description) {
        String subject = issueType + ' - ';
        if (String.isNotBlank(description) && description.length() > 50) {
            subject += description.substring(0, 50) + '...';
        } else if (String.isNotBlank(description)) {
            subject += description;
        } else {
            subject += 'New complaint';
        }
        return subject;
    }
    
    private static String generateTrackingToken() {
        String prefix = 'CC' + String.valueOf(Date.today().year()).substring(2);
        String monthDay = String.valueOf(Date.today().month()).leftPad(2, '0') + 
                         String.valueOf(Date.today().day()).leftPad(2, '0');
        String randomSuffix = String.valueOf(Math.round(Math.random() * 9999)).leftPad(4, '0');
        return prefix + monthDay + '-' + randomSuffix;
    }
    
    private static DateTime calculateSLADueDate(String severity) {
        DateTime now = DateTime.now();
        
        switch on severity {
            when 'Critical' {
                return now.addHours(4);
            }
            when 'High' {
                return now.addDays(1);
            }
            when 'Medium' {
                return now.addDays(3);
            }
            when 'Low' {
                return now.addDays(7);
            }
            when else {
                return now.addDays(3); // Default
            }
        }
    }
    
    private static void createActionLog(String caseId, String actionType, String description) {
        try {
            Action_Log__c log = new Action_Log__c();
            log.Case__c = caseId;
            log.Action_Type__c = actionType;
            log.Description__c = description;
            log.Source_System__c = 'Web Portal';
            
            insert log;
        } catch (Exception e) {
            System.debug('Error creating action log: ' + e.getMessage());
        }
    }
    
    // Wrapper class for return results
    public class ComplaintResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String caseId;
        @AuraEnabled public String trackingNumber;
        @AuraEnabled public String message;
        @AuraEnabled public String errorMessage;
        
        public ComplaintResult() {
            this.success = false;
        }
    }
}