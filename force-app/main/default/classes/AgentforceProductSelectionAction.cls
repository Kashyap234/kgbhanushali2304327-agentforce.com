/**
 * This is the actual Agent Action. The original two files (schema + LWC) had no
 * @InvocableMethod anywhere — without one, there's no Agent Action to attach a
 * Custom Lightning Type to, and so no "Input Rendering" parameter ever appears.
 *
 * Create your custom Agent Action in Setup using this class. The single input
 * parameter "requests" will be of type AgentforceProductSelectionSchema, and
 * that input parameter's "Input Rendering" dropdown is where you select the
 * productSelectionType CLT once it's deployed.
 */
global class AgentforceProductSelectionAction {

    @InvocableMethod(
        label='Confirm Product Or Insurance Selection'
        description='Renders a CLT editor reflecting the active Insurance/Product context and captures the user confirmation checkbox.'
    )
    global static List<AgentforceProductSelectionSchema> confirmSelection(
        List<AgentforceProductSelectionSchema> requests
    ) {
        List<AgentforceProductSelectionSchema> results = new List<AgentforceProductSelectionSchema>();
        for (AgentforceProductSelectionSchema req : requests) {
            // Demo behavior: echo back exactly what the CLT editor captured.
            // Replace this with whatever logic should run once the user submits
            // the checkbox (e.g. writing UserCheckboxInput to a record).
            results.add(req);
        }
        return results;
    }
}