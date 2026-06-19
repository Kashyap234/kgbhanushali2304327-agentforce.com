@JsonAccess(serializable='always' deserializable='always')
global class AFA_ProcessTopicSelection {

    /**
     * Input schema — mirrors the Custom Lightning Type CLT_ProcessTopicSelection.
     * The LWC dispatches { IsProductSelected: Boolean, IsInsuranceSelected: Boolean }
     * through the "valuechange" event, which Agentforce serialises into this class.
     */
    @JsonAccess(serializable='always' deserializable='always')
    global class TopicSelectionInput {
        @AuraEnabled
        global Boolean IsProductSelected;

        @AuraEnabled
        global Boolean IsInsuranceSelected;
    }

    /** Wrapper that Agentforce passes into the @InvocableMethod. */
    @JsonAccess(serializable='always' deserializable='always')
    global class InputRequest {
        @InvocableVariable(label='Topic Selection Input' required=true)
        global TopicSelectionInput inputs;
    }

    /** Output returned to the Agent so it can branch in the Agent Script. */
    @JsonAccess(serializable='always' deserializable='always')
    global class ActionOutput {
        @InvocableVariable(label='Is Product Selected')
        global Boolean IsProductSelected;

        @InvocableVariable(label='Is Insurance Selected')
        global Boolean IsInsuranceSelected;
    }

    @InvocableMethod(label='Topic Selection Process' description='Receives the user topic selection from the LWC and returns boolean flags so the Agent Script can route to the correct subagent.')
    global static List<ActionOutput> processTopicSelection(List<InputRequest> requests) {
        List<ActionOutput> results = new List<ActionOutput>();

        for (InputRequest req : requests) {
            ActionOutput out = new ActionOutput();

            if (req.inputs != null) {
                out.IsProductSelected  = req.inputs.IsProductSelected  == true;
                out.IsInsuranceSelected = req.inputs.IsInsuranceSelected == true;
            } else {
                out.IsProductSelected  = false;
                out.IsInsuranceSelected = false;
            }

            results.add(out);
        }
        return results;
    }
}