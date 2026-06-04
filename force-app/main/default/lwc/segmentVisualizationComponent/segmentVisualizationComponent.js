// segmentVisualizationComponent.js - Fully dynamic with real-time data
import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getTrainRoute from '@salesforce/apex/RouteVisualizationController.getTrainRoute';
import getSegmentUtilization from '@salesforce/apex/RouteVisualizationController.getSegmentUtilization';
import getLiveTrainStatus from '@salesforce/apex/RouteVisualizationController.getLiveTrainStatus';

export default class SegmentVisualizationComponent extends LightningElement {
    @api trainId;
    @api journeyDate;
    @api selectedFromOrder;
    @api selectedToOrder;
    @api selectedCoachType = 'SL';
    @api showLiveStatus = false;
    
    @track routeData = null;
    @track segmentData = [];
    @track liveStatusData = [];
    @track isLoading = true;
    @track error = null;
    @track selectedSegments = [];
    @track viewMode = 'route'; // 'route', 'utilization', 'live'
    
    // Cached data for refresh
    _routeResult;
    _utilizationResult;
    _liveStatusResult;

    connectedCallback() {
        if (this.trainId && this.journeyDate) {
            this.loadAllData();
        }
    }

    @wire(getTrainRoute, { trainId: '$trainId' })
    wiredRoute(result) {
        this._routeResult = result;
        if (result.data) {
            this.routeData = result.data;
            this.processRouteData();
            this.error = null;
        } else if (result.error) {
            this.error = result.error;
            console.error('Route loading error:', result.error);
        }
    }

    @wire(getSegmentUtilization, { 
        trainId: '$trainId', 
        journeyDate: '$journeyDate' 
    })
    wiredUtilization(result) {
        this._utilizationResult = result;
        if (result.data) {
            this.processUtilizationData(result.data);
            this.error = null;
        } else if (result.error) {
            this.error = result.error;
            console.error('Utilization loading error:', result.error);
        }
    }

    @wire(getLiveTrainStatus, { 
        trainId: '$trainId', 
        journeyDate: '$journeyDate' 
    })
    wiredLiveStatus(result) {
        this._liveStatusResult = result;
        if (result.data) {
            this.liveStatusData = result.data.map(status => ({
                ...status,
                statusClass: this.getStatusClass(status.status),
                delayClass: this.getDelayClass(status.delay),
                delayText: this.formatDelay(status.delay)
            }));
            this.error = null;
        } else if (result.error) {
            this.error = result.error;
            console.error('Live status loading error:', result.error);
        }
        this.isLoading = false;
    }

    loadAllData() {
        this.isLoading = true;
        this.error = null;
    }

    processRouteData() {
        if (!this.routeData || !this.routeData.routeStations) return;
        
        // Add computed properties to route stations
        this.routeData.routeStations = this.routeData.routeStations.map((station, index) => ({
            ...station,
            isSelected: this.isStationSelected(station.stopNumber),
            isInSegment: this.isStationInSegment(station.stopNumber),
            cumulativeTime: this.calculateCumulativeTime(index),
            averageSpeed: this.calculateSegmentSpeed(index),
            stationClass: this.getStationClass(station, index)
        }));
        
        this.updateSegmentHighlighting();
    }

    processUtilizationData(utilizationData) {
        if (!utilizationData || !this.routeData) return;
        
        // Group utilization data by segment and coach type
        const utilizationMap = new Map();
        utilizationData.forEach(segment => {
            const key = `${segment.fromOrder}_${segment.toOrder}`;
            if (!utilizationMap.has(key)) {
                utilizationMap.set(key, new Map());
            }
            utilizationMap.get(key).set(segment.coachType, segment);
        });
        
        // Generate segment visualization data
        this.segmentData = [];
        const stations = this.routeData.routeStations;
        
        for (let i = 0; i < stations.length - 1; i++) {
            const fromStation = stations[i];
            const toStation = stations[i + 1];
            const key = `${fromStation.stopNumber}_${toStation.stopNumber}`;
            const segmentUtilization = utilizationMap.get(key);
            
            if (segmentUtilization) {
                const selectedCoachData = segmentUtilization.get(this.selectedCoachType);
                const allCoachData = Array.from(segmentUtilization.values());
                
                this.segmentData.push({
                    id: `segment_${i}`,
                    fromStation: fromStation.stationCode,
                    fromStationName: fromStation.stationName,
                    toStation: toStation.stationCode,
                    toStationName: toStation.stationName,
                    fromOrder: fromStation.stopNumber,
                    toOrder: toStation.stopNumber,
                    distance: fromStation.distanceFromPrevious || 0,
                    duration: toStation.runningTime || '',
                    
                    // Current coach type data
                    currentCoachData: selectedCoachData || this.getEmptyUtilization(),
                    
                    // All coach types for this segment
                    allCoachTypes: allCoachData,
                    
                    // Visual properties
                    utilizationClass: this.getUtilizationClass(
                        selectedCoachData ? selectedCoachData.occupancyPercentage : 0
                    ),
                    utilizationWidth: selectedCoachData ? selectedCoachData.occupancyPercentage : 0,
                    isSelectedSegment: this.isInSelectedRange(fromStation.stopNumber, toStation.stopNumber),
                    segmentClass: this.getSegmentClass(fromStation.stopNumber, toStation.stopNumber)
                });
            }
        }
    }

