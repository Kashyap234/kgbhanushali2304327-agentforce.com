import { LightningElement, api, track } from 'lwc';

export default class TopicDescriptionRenderer extends LightningElement {
    @api _value;
    @track descriptions = [];
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

        let rawDesc = '';
        if (v && v.topicDescription) {
            rawDesc = v.topicDescription;
        } else if (v && v.resultData && v.resultData.topicDescription) {
            rawDesc = v.resultData.topicDescription;
        }

        if (rawDesc) {
            this.descriptions = rawDesc.split('|||').map((desc, index) => {
                return { id: index, text: desc };
            });
        } else {
            this.descriptions = [];
        }
    }

    get hasDescriptions() {
        return this.descriptions && this.descriptions.length > 0;
    }
}