import { LightningElement, api, track } from 'lwc';
import updateCaseFromLWC from '@salesforce/apex/UpdateCaseAction.updateCaseFromLWC';
import getCasesByStatus from '@salesforce/apex/CaseFilterAction.getCasesByStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CaseCardRenderer extends LightningElement {
    @api sourceType;
    @track cases = [];
    @track isLoading = false;
    
    @track filterOptions = [
        { label: 'All Cases', value: 'All', checked: true },
        { label: 'New', value: 'New', checked: false },
        { label: 'Working', value: 'Working', checked: false },
        { label: 'Escalated', value: 'Escalated', checked: false },
        { label: 'Closed', value: 'Closed', checked: false }
    ];
    
    @api
    get value() { return this._value; }
    set value(v) {
        this._value = v;
        if (v && v.casesJson) {
            this.setCases(v.casesJson);
        } else {
            // Default load
            this.fetchFilteredCases('All');
        }
    }
    _value = null;

    setCases(jsonStr) {
        if (!jsonStr) {
            this.cases = [];
            return;
        }
        this.cases = JSON.parse(jsonStr).map(c => ({
            ...c,
            noteValue: '',
            isSaving: false
        }));
    }

    async handleFilterChange(event) {
        const selectedStatus = event.target.value;
        this.filterOptions = this.filterOptions.map(opt => ({
            ...opt,
            checked: opt.value === selectedStatus
        }));
        
        await this.fetchFilteredCases(selectedStatus);
    }

    async fetchFilteredCases(status) {
        this.isLoading = true;
        try {
            const resultJson = await getCasesByStatus({ status: status });
            this.setCases(resultJson);
        } catch (error) {
            console.error('Error fetching cases', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleNoteChange(event) {
        const caseId = event.target.dataset.id;
        const value = event.target.value;
        const caseRecord = this.cases.find(c => c.Id === caseId);
        if (caseRecord) {
            caseRecord.noteValue = value;
        }
    }

    async handleSaveNote(event) {
        const caseId = event.target.dataset.id;
        const caseRecord = this.cases.find(c => c.Id === caseId);
        
        if (!caseRecord || !caseRecord.noteValue) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Please enter a note before saving.',
                variant: 'error'
            }));
            return;
        }

        caseRecord.isSaving = true;
        
        try {
            await updateCaseFromLWC({ 
                caseId: caseId, 
                description: caseRecord.noteValue 
            });
            
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Note saved to Case ' + caseRecord.CaseNumber,
                variant: 'success'
            }));
            
            caseRecord.noteValue = '';
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error saving note',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        } finally {
            caseRecord.isSaving = false;
        }
    }
}