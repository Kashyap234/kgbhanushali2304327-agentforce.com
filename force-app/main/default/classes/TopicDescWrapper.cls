@JsonAccess(serializable='always' deserializable='always')
public with sharing class TopicDescWrapper {
    @AuraEnabled @InvocableVariable(label='Topic Description' description='Description of the selected topic')
    public String topicDescription;

    public TopicDescWrapper() {
        this.topicDescription = '';
    }
}
