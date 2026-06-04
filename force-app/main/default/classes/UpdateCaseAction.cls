// UpdateCaseAction.cls
global with sharing class UpdateCaseAction {
    global class Request {
        @InvocableVariable(required=true label='Case Number' description='The CaseNumber of the case to update, e.g., 00001002')
        global String caseNumber;
        
        @InvocableVariable(required=true label='Description' description='The new description or notes to append or update on the case')
        global String description;
    }

    global class Result {
        @InvocableVariable(label='Status' description='Success or error message')
        global String status;
        
        @InvocableVariable(label='Case Id' description='The ID of the updated case')
        global String caseId;
    }

    @InvocableMethod(
        label='Update Case Description'
        description='Updates a case record based on its case number with a provided description'
    )
    global static List<Result> execute(List<Request> requests) {
        List<Result> results = new List<Result>();
        List<Case> casesToUpdate = new List<Case>();
        Map<String, Request> reqMap = new Map<String, Request>();
        
        for(Request req : requests) {
            reqMap.put(req.caseNumber, req);
        }
        
        List<Case> existingCases = [SELECT Id, CaseNumber, Description FROM Case WHERE CaseNumber IN :reqMap.keySet()];
        
        for (Case c : existingCases) {
            Request req = reqMap.get(c.CaseNumber);
            if (req != null) {
                // Append or replace? We will append for safety, or just overwrite if it's a note.
                // Let's append with a new line if it already has a description.
                if (String.isNotBlank(c.Description)) {
                    c.Description = c.Description + '\n\n' + req.description;
                } else {
                    c.Description = req.description;
                }
                casesToUpdate.add(c);
            }
        }
        
        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
        
        for(Request req : requests) {
            Result res = new Result();
            boolean found = false;
            for (Case c : casesToUpdate) {
                if (c.CaseNumber == req.caseNumber) {
                    res.status = 'Success: Case ' + req.caseNumber + ' updated.';
                    res.caseId = c.Id;
                    found = true;
                    break;
                }
            }
            if (!found) {
                res.status = 'Error: Case ' + req.caseNumber + ' not found.';
            }
            results.add(res);
        }
        
        return results;
    }

    @AuraEnabled
    public static String updateCaseFromLWC(String caseId, String description) {
        try {
            Case c = [SELECT Id, Description FROM Case WHERE Id = :caseId LIMIT 1];
            if (String.isNotBlank(c.Description)) {
                c.Description = c.Description + '\n\n' + description;
            } else {
                c.Description = description;
            }
            update c;
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