    getEmptyUtilization() {
        return {
            totalSeats: 0,
            occupiedSeats: 0,
            availableSeats: 0,
            occupancyPercentage: 0,
            confirmedSeats: 0,
            waitlistedSeats: 0
        };
    }

    updateSegmentHighlighting() {
        if (!this.selectedFromOrder || !this.selectedToOrder) return;
        
        // Update route stations highlighting
        if (this.routeData && this.routeData.routeStations) {
            this.routeData.routeStations = this.routeData.routeStations.map(station => ({
                ...station,
                isSelected: this.isStationSelected(station.stopNumber),
                isInSegment: this.isStationInSegment(station.stopNumber),
                stationClass: this.getStationClass(station)
            }));
        }

        // Update segment data highlighting
        this.segmentData = this.segmentData.map(segment => ({
            ...segment,
            isSelectedSegment: this.isInSelectedRange(segment.fromOrder, segment.toOrder),
            segmentClass: this.getSegmentClass(segment.fromOrder, segment.toOrder)
        }));
    }

    isStationSelected(stopNumber) {
        return stopNumber === this.selectedFromOrder || stopNumber === this.selectedToOrder;
    }

    isStationInSegment(stopNumber) {
        if (!this.selectedFromOrder || !this.selectedToOrder) return false;
        return stopNumber >= this.selectedFromOrder && stopNumber <= this.selectedToOrder;
    }

    isInSelectedRange(fromOrder, toOrder) {
        if (!this.selectedFromOrder || !this.selectedToOrder) return false;
        return fromOrder >= this.selectedFromOrder && toOrder <= this.selectedToOrder;
    }

    getStationClass(station, index) {
        let classes = ['station-item'];
        
        if (station.isFirst) classes.push('station-first');
        if (station.isLast) classes.push('station-last');
        if (station.isSelected) classes.push('station-selected');
        if (station.isInSegment) classes.push('station-in-segment');
        if (station.isTechnicalStop) classes.push('station-technical');
        if (station.hasPantryCar) classes.push('station-pantry');
        
        return classes.join(' ');
    }

    getSegmentClass(fromOrder, toOrder) {
        let classes = ['segment-bar'];
        
        if (this.isInSelectedRange(fromOrder, toOrder)) {
            classes.push('segment-selected');
        }
        
        return classes.join(' ');
    }

    getUtilizationClass(percentage) {
        if (percentage >= 95) return 'utilization-full';
        if (percentage >= 80) return 'utilization-high';
        if (percentage >= 60) return 'utilization-medium';
        if (percentage >= 30) return 'utilization-low';
        return 'utilization-empty';
    }

    getStatusClass(status) {
        const statusClasses = {
            'Expected': 'status-expected',
            'At Platform': 'status-current',
            'Departed': 'status-completed',
            'Cancelled': 'status-cancelled',
            'Delayed': 'status-delayed'
        };
        return statusClasses[status] || 'status-unknown';
    }

    getDelayClass(delay) {
        if (!delay || delay === 0) return 'delay-none';
        if (delay <= 10) return 'delay-minor';
        if (delay <= 30) return 'delay-moderate';
        return 'delay-major';
    }

    formatDelay(delay) {
        if (!delay || delay === 0) return 'On Time';
        return delay > 0 ? `+${delay}m` : `${delay}m`;
    }

    calculateCumulativeTime(stationIndex) {
        if (!this.routeData || !this.routeData.routeStations || stationIndex === 0) return '0h 0m';
        
        const firstStation = this.routeData.routeStations[0];
        const currentStation = this.routeData.routeStations[stationIndex];
        
        // This would need proper time calculation logic
        // For now, return a placeholder
        return `${stationIndex * 2}h ${(stationIndex * 30) % 60}m`;
    }

