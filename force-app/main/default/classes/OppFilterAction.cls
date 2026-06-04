// OppFilterAction.cls
global with sharing class OppFilterAction {
    global class Request {
        @InvocableVariable(required=true label='Opportunity Filter Input' description='The wrapper for opp filters')
        global OppFilterWrapper filter;
    }

    global class Result {
        @InvocableVariable(label='Opportunity Filter Output' description='The wrapper for opp results')
        global OppResultWrapper resultData;
    }

    @InvocableMethod(
        label='Fetch Opportunity Filters'
        description='Accepts multiselect opportunity stage filters and returns matching opportunities'
    )
    global static List<Result> execute(List<Request> inputs) {
        List<Result> results = new List<Result>();
        for (Request input : inputs) {
            Result outResult = new Result();
            outResult.resultData = new OppResultWrapper();
            outResult.resultData.oppsJson = '[]';
            outResult.resultData.userNotes = '';
            
            if (input.filter != null && String.isNotBlank(input.filter.selectedStages)) {
                List<String> stages = input.filter.selectedStages.split(',');
                List<Opportunity> opps = [
                    SELECT Id, Name, StageName, Amount, CloseDate, AccountId, Account.Name
                    FROM Opportunity
                    WHERE StageName IN :stages
                    LIMIT 50
                ];
                outResult.resultData.oppsJson = JSON.serialize(opps);
            }
            results.add(outResult);
        }
        return results;
    }
}