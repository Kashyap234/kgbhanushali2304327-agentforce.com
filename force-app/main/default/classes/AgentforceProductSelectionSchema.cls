/**
 * Data shape for the "Product Selection" custom Lightning type.
 *
 * Requirements enforced here (per Salesforce's Apex-based CLT rules):
 *  - Top-level class, not an inner class.
 *  - global visibility (public/private breaks namespaced orgs & managed packages).
 *  - @JsonAccess(serializable='always' deserializable='always') on the class.
 *  - @AuraEnabled on every field. Schema projection (the process that builds the
 *    runtime JSON schema for the CLT) only looks at @AuraEnabled fields — this was
 *    missing in the original version and is one reason the CLT wasn't selectable.
 *  - @InvocableVariable on every field that should be exposed as an action
 *    input/output parameter.
 */
@JsonAccess(serializable='always' deserializable='always')
global class AgentforceProductSelectionSchema {

    @AuraEnabled
    @InvocableVariable(
        required=true
        label='Is Insurance Selected'
        description='Context flag: true when the Insurance context is active for this turn.'
    )
    public Boolean IsInsuranceSelected;

    @AuraEnabled
    @InvocableVariable(
        required=true
        label='Is Product Selected'
        description='Context flag: true when the Product context is active for this turn.'
    )
    public Boolean IsProductSelected;

    @AuraEnabled
    @InvocableVariable(
        label='User Checkbox Input'
        description='The confirmation value the user toggles inside the CLT editor.'
    )
    public Boolean UserCheckboxInput;
}