    calculateSegmentSpeed(stationIndex) {
        if (!this.routeData || !this.routeData.routeStations || stationIndex === 0) return 0;
        
        const currentStation = this.routeData.routeStations[stationIndex];
        const runningTimeStr = currentStation.runningTime;
        const distance = currentStation.distanceFromPrevious || 0;
        
        if (!runningTimeStr || distance === 0) return 0;
        
        // Parse running time (format: "2h 30m")
        const timeMatch = runningTimeStr.match(/(\d+)h\s*(\d+)?m?/);
        if (!timeMatch) return 0;
        
        const hours = parseInt(timeMatch[1]) + (parseInt(timeMatch[2] || 0) / 60);
        return hours > 0 ? Math.round(distance / hours) : 0;
    }

    // Event handlers
    handleStationClick(event) {
        const stationOrder = parseInt(event.currentTarget.dataset.stationOrder);
        const station = this.routeData.routeStations.find(s => s.stopNumber === stationOrder);
        
        this.dispatchEvent(new CustomEvent('stationselected', {
            detail: { 
                stationOrder, 
                station,
                trainId: this.trainId,
                journeyDate: this.journeyDate
            }
        }));
    }

    handleSegmentClick(event) {
        const segmentIndex = parseInt(event.currentTarget.dataset.segmentIndex);
        const segment = this.segmentData[segmentIndex];
        
        this.dispatchEvent(new CustomEvent('segmentselected', {
            detail: { 
                segment,
                fromOrder: segment.fromOrder,
                toOrder: segment.toOrder,
                trainId: this.trainId,
                journeyDate: this.journeyDate
            }
        }));
    }

    handleViewModeChange(event) {
        this.viewMode = event.detail.value;
        
        // Refresh live data when switching to live view
        if (this.viewMode === 'live' && this._liveStatusResult) {
            refreshApex(this._liveStatusResult);
        }
    }

    handleCoachTypeChange(event) {
        this.selectedCoachType = event.detail.value;
        
        // Refresh utilization data with new coach type
        if (this._utilizationResult && this._utilizationResult.data) {
            this.processUtilizationData(this._utilizationResult.data);
        }
    }

    handleRefresh() {
        this.isLoading = true;
        
        // Refresh all data
        if (this._routeResult) refreshApex(this._routeResult);
        if (this._utilizationResult) refreshApex(this._utilizationResult);
        if (this._liveStatusResult) refreshApex(this._liveStatusResult);
    }

    // Getter methods for template
    get isRouteView() {
        return this.viewMode === 'route';
    }

    get isUtilizationView() {
        return this.viewMode === 'utilization';
    }

    get isLiveView() {
        return this.viewMode === 'live';
    }

    get hasRouteData() {
        return this.routeData && this.routeData.routeStations && this.routeData.routeStations.length > 0;
    }

    get hasSegmentData() {
        return this.segmentData && this.segmentData.length > 0;
    }

    get hasLiveData() {
        return this.liveStatusData && this.liveStatusData.length > 0;
    }

    get trainInfo() {
        return this.routeData ? this.routeData.trainInfo : null;
    }

    get viewModeOptions() {
        return [
            { label: 'Route Map', value: 'route' },
            { label: 'Seat Utilization', value: 'utilization' },
            { label: 'Live Status', value: 'live' }
        ];
    }

    get coachTypeOptions() {
        if (!this.segmentData || this.segmentData.length === 0) return [];
        
        // Get unique coach types from segment data
        const coachTypes = new Set();
        this.segmentData.forEach(segment => {
            segment.allCoachTypes.forEach(coach => coachTypes.add(coach.coachType));
        });
        
        return Array.from(coachTypes).map(type => ({
            label: this.formatCoachTypeLabel(type),
            value: type
        }));
    }

    formatCoachTypeLabel(coachType) {
        const labels = {
            '1A': '1st AC',
            '2A': '2nd AC',
            '3A': '3rd AC',
            'SL': 'Sleeper',
            'CC': 'Chair Car',
            '2S': '2nd Sitting'
        };
        return labels[coachType] || coachType;
    }

    get selectedSegmentInfo() {
        if (!this.selectedFromOrder || !this.selectedToOrder || !this.hasRouteData) return null;
        
        const fromStation = this.routeData.routeStations.find(s => s.stopNumber === this.selectedFromOrder);
        const toStation = this.routeData.routeStations.find(s => s.stopNumber === this.selectedToOrder);
        
        if (!fromStation || !toStation) return null;
        
        return {
            from: `${fromStation.stationName} (${fromStation.stationCode})`,
            to: `${toStation.stationName} (${toStation.stationCode})`,
            departure: fromStation.departureTime,
            arrival: toStation.arrivalTime,
            distance: toStation.distanceFromSource - fromStation.distanceFromSource
        };
    }

    get errorMessage() {
        if (!this.error) return '';
        return this.error.body ? this.error.body.message : this.error.message;
    }
}