import { LightningElement, api, track } from 'lwc';
export default class CaseFilterEditor extends LightningElement {
    @api targetType;
    @track statusOptions = [
        { label: 'New', value: 'New', checked: false },
        { label: 'Working', value: 'Working', checked: false },
        { label: 'Escalated', value: 'Escalated', checked: false },
        { label: 'Closed', value: 'Closed', checked: false }
    ];

    handleCheck(event) {
        const val = event.target.value;
        this.statusOptions = this.statusOptions.map(opt =>
            opt.value === val ? { ...opt, checked: event.target.checked } : opt
        );
        const selected = this.statusOptions
            .filter(o => o.checked).map(o => o.value).join(',');
        this.dispatchEvent(new CustomEvent('valuechange', {
            bubbles: true,
            detail: { value: { selectedStatuses: selected } }
        }));
    }
}