@JsonAccess(serializable='always' deserializable='always')
public with sharing class TopicDescWrapper {
    @AuraEnabled @InvocableVariable(label='Topic Description' description='Description of the selected topic')
    public String topicDescription;

    @AuraEnabled @InvocableVariable(label='Next Action' description='The user requested next action')
    public String nextAction;

    public TopicDescWrapper() {
        this.topicDescription = '';
        this.nextAction = '';
    }
}