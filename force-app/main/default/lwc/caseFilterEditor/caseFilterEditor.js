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
        // Update all options so only the selected one is checked
        this.statusOptions = this.statusOptions.map(opt =>
            ({ ...opt, checked: opt.value === val })
        );

        // Dispatch the new selected status
        this.dispatchEvent(new CustomEvent('valuechange', {
            bubbles: true,
            detail: { value: { selectedStatuses: val } }
        }));
    }
}