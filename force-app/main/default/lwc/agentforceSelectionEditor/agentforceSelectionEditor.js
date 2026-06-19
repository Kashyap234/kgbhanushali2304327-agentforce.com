import { LightningElement, api } from 'lwc';

export default class AgentforceSelectionEditor extends LightningElement {
    /**
     * Agentforce passes the CLT's data shape into this single 'value' property.
     *
     * IMPORTANT: Salesforce's own docs for top-level CLT editor overrides state
     * that this @api value property does NOT support data injection of existing
     * conversational/context values on first render — it's designed to capture
     * NEW user input, not to be guaranteed pre-populated with whatever the agent
     * already knows (e.g. IsInsuranceSelected / IsProductSelected). Test this
     * specific behavior in your org: if the flags don't arrive populated the
     * first time the form renders, that's the documented platform limitation
     * talking, not a bug in this code.
     */
    @api value;

    get isInsurance() {
        return !!(this.value && this.value.IsInsuranceSelected);
    }

    get isProduct() {
        return !!(this.value && this.value.IsProductSelected);
    }

    get noContextRecognized() {
        return !this.isInsurance && !this.isProduct;
    }

    handleCheckboxChange(event) {
        const isChecked = event.target.checked;

        const updatedValue = {
            ...this.value,
            UserCheckboxInput: isChecked
        };

        this.dispatchEvent(
            new CustomEvent('valuechange', {
                detail: {
                    value: updatedValue
                },
                bubbles: true,
                composed: true
            })
        );
    }
}