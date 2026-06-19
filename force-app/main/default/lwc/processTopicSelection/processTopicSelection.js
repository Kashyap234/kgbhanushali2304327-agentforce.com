import { api, LightningElement } from "lwc";

export default class ProcessTopicSelection extends LightningElement {

    /* ── Agentforce @api properties ── */
    @api
    get readOnly() { return this._readOnly; }
    set readOnly(value) { this._readOnly = value; }
    _readOnly = false;

    @api
    get value() { return this._value; }
    set value(val) { this._value = val; }
    _value;

    /* ── Internal state ── */
    selectedTopic = null;   // 'Product' | 'Insurance' | null

    /* ── Computed CSS classes ── */
    get productButtonClass() {
        return `topic-pill${this.selectedTopic === 'Product' ? ' selected' : ''}`;
    }
    get insuranceButtonClass() {
        return `topic-pill${this.selectedTopic === 'Insurance' ? ' selected' : ''}`;
    }

    /* ── Handler: select topic and immediately dispatch value ── */
    handleTopicClick(event) {
        this.selectedTopic = event.currentTarget.dataset.value;

        const payload = {
            IsProductSelected:   this.selectedTopic === 'Product',
            IsInsuranceSelected: this.selectedTopic === 'Insurance'
        };

        this.dispatchEvent(
            new CustomEvent("valuechange", {
                detail: { value: payload }
            })
        );
    }
}