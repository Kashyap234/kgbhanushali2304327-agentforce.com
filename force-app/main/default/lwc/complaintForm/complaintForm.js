// complaintForm.js
import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createComplaintCase from '@salesforce/apex/ComplaintFormController.createComplaintCase';
import uploadFile from '@salesforce/apex/ComplaintFormController.uploadFile';

export default class ComplaintForm extends LightningElement {
    @track formData = {
        issueType: '',
        subtype: '',
        severity: 'Medium',
        description: '',
        contactName: '',
        contactEmail: '',
        contactPhone: '',
        address: '',
        latitude: null,
        longitude: null
    };

    @track isSubmitting = false;
    @track showThankYou = false;
    @track trackingNumber = '';
    @track uploadedFiles = [];
    @track showLocationPicker = false;

    // Picklist options
    issueTypeOptions = [
        { label: 'Pothole', value: 'Pothole' },
        { label: 'Water Issue', value: 'Water Issue' },
        { label: 'Waste Management', value: 'Waste Management' },
        { label: 'Streetlight', value: 'Streetlight' },
        { label: 'Traffic Signal', value: 'Traffic Signal' },
        { label: 'Drainage', value: 'Drainage' },
        { label: 'Parks & Recreation', value: 'Parks & Recreation' },
        { label: 'Noise Complaint', value: 'Noise Complaint' },
        { label: 'Other', value: 'Other' }
    ];

    severityOptions = [
        { label: 'Low', value: 'Low' },
        { label: 'Medium', value: 'Medium' },
        { label: 'High', value: 'High' },
        { label: 'Critical', value: 'Critical' }
    ];

    connectedCallback() {
        this.getCurrentLocation();
        this.loadMapScript();
    }

    loadMapScript() {
        // Load Leaflet CSS and JS
        const leafletCSS = document.createElement('link');
        leafletCSS.rel = 'stylesheet';
        leafletCSS.href = 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/leaflet.css';
        document.head.appendChild(leafletCSS);

        const leafletJS = document.createElement('script');
        leafletJS.src = 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/leaflet.js';
        leafletJS.onload = () => {
            this.mapLoaded = true;
        };
        document.head.appendChild(leafletJS);
    }

    getCurrentLocation() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    this.formData.latitude = position.coords.latitude;
                    this.formData.longitude = position.coords.longitude;
                    this.reverseGeocode(position.coords.latitude, position.coords.longitude);
                },
                (error) => {
                    console.log('Geolocation error:', error);
                }
            );
        }
    }

    async reverseGeocode(lat, lon) {
        try {
            const response = await fetch(
                `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lon}&format=json`
            );
            const data = await response.json();
            if (data.display_name) {
                this.formData.address = data.display_name;
            }
        } catch (error) {
            console.error('Reverse geocoding failed:', error);
        }
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.formData[field] = event.target.value;
    }

    handleFileUpload(event) {
        const files = Array.from(event.target.files);
        files.forEach(file => {
            if (file.size <= 25 * 1024 * 1024) { // 25MB limit
                const reader = new FileReader();
                reader.onload = () => {
                    this.uploadedFiles.push({
                        name: file.name,
                        base64: reader.result.split(',')[1],
                        contentType: file.type
                    });
                };
                reader.readAsDataURL(file);
            } else {
                this.showToast('Error', 'File size must be less than 25MB', 'error');
            }
        });
    }

    removeFile(event) {
        const index = event.target.dataset.index;
        this.uploadedFiles.splice(index, 1);
    }

    showLocationPicker() {
        this.showLocationPicker = true;
        setTimeout(() => {
            this.initializeMap();
        }, 100);
    }

    initializeMap() {
        if (!this.mapLoaded || !window.L) return;

        const mapContainer = this.template.querySelector('.map-container');
        if (!mapContainer) return;

        const map = window.L.map(mapContainer).setView([
            this.formData.latitude || 23.0225, 
            this.formData.longitude || 72.5714
        ], 13);

        window.L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors'
        }).addTo(map);

        let marker = window.L.marker([
            this.formData.latitude || 23.0225,
            this.formData.longitude || 72.5714
        ]).addTo(map);

        map.on('click', (e) => {
            if (marker) {
                map.removeLayer(marker);
            }
            marker = window.L.marker([e.latlng.lat, e.latlng.lng]).addTo(map);
            this.formData.latitude = e.latlng.lat;
            this.formData.longitude = e.latlng.lng;
            this.reverseGeocode(e.latlng.lat, e.latlng.lng);
        });
    }

    closeLocationPicker() {
        this.showLocationPicker = false;
    }

    async handleSubmit() {
        if (!this.validateForm()) {
            return;
        }

        this.isSubmitting = true;

        try {
            // Create case first
            const result = await createComplaintCase({
                complaintData: JSON.stringify(this.formData)
            });

            if (result.success) {
                this.trackingNumber = result.trackingNumber;
                const caseId = result.caseId;

                // Upload files if any
                if (this.uploadedFiles.length > 0) {
                    await this.uploadFiles(caseId);
                }

                this.showThankYou = true;
                this.showToast('Success', 'Your complaint has been submitted successfully!', 'success');
            } else {
                throw new Error(result.errorMessage || 'Failed to submit complaint');
            }
        } catch (error) {
            console.error('Submission error:', error);
            this.showToast('Error', 'Failed to submit complaint. Please try again.', 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    async uploadFiles(caseId) {
        for (const file of this.uploadedFiles) {
            try {
                await uploadFile({
                    parentId: caseId,
                    fileName: file.name,
                    base64Data: file.base64,
                    contentType: file.contentType
                });
            } catch (error) {
                console.error('File upload error:', error);
            }
        }
    }

    validateForm() {
        const requiredFields = ['issueType', 'description', 'contactName', 'contactEmail'];
        let isValid = true;

        requiredFields.forEach(field => {
            if (!this.formData[field]) {
                isValid = false;
                this.showToast('Error', `Please fill in ${field.replace(/([A-Z])/g, ' $1').toLowerCase()}`, 'error');
            }
        });

        // Email validation
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (this.formData.contactEmail && !emailRegex.test(this.formData.contactEmail)) {
            isValid = false;
            this.showToast('Error', 'Please enter a valid email address', 'error');
        }

        return isValid;
    }

    resetForm() {
        this.formData = {
            issueType: '',
            subtype: '',
            severity: 'Medium',
            description: '',
            contactName: '',
            contactEmail: '',
            contactPhone: '',
            address: '',
            latitude: null,
            longitude: null
        };
        this.uploadedFiles = [];
        this.showThankYou = false;
        this.trackingNumber = '';
        this.getCurrentLocation();
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    get hasFiles() {
        return this.uploadedFiles.length > 0;
    }

    get locationText() {
        if (this.formData.address) {
            return this.formData.address.length > 100 ? 
                this.formData.address.substring(0, 100) + '...' : 
                this.formData.address;
        }
        return 'Click to select location on map';
    }
}