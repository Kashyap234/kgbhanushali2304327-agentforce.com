import { LightningElement, api, track } from 'lwc';

export default class TopicSelectionRenderer extends LightningElement {
    @api _value;
    @track options = [];
    @track debugValue = '';
    selectedValue = '';

    @api
    get value() {
        return this._value;
    }

    set value(v) {
        this._value = v;
        try {
            this.debugValue = JSON.stringify(v);
        } catch(e) {
            this.debugValue = 'Error stringifying';
        }

        // Handle case where Agentforce passes the output directly or wrapped in resultData
        let types = null;
        if (v && v.topicTypes) {
            types = v.topicTypes;
        } else if (v && v.resultData && v.resultData.topicTypes) {
            types = v.resultData.topicTypes;
        }

        if (types && Array.isArray(types)) {
            this.options = types.map(topic => {
                return { label: topic, value: topic };
            });
        } else {
            this.options = [];
        }
    }

    get hasOptions() {
        return this.options && this.options.length > 0;
    }

    handleChange(event) {
        this.selectedValue = event.detail.value;
    }

    get isSubmitDisabled() {
        return !this.selectedValue;
    }

    handleSubmit() {
        this.dispatchEvent(new CustomEvent('valuechange', {
            bubbles: true,
            composed: true,
            detail: {
                value: this.selectedValue
            }
        }));
    }
}