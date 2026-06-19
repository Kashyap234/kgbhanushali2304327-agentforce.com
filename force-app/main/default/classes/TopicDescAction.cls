public with sharing class TopicDescAction {

    public class Request {
        @InvocableVariable(required=true label='Topic Input' description='The selected topic input from user')
        public TopicTypeWrapper topicInput;
    }

    public class Result {
        @InvocableVariable(label='Topic Desc Output' description='The wrapper for topic description')
        public TopicDescWrapper resultData;
    }

    @InvocableMethod(label='Get Topic Description' description='Returns the description for a given topic type')
    public static List<Result> getTopicDescription(List<Request> requests) {
        List<Result> results = new List<Result>();
        
        for (Request req : requests) {
            Result res = new Result();
            res.resultData = new TopicDescWrapper();
            
            // Query the descriptions for the given topic type
            List<Topic__c> topics = [
                SELECT Description__c 
                FROM Topic__c 
                WHERE Type_of_Topics__c = :req.topicInput.selectedTopic 
            ];
            
            if (!topics.isEmpty()) {
                List<String> descs = new List<String>();
                for (Topic__c t : topics) {
                    if (String.isNotBlank(t.Description__c)) {
                        descs.add(t.Description__c);
                    }
                }
                res.resultData.topicDescription = String.join(descs, '|||');
            } else {
                res.resultData.topicDescription = 'No description found for this topic.';
            }
            results.add(res);
        }
        
        return results;
    }

    @AuraEnabled
    public static String getTopicDescriptionAura(String selectedTopic) {
        List<Topic__c> topics = [
            SELECT Description__c 
            FROM Topic__c 
            WHERE Type_of_Topics__c = :selectedTopic 
        ];
        
        if (!topics.isEmpty()) {
            List<String> descs = new List<String>();
            for (Topic__c t : topics) {
                if (String.isNotBlank(t.Description__c)) {
                    descs.add(t.Description__c);
                }
            }
            return String.join(descs, '|||');
        } else {
            return 'No description found for this topic.';
        }
    }
}