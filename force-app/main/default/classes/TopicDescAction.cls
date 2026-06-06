public with sharing class TopicDescAction {

    public class Request {
        @InvocableVariable(required=true description='The selected Type_of_Topics__c value')
        public String topicType;
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
            
            // Query the description for the given topic type
            // Assuming we take the first matching topic's description
            List<Topic__c> topics = [
                SELECT Description__c 
                FROM Topic__c 
                WHERE Type_of_Topics__c = :req.topicType 
                LIMIT 1
            ];
            
            if (!topics.isEmpty()) {
                res.resultData.topicDescription = topics[0].Description__c;
            } else {
                res.resultData.topicDescription = 'No description found for this topic.';
            }
            results.add(res);
        }
        
        return results;
    }
}
