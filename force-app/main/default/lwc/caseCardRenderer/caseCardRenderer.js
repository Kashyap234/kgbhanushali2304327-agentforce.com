import { LightningElement, api, track } from 'lwc';
import updateCaseFromLWC from '@salesforce/apex/UpdateCaseAction.updateCaseFromLWC';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CaseCardRenderer extends LightningElement {
    @api sourceType;
    @track cases = [];
    
    @api
    get value() { return this._value; }
    set value(v) {
        this._value = v;
        if (v && v.casesJson) {
            this.cases = JSON.parse(v.casesJson).map(c => ({
                ...c,
                noteValue: '',
                isSaving: false
            }));
        }
    }
    _value = null;

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
            
            // Clear the note field
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