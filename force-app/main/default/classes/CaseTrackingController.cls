public with sharing class CaseTrackingController {
    
    @AuraEnabled(cacheable=false)
    public static TrackingResult getCaseDetails(String trackingToken) {
        TrackingResult result = new TrackingResult();
        
        try {
            // Find case by tracking token
            List<Case> cases = [
                SELECT Id, CaseNumber, Subject, Description, Status, Origin, CreatedDate, 
                       LastModifiedDate, ContactId, Contact.Name, Contact.Email,
                       Issue_Type__c, Subtype__c, Severity__c, Address__c, Ward__c,
                       Public_Tracking_Token__c, SLA_Due__c, Latitude__c, Longitude__c
                FROM Case 
                WHERE Public_Tracking_Token__c = :trackingToken 
                LIMIT 1
            ];
            
            if (cases.isEmpty()) {
                result.success = false;
                result.errorMessage = 'No complaint found with tracking number: ' + trackingToken;
                return result;
            }
            
            Case caseRecord = cases[0];
            
            // Get work orders
            List<Work_Order__c> workOrders = [
                SELECT Id, Name, Status__c, Technician__c, Technician__r.Name,
                       Scheduled_Time__c, Completion_Time__c, Notes__c, CreatedDate
                FROM Work_Order__c 
                WHERE Case__c = :caseRecord.Id 
                ORDER BY CreatedDate DESC
            ];
            
            // Get action logs
            List<Action_Log__c> actionLogs = [
                SELECT Id, Action_Type__c, Description__c, CreatedDate, Actor__r.Name
                FROM Action_Log__c 
                WHERE Case__c = :caseRecord.Id 
                ORDER BY CreatedDate DESC 
                LIMIT 20
            ];
            
            // Get photos (ContentDocumentLinks)
            List<ContentDocumentLink> documentLinks = [
                SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.CreatedDate
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :caseRecord.Id 
                ORDER BY ContentDocument.CreatedDate DESC
            ];
            
            // Build result
            CaseData caseData = new CaseData();
            caseData.id = caseRecord.Id;
            caseData.caseNumber = caseRecord.CaseNumber;
            caseData.trackingNumber = caseRecord.Public_Tracking_Token__c;
            caseData.subject = caseRecord.Subject;
            caseData.description = caseRecord.Description;
            caseData.status = caseRecord.Status;
            caseData.issueType = caseRecord.Issue_Type__c;
            caseData.subtype = caseRecord.Subtype__c;
            caseData.severity = caseRecord.Severity__c;
            caseData.address = caseRecord.Address__c;
            caseData.ward = caseRecord.Ward__c;
            caseData.createdDate = caseRecord.CreatedDate?.format('MMM dd, yyyy hh:mm a');
            caseData.lastModified = caseRecord.LastModifiedDate?.format('MMM dd, yyyy hh:mm a');
            caseData.slaDate = caseRecord.SLA_Due__c?.format('MMM dd, yyyy hh:mm a');
            
            if (caseRecord.Contact != null) {
                caseData.contactName = caseRecord.Contact.Name;
                caseData.contactEmail = maskEmail(caseRecord.Contact.Email);
            }
            
            // Add work orders
            caseData.workOrders = new List<WorkOrderData>();
            for (Work_Order__c wo : workOrders) {
                WorkOrderData wod = new WorkOrderData();
                wod.id = wo.Id;
                wod.name = wo.Name;
                wod.status = wo.Status__c;
                wod.technician = wo.Technician__r?.Name;
                wod.scheduledTime = wo.Scheduled_Time__c?.format('MMM dd, yyyy hh:mm a');
                wod.completionTime = wo.Completion_Time__c?.format('MMM dd, yyyy hh:mm a');
                wod.notes = wo.Notes__c;
                caseData.workOrders.add(wod);
            }
            
            // Add action logs
            caseData.actionLogs = new List<ActionLogData>();
            for (Action_Log__c log : actionLogs) {
                ActionLogData ald = new ActionLogData();
                ald.id = log.Id;
                ald.actionType = log.Action_Type__c;
                ald.description = log.Description__c;
                ald.createdDate = log.CreatedDate?.format('MMM dd, yyyy hh:mm a');
                ald.actor = log.Actor__r?.Name;
                caseData.actionLogs.add(ald);
            }
            
            // Add photos
            caseData.photos = new List<PhotoData>();
            for (ContentDocumentLink link : documentLinks) {
                PhotoData pd = new PhotoData();
                pd.id = link.ContentDocumentId;
                pd.title = link.ContentDocument.Title;
                pd.url = '/sfc/servlet.shepherd/document/download/' + link.ContentDocumentId;
                caseData.photos.add(pd);
            }
            
            result.success = true;
            result.caseData = caseData;
            
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = 'Error retrieving case information: ' + e.getMessage();
            System.debug('Error in getCaseDetails: ' + e.getMessage());
        }
        
        return result;
    }
    
    private static String maskEmail(String email) {
        if (String.isBlank(email)) return '';
        
        Integer atIndex = email.indexOf('@');
        if (atIndex <= 0) return email;
        
        String username = email.substring(0, atIndex);
        String domain = email.substring(atIndex);
        
        if (username.length() <= 2) {
            return username + '***' + domain;
        }
        
        return username.substring(0, 2) + '***' + domain;
    }
    
    // Wrapper classes
    public class TrackingResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public CaseData caseData;
        @AuraEnabled public String errorMessage;
        
        public TrackingResult() {
            this.success = false;
        }
    }
    
    public class CaseData {
        @AuraEnabled public String id;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String trackingNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String description;
        @AuraEnabled public String status;
        @AuraEnabled public String issueType;
        @AuraEnabled public String subtype;
        @AuraEnabled public String severity;
        @AuraEnabled public String address;
        @AuraEnabled public String ward;
        @AuraEnabled public String contactName;
        @AuraEnabled public String contactEmail;
        @AuraEnabled public String createdDate;
        @AuraEnabled public String lastModified;
        @AuraEnabled public String slaDate;
        @AuraEnabled public List<WorkOrderData> workOrders;
        @AuraEnabled public List<ActionLogData> actionLogs;
        @AuraEnabled public List<PhotoData> photos;
    }
    
    public class WorkOrderData {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String technician;
        @AuraEnabled public String scheduledTime;
        @AuraEnabled public String completionTime;
        @AuraEnabled public String notes;
    }
    
    public class ActionLogData {
        @AuraEnabled public String id;
        @AuraEnabled public String actionType;
        @AuraEnabled public String description;
        @AuraEnabled public String createdDate;
        @AuraEnabled public String actor;
    }
    
    public class PhotoData {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String url;
    }
}