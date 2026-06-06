public with sharing class TopicTypeAction {

    public class Result {
        @InvocableVariable(label='Topic Type Output' description='The wrapper for topic types')
        public TopicTypeWrapper resultData;
    }

    public class Request {
        @InvocableVariable(label='Context Input' description='Optional input parameter')
        public String contextInput;
    }

    @InvocableMethod(label='Get Topic Types' description='Returns a list of unique topic types from the Topic__c object')
    public static List<Result> getTopicTypes(List<Request> requests) {
        List<Result> results = new List<Result>();
        
        for (Request req : requests) {
            Result res = new Result();
            res.resultData = new TopicTypeWrapper();
            
            // Query unique topic types
            Set<String> uniqueTypes = new Set<String>();
            for(Topic__c t : [SELECT Type_of_Topics__c FROM Topic__c WHERE Type_of_Topics__c != null]) {
                uniqueTypes.add(t.Type_of_Topics__c);
            }
            
            res.resultData.topicTypes.addAll(uniqueTypes);
            results.add(res);
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getAvailableTopicTypes() {
        Set<String> uniqueTypes = new Set<String>();
        for(Topic__c t : [SELECT Type_of_Topics__c FROM Topic__c WHERE Type_of_Topics__c != null]) {
            uniqueTypes.add(t.Type_of_Topics__c);
        }
        return new List<String>(uniqueTypes);
    }
}
