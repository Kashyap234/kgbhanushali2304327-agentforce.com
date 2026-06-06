import { LightningElement, api, track, wire } from 'lwc';
import getAvailableTopicTypes from '@salesforce/apex/TopicTypeAction.getAvailableTopicTypes';

export default class TopicSelectionRenderer extends LightningElement {
    @api targetType;
    @track options = [];
    @track debugValue = '';
    selectedValue = '';

    @wire(getAvailableTopicTypes)
    wiredTopics({ error, data }) {
        if (data) {
            this.options = data.map(topic => {
                return { label: topic, value: topic };
            });
        } else if (error) {
            this.debugValue = JSON.stringify(error);
            this.options = [];
        }
    }

    @api
    get value() {
        return this._value;
    }

    set value(v) {
        this._value = v;
        if (v && v.selectedTopic) {
            this.selectedValue = v.selectedTopic;
        }
    }
    _value = null;

    get hasOptions() {
        return this.options && this.options.length > 0;
    }

    handleChange(event) {
        this.selectedValue = event.detail.value;
        this.dispatchEvent(new CustomEvent('valuechange', {
            bubbles: true,
            composed: true,
            detail: {
                value: {
                    selectedTopic: this.selectedValue
                }
            }
        }));
    }
}