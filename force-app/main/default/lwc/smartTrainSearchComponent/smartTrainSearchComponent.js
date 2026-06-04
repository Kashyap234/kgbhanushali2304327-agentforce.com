// smartTrainSearchComponent.js - Fixed implementation
import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchTrains from '@salesforce/apex/TrainSearchController.searchTrains';
import checkAvailability from '@salesforce/apex/SegmentAvailabilityService.checkSegmentAvailability';
import getStationOptions from '@salesforce/apex/TrainSearchController.getStationOptions';
import getCoachTypeOptions from '@salesforce/apex/TrainSearchController.getCoachTypeOptions';
import getPopularRoutes from '@salesforce/apex/TrainSearchController.getPopularRoutes';

export default class SmartTrainSearchComponent extends LightningElement {
    @track searchCriteria = {
        fromStation: '',
        toStation: '',
        journeyDate: '',
        coachType: 'SL',
        passengerCount: 1
    };
    
    @track searchResults = [];
    @track isLoading = false;
    @track isLoadingStations = true;
    @track stationOptions = [];
    @track coachTypeOptions = [];
    @track popularRoutes = [];
    @track showResults = false;
    @track selectedTrain = null;

    // Get today's date in YYYY-MM-DD format
    get todayDate() {
        const today = new Date();
        return today.toISOString().split('T')[0];
    }

    // Get maximum booking date (usually 120 days in advance)
    get maxBookingDate() {
        const today = new Date();
        const maxDate = new Date(today.getTime() + (120 * 24 * 60 * 60 * 1000));
        return maxDate.toISOString().split('T')[0];
    }

    // Passenger count options
    get passengerCountOptions() {
        return [
            { label: '1 Passenger', value: 1 },
            { label: '2 Passengers', value: 2 },
            { label: '3 Passengers', value: 3 },
            { label: '4 Passengers', value: 4 },
            { label: '5 Passengers', value: 5 },
            { label: '6 Passengers', value: 6 }
        ];
    }

    // Wire methods to load dynamic data
    @wire(getStationOptions)
    wiredStations({ error, data }) {
        this.isLoadingStations = true;
        if (data) {
            this.stationOptions = data.map(station => ({
                label: station.label,
                value: station.value,
                city: station.city,
                state: station.state
            }));
            this.isLoadingStations = false;
        } else if (error) {
            console.error('Error loading stations:', error);
            this.showToast('Error', 'Failed to load station options', 'error');
            this.isLoadingStations = false;
        }
    }

    @wire(getCoachTypeOptions)
    wiredCoachTypes({ error, data }) {
        if (data) {
            this.coachTypeOptions = data.map(coach => ({
                label: `${coach.label} - ${coach.description}`,
                value: coach.value,
                description: coach.description
            }));
        } else if (error) {
            console.error('Error loading coach types:', error);
        }
    }

    @wire(getPopularRoutes)
    wiredPopularRoutes({ error, data }) {
        if (data) {
            this.popularRoutes = data;
        } else if (error) {
            console.error('Error loading popular routes:', error);
        }
    }

    connectedCallback() {
        // Set default journey date to tomorrow
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        this.searchCriteria.journeyDate = tomorrow.toISOString().split('T')[0];
    }

    handleSearchInputChange(event) {
        const field = event.target.dataset.field;
        const value = field === 'passengerCount' ? parseInt(event.target.value) : event.target.value;
        
        this.searchCriteria = {
            ...this.searchCriteria,
            [field]: value
        };

        // Reset results if search criteria changes
        if (this.showResults) {
            this.showResults = false;
            this.searchResults = [];
        }
    }

    handlePopularRouteClick(event) {
        const routeIndex = parseInt(event.currentTarget.dataset.routeIndex);
        const route = this.popularRoutes[routeIndex];
        
        this.searchCriteria = {
            ...this.searchCriteria,
            fromStation: route.fromCode,
            toStation: route.toCode
        };
    }

    handleSwapStations() {
        const temp = this.searchCriteria.fromStation;
        this.searchCriteria = {
            ...this.searchCriteria,
            fromStation: this.searchCriteria.toStation,
            toStation: temp
        };
    }

