// OppFilterWrapper.cls
@JsonAccess(serializable='always' deserializable='always')
global class OppFilterWrapper {
    @AuraEnabled @InvocableVariable(label='Selected Stages' description='Comma-separated Opportunity stages')
    public String selectedStages;
}