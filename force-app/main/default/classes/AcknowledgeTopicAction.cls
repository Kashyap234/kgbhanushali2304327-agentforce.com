public with sharing class AcknowledgeTopicAction {
    public class Request {
        @InvocableVariable(required=true label='Topic Description Input' description='The description from the previous step')
        public TopicDescWrapper topicDesc;
    }

    public class Result {
        @InvocableVariable(label='Status')
        public String status;
    }

    @InvocableMethod(label='Acknowledge Topic')
    public static List<Result> acknowledge(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            res.status = 'Acknowledged';
            results.add(res);
        }
        return results;
    }
}