    async handleSearch() {
        if (!this.validateSearchCriteria()) {
            return;
        }

        this.isLoading = true;
        this.showResults = false;
        
        try {
            // Search for trains
            const trains = await searchTrains({
                fromStation: this.searchCriteria.fromStation,
                toStation: this.searchCriteria.toStation,
                journeyDate: this.searchCriteria.journeyDate
            });

            if (trains.length === 0) {
                this.showToast('No Results', 'No trains found for the selected route and date', 'info');
                this.searchResults = [];
                this.showResults = false;
                return;
            }

            // Get availability for each train and coach type combination
            this.searchResults = [];
            
            for (const train of trains) {
                const trainResult = {
                    ...train,
                    id: train.trainId,
                    availabilityByCoach: new Map(),
                    bestAvailability: null,
                    canBook: false
                };

                // Check availability for each coach type available on this train
                const coachAvailabilities = [];
                
                for (const coachType of train.availableCoachTypes) {
                    try {
                        const availabilityData = await checkAvailability({
                            trainId: train.trainId,
                            journeyDate: this.searchCriteria.journeyDate,
                            fromOrder: train.fromStationOrder,
                            toOrder: train.toStationOrder,
                            coachType: coachType
                        });

                        const coachAvailability = {
                            coachType: coachType,
                            ...availabilityData,
                            availabilityClass: this.getAvailabilityClass(availabilityData),
                            bookingLabel: availabilityData.totalAvailable > 0 ? 'Book Now' : 'Join Waitlist',
                            canBook: availabilityData.totalAvailable >= this.searchCriteria.passengerCount,
                            buttonVariant: availabilityData.totalAvailable >= this.searchCriteria.passengerCount ? 'brand' : 'outline-brand'
                        };

                        coachAvailabilities.push(coachAvailability);
                        trainResult.availabilityByCoach.set(coachType, coachAvailability);

                        // Track if any coach type can accommodate the booking
                        if (coachAvailability.canBook) {
                            trainResult.canBook = true;
                        }
                    } catch (error) {
                        console.error(`Availability check failed for ${train.trainNumber} - ${coachType}:`, error);
                    }
                }

                // Set best availability (prioritize requested coach type, then highest availability)
                if (trainResult.availabilityByCoach.has(this.searchCriteria.coachType)) {
                    trainResult.bestAvailability = trainResult.availabilityByCoach.get(this.searchCriteria.coachType);
                } else if (coachAvailabilities.length > 0) {
                    // Find coach type with best availability
                    trainResult.bestAvailability = coachAvailabilities.reduce((best, current) => 
                        current.totalAvailable > best.totalAvailable ? current : best
                    );
                }

                trainResult.coachAvailabilities = coachAvailabilities;
                this.searchResults.push(trainResult);
            }

            // Sort results by availability and departure time
            this.searchResults.sort((a, b) => {
                // Prioritize bookable trains
                if (a.canBook && !b.canBook) return -1;
                if (!a.canBook && b.canBook) return 1;
                
                // Then by best availability
                const aAvail = a.bestAvailability ? a.bestAvailability.totalAvailable : 0;
                const bAvail = b.bestAvailability ? b.bestAvailability.totalAvailable : 0;
                if (aAvail !== bAvail) return bAvail - aAvail;
                
                // Finally by departure time
                return a.departureTime.localeCompare(b.departureTime);
            });

            this.showResults = true;
            
        } catch (error) {
            console.error('Search Error:', error);
            this.showToast('Error', 'Failed to search trains: ' + error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    getAvailabilityClass(availability) {
        if (availability.totalAvailable === 0) return 'availability-none';
        if (availability.totalAvailable < 10) return 'availability-low';
        if (availability.partiallyAvailable > 0) return 'availability-smart';
        return 'availability-good';
    }

    getAvailabilityVariant(availability) {
        if (availability.totalAvailable === 0) return 'error';
        if (availability.totalAvailable < 10) return 'warning';
        if (availability.partiallyAvailable > 0) return 'brand';
        return 'success';
    }

    validateSearchCriteria() {
        if (!this.searchCriteria.fromStation || !this.searchCriteria.toStation || !this.searchCriteria.journeyDate) {
            this.showToast('Error', 'Please fill all required fields', 'error');
            return false;
        }
        
        if (this.searchCriteria.fromStation === this.searchCriteria.toStation) {
            this.showToast('Error', 'From and To stations cannot be the same', 'error');
            return false;
        }

        const selectedDate = new Date(this.searchCriteria.journeyDate);
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        
        if (selectedDate < today) {
            this.showToast('Error', 'Journey date cannot be in the past', 'error');
            return false;
        }

        const maxDate = new Date(today.getTime() + (120 * 24 * 60 * 60 * 1000));
        if (selectedDate > maxDate) {
            this.showToast('Error', 'Journey date cannot be more than 120 days from today', 'error');
            return false;
        }

        return true;
    }

    handleTrainSelection(event) {
        const selectedTrainId = event.currentTarget.dataset.trainId;
        const coachType = event.currentTarget.dataset.coachType || this.searchCriteria.coachType;
        
        const selectedTrain = this.searchResults.find(train => train.trainId === selectedTrainId);
        const availability = selectedTrain.availabilityByCoach.get(coachType);
        
        // Fire event to parent component with all necessary data
        this.dispatchEvent(new CustomEvent('trainselected', {
            detail: {
                train: selectedTrain,
                coachType: coachType,
                availability: availability,
                searchCriteria: { ...this.searchCriteria, coachType: coachType },
                bookingData: {
                    trainId: selectedTrainId,
                    trainName: selectedTrain.trainName,
                    trainNumber: selectedTrain.trainNumber,
                    fromStation: this.searchCriteria.fromStation,
                    toStation: this.searchCriteria.toStation,
                    fromStationOrder: selectedTrain.fromStationOrder,
                    toStationOrder: selectedTrain.toStationOrder,
                    journeyDate: this.searchCriteria.journeyDate,
                    coachType: coachType,
                    passengerCount: this.searchCriteria.passengerCount,
                    departureTime: selectedTrain.departureTime,
                    arrivalTime: selectedTrain.arrivalTime,
                    duration: selectedTrain.duration,
                    canConfirm: availability.totalAvailable >= this.searchCriteria.passengerCount
                }
            }
        }));
    }

    handleCoachTypeChange(event) {
        const trainId = event.currentTarget.dataset.trainId;
        const newCoachType = event.detail.value;
        
        // Update the display immediately
        const train = this.searchResults.find(t => t.trainId === trainId);
        if (train && train.availabilityByCoach.has(newCoachType)) {
            train.bestAvailability = train.availabilityByCoach.get(newCoachType);
        }
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'pester'
        });
        this.dispatchEvent(evt);
    }

    // Utility methods for template
    get hasPopularRoutes() {
        return this.popularRoutes && this.popularRoutes.length > 0;
    }

    get hasSearchResults() {
        return this.searchResults && this.searchResults.length > 0;
    }

    get searchSummary() {
        if (!this.hasSearchResults) return '';
        
        const fromStationName = this.getStationName(this.searchCriteria.fromStation);
        const toStationName = this.getStationName(this.searchCriteria.toStation);
        const bookableTrains = this.searchResults.filter(train => train.canBook).length;
        
        return `Found ${this.searchResults.length} trains from ${fromStationName} to ${toStationName} on ${this.formatDate(this.searchCriteria.journeyDate)}. ${bookableTrains} train(s) have confirmed seats available.`;
    }

    getStationName(stationCode) {
        const station = this.stationOptions.find(s => s.value === stationCode);
        return station ? station.label : stationCode;
    }

    formatDate(dateString) {
        const date = new Date(dateString);
        return date.toLocaleDateString('en-IN', { 
            weekday: 'short', 
            year: 'numeric', 
            month: 'short', 
            day: 'numeric' 
        });
    }

    getCoachTypeLabel(coachType) {
        const coach = this.coachTypeOptions.find(c => c.value === coachType);
        return coach ? coach.label.split(' - ')[0] : coachType;
    }

    // Reset search
    handleReset() {
        this.searchCriteria = {
            fromStation: '',
            toStation: '',
            journeyDate: '',
            coachType: 'SL',
            passengerCount: 1
        };
        this.searchResults = [];
        this.showResults = false;
        this.selectedTrain = null;
        
        // Set default journey date to tomorrow
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        this.searchCriteria.journeyDate = tomorrow.toISOString().split('T')[0];
    }
}