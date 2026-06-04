// CaseFilterAction.cls
global with sharing class CaseFilterAction {
    global class Request {
        @InvocableVariable(required=true label='Case Filter Input' description='The wrapper for case filters')
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
            outResult.resultData.casesJson = '[]';
            outResult.resultData.userNotes = '';
            
            if (input.filter != null && String.isNotBlank(input.filter.selectedStatuses)) {
                List<String> statuses = input.filter.selectedStatuses.split(',');
                List<Case> cases = [
                    SELECT Id, CaseNumber, Subject, Status, Priority, AccountId, Account.Name
                    FROM Case
                    WHERE Status IN :statuses
                    LIMIT 50
                ];
                outResult.resultData.casesJson = JSON.serialize(cases);
            }
            results.add(outResult);
        }
        return results;
    }
}