@JsonAccess(serializable='always' deserializable='always')
public with sharing class TopicTypeWrapper {
    @AuraEnabled @InvocableVariable(label='Topic Types' description='List of available topic types')
    public List<String> topicTypes;

    @AuraEnabled @InvocableVariable(label='Selected Topic' description='The selected topic type')
    public String selectedTopic;

    public TopicTypeWrapper() {
        this.topicTypes = new List<String>();
    }
}
