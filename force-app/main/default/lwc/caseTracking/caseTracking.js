import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCaseDetails from '@salesforce/apex/CaseTrackingController.getCaseDetails';

export default class CaseTracking extends LightningElement {
    @track trackingNumber = '';
    @track caseData = null;
    @track loading = false;
    @track error = null;
    @track showDetails = false;

    handleTrackingNumberChange(event) {
        this.trackingNumber = event.target.value.toUpperCase();
    }

    async handleTrack() {
        if (!this.trackingNumber.trim()) {
            this.showToast('Error', 'Please enter a tracking number', 'error');
            return;
        }

        this.loading = true;
        this.error = null;
        this.caseData = null;
        this.showDetails = false;

        try {
            const result = await getCaseDetails({ trackingToken: this.trackingNumber.trim() });
            
            if (result.success) {
                this.caseData = result.caseData;
                this.showDetails = true;
            } else {
                this.error = result.errorMessage || 'Case not found';
                this.showToast('Not Found', this.error, 'error');
            }
        } catch (error) {
            this.error = 'Unable to retrieve case information';
            this.showToast('Error', this.error, 'error');
        } finally {
            this.loading = false;
        }
    }

    handleNewSearch() {
        this.trackingNumber = '';
        this.caseData = null;
        this.showDetails = false;
        this.error = null;
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    get statusClass() {
        if (!this.caseData) return '';
        
        switch (this.caseData.status) {
            case 'New':
                return 'slds-badge slds-badge_lightest';
            case 'In Progress':
                return 'slds-badge slds-theme_warning';
            case 'Escalated':
                return 'slds-badge slds-theme_error';
            case 'Closed':
                return 'slds-badge slds-theme_success';
            default:
                return 'slds-badge';
        }
    }

    get severityClass() {
        if (!this.caseData) return '';
        
        switch (this.caseData.severity) {
            case 'Critical':
                return 'priority-critical';
            case 'High':
                return 'priority-high';
            case 'Medium':
                return 'priority-medium';
            case 'Low':
                return 'priority-low';
            default:
                return '';
        }
    }

    get hasWorkOrders() {
        return this.caseData && this.caseData.workOrders && this.caseData.workOrders.length > 0;
    }

    get hasActionLogs() {
        return this.caseData && this.caseData.actionLogs && this.caseData.actionLogs.length > 0;
    }

    get hasPhotos() {
        return this.caseData && this.caseData.photos && this.caseData.photos.length > 0;
    }
}