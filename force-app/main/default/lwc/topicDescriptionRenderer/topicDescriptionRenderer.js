import { LightningElement, api, track } from 'lwc';

export default class TopicDescriptionRenderer extends LightningElement {
    @api _value;
    @track description = '';
    @track debugValue = '';

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

        if (v && v.topicDescription) {
            this.description = v.topicDescription;
        } else if (v && v.resultData && v.resultData.topicDescription) {
            this.description = v.resultData.topicDescription;
        } else {
            this.description = '';
        }
    }
}