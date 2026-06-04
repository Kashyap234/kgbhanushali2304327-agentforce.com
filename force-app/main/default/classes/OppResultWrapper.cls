// OppResultWrapper.cls
@JsonAccess(serializable='always' deserializable='always')
global class OppResultWrapper {
    @AuraEnabled @InvocableVariable(label='Opportunities JSON' description='JSON array of matching opportunities')
    public String oppsJson;

    @AuraEnabled @InvocableVariable(label='User Notes' description='Notes entered by the user in the output form')
    public String userNotes;
}