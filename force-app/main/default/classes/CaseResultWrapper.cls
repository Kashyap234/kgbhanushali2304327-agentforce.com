// CaseResultWrapper.cls
@JsonAccess(serializable='always' deserializable='always')
global class CaseResultWrapper {
    @AuraEnabled @InvocableVariable(label='Cases JSON' description='JSON array of matching cases')
    public String casesJson;

    @AuraEnabled @InvocableVariable(label='User Notes' description='Notes entered by the user in the output form')
    public String userNotes;
}