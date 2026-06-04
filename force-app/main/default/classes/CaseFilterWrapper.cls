// CaseFilterWrapper.cls
@JsonAccess(serializable='always' deserializable='always')
global class CaseFilterWrapper {
    @AuraEnabled @InvocableVariable(label='Selected Statuses' description='Comma-separated Case statuses selected by the user')
    public String selectedStatuses;    // e.g. "New,Working,Escalated"
}