// CaseFilterAction.cls
global with sharing class CaseFilterAction {
    global class Request {
        @InvocableVariable(required=false label='Case Filter Input' description='The wrapper for case filters')
        global CaseFilterWrapper filter;
    }

    global class Result {
        @InvocableVariable(label='Case Filter Output' description='The wrapper for case results')
        global CaseResultWrapper resultData;
    }

    @InvocableMethod(
        label='Fetch Case Filters'
        description='Accepts multiselect case status filters and returns matching cases as JSON'
    )
    global static List<Result> execute(List<Request> inputs) {
        List<Result> results = new List<Result>();
        for (Request input : inputs) {
            Result outResult = new Result();
            outResult.resultData = new CaseResultWrapper();
            outResult.resultData.userNotes = '';
            
            List<Case> cases;
            if (input.filter != null && String.isNotBlank(input.filter.selectedStatuses)) {
                List<String> statuses = input.filter.selectedStatuses.split(',');
                cases = [
                    SELECT Id, CaseNumber, Subject, Status, Priority, AccountId, Account.Name
                    FROM Case
                    WHERE Status IN :statuses
                    LIMIT 50
                ];
            } else {
                // If no filter is provided, return all cases by default
                cases = [
                    SELECT Id, CaseNumber, Subject, Status, Priority, AccountId, Account.Name
                    FROM Case
                    LIMIT 50
                ];
            }
            outResult.resultData.casesJson = JSON.serialize(cases);
            results.add(outResult);
        }
        return results;
    }

    @AuraEnabled
    public static String getCasesByStatus(String status) {
        try {
            List<Case> cases;
            if (String.isBlank(status) || status == 'All') {
                cases = [SELECT Id, CaseNumber, Subject, Status, Priority, AccountId, Account.Name FROM Case LIMIT 50];
            } else {
                cases = [SELECT Id, CaseNumber, Subject, Status, Priority, AccountId, Account.Name FROM Case WHERE Status = :status LIMIT 50];
            }
            return JSON.serialize(cases);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}