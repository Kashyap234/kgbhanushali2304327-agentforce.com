import { LightningElement, api, track } from 'lwc';
import updateCaseFromLWC from '@salesforce/apex/UpdateCaseAction.updateCaseFromLWC';
import getCasesByStatus from '@salesforce/apex/CaseFilterAction.getCasesByStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CaseCardRenderer extends LightningElement {
    @api sourceType;
    @track cases = [];
    @track isLoading = false;
    @track showFilter = false;
    
    @api
    get value() { return this._value; }
    set value(v) {
        this._value = v;
        if (v && v.casesJson) {
            this.setCases(v.casesJson);
        } else {
            this.cases = [];
        }
    }
    _value = null;

    setCases(jsonStr) {
        if (!jsonStr || jsonStr === '[]') {
            this.cases = [];
            return;
        }
        this.cases = JSON.parse(jsonStr).map(c => ({
            ...c,
            noteValue: '',
            isSaving: false
        }));
    }

    handleReturnToMenu(event) {
        if (event) {
            event.preventDefault();
        }
        
        console.log('Return to menu clicked. Switching to local filter view.');
        this.showFilter = true;
    }
    
    handleCancelFilter(event) {
        if (event) {
            event.preventDefault();
        }
        this.showFilter = false;
    }
    
    async handleLocalFilterChange(event) {
        // Prevent the valuechange event from bubbling up to Agentforce
        event.stopPropagation();
        
        const selectedStatus = event.detail.value.selectedStatuses;
        if (!selectedStatus) return;
        
        this.isLoading = true;
        this.showFilter = false;
        
        try {
            // Fetch cases directly from Apex bypassing the Copilot planner
            const casesJson = await getCasesByStatus({ status: selectedStatus });
            this.setCases(casesJson);
        } catch (error) {
            console.error('Error fetching cases:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body ? error.body.message : error.message,
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    handleNoteChange(event) {
        const caseId = event.target.dataset.id;
        const note = event.target.value;
        const caseRecord = this.cases.find(c => c.Id === caseId);
        if (caseRecord) {
            caseRecord.noteValue = note;
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
                title: 'Error Saving Note',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        } finally {
            caseRecord.isSaving = false;
        }
    }
}