import { LightningElement, api, track } from 'lwc';

export default class TopicDescriptionRenderer extends LightningElement {
    @api sourceType;

    @api
    get value() {
        return this._value;
    }
    set value(incoming) {
        this._value = incoming;
        this.parseValue(incoming);
    }

    @track descriptions = [];
    @track debugValue = '';
    _value = null;

    parseValue(incoming) {
        if (!incoming) {
            this.debugValue = 'incoming is null';
            return;
        }

        this.debugValue = JSON.stringify(incoming);

        if (!incoming.topicDescription) {
            this.descriptions = [];
            return;
        }

        const rawData = incoming.topicDescription;
        if (rawData === 'No description found for this topic.') {
            this.descriptions = [];
            return;
        }

        const arr = rawData.split('|||');
        this.descriptions = arr.map((item, index) => ({
            id: String(index),
            text: item
        }));
    }

    get hasDescriptions() {
        return this.descriptions && this.descriptions.length > 0;
    }

    handleSelectAnother() {
        console.log('Select another topic clicked. The org lacks lightning/accApi to dispatch a new bubble.');
    }
}