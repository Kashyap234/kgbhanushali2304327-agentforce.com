/**
 * BookingIntegrationController.cls - Complete booking workflow integration
 */
public with sharing class BookingIntegrationController {
    
    @AuraEnabled
    public static BookingInitiationResult initiateBooking(BookingRequestData requestData) {
        try {
            // Validate booking request
            ValidationResult validation = validateBookingRequest(requestData);
            if (!validation.isValid) {
                return new BookingInitiationResult(false, validation.errorMessage, null);
            }
            
            // Get current availability before booking
            AvailabilityResponse currentAvailability = SegmentAvailabilityService.checkSegmentAvailability(
                requestData.trainId, requestData.journeyDate, 
                requestData.fromStationOrder, requestData.toStationOrder, 
                requestData.coachType
            );
            
            // Check if enough seats are available
            if (currentAvailability.totalAvailable < requestData.passengerCount && !requestData.allowWaitlist) {
                return new BookingInitiationResult(false, 
                    'Insufficient seats available. ' + currentAvailability.totalAvailable + ' seats available but ' + requestData.passengerCount + ' requested.', 
                    currentAvailability);
            }
            
            // Create booking record
            Booking__c booking = createBookingRecord(requestData, currentAvailability);
            insert booking;
            
            // Process seat allocation through trigger
            // The BookingTriggerHandler will handle the allocation asynchronously
            
            return new BookingInitiationResult(true, 'Booking initiated successfully', currentAvailability, booking.Id);
            
        } catch (Exception e) {
            System.debug('Booking initiation error: ' + e.getMessage());
            return new BookingInitiationResult(false, 'Booking failed: ' + e.getMessage(), null);
        }
    }
    
    @AuraEnabled
    public static BookingStatusResult getBookingStatus(String bookingId) {
        try {
            Booking__c booking = [
                SELECT Id, Booking_Status__c, Confirmed_Seats__c, Waitlisted_Seats__c,
                       Allocation_Details__c, Failure_Reason__c, Total_Amount__c,
                       Train__r.Name, Train__r.Train_Number__c,
                       Source_Station__r.Name, Source_Station__r.Station_Code__c,
                       Destination_Station__r.Name, Destination_Station__r.Station_Code__c,
                       Journey_Date__c, Coach_Type__c, Total_Passengers__c,
                       CreatedDate, LastModifiedDate,
                       (SELECT Id, Name__c, Assigned_Seat_Allocation__r.Seat__r.Seat_Number__c,
                               Assigned_Seat_Allocation__r.Seat__r.Coach__r.Coach_Number__c,
                               Ticket_Status__c
                        FROM Passengers__r)
                FROM Booking__c 
                WHERE Id = :bookingId
                LIMIT 1
            ];
            
            // Get seat allocation details if confirmed
            List<SeatAllocationInfo> seatAllocations = new List<SeatAllocationInfo>();
            if (booking.Booking_Status__c == 'Confirmed' || booking.Booking_Status__c == 'Partially Confirmed') {
                for (Passenger__c passenger : booking.Passengers__r) {
                    if (passenger.Assigned_Seat_Allocation__r != null) {
                        seatAllocations.add(new SeatAllocationInfo(
                            passenger.Name__c,
                            passenger.Assigned_Seat_Allocation__r.Seat__r.Coach__r.Coach_Number__c,
                            passenger.Assigned_Seat_Allocation__r.Seat__r.Seat_Number__c,
                            passenger.Ticket_Status__c
                        ));
                    }
                }
            }
            
            return new BookingStatusResult(booking, seatAllocations);
            
        } catch (Exception e) {
            System.debug('Booking status error: ' + e.getMessage());
            throw new AuraHandledException('Failed to get booking status: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<BookingSummary> getRecentBookings(String contactId, Integer limitCount) {
        try {
            if (limitCount == null) limitCount = 10;
            
            List<BookingSummary> bookings = new List<BookingSummary>();
            
            for (Booking__c booking : [
                SELECT Id, Booking_Status__c, Total_Passengers__c, Total_Amount__c,
                       Train__r.Name, Train__r.Train_Number__c,
                       Source_Station__r.Station_Code__c, Destination_Station__r.Station_Code__c,
                       Journey_Date__c, Coach_Type__c, CreatedDate,
                       Confirmed_Seats__c, Waitlisted_Seats__c
                FROM Booking__c 
                WHERE Contact__c = :contactId
                ORDER BY CreatedDate DESC
                LIMIT :limitCount
            ]) {
                bookings.add(new BookingSummary(booking));
            }
            
            return bookings;
            
        } catch (Exception e) {
            System.debug('Recent bookings error: ' + e.getMessage());
            throw new AuraHandledException('Failed to get recent bookings: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static CancellationResult cancelBooking(String bookingId, String cancellationReason) {
        try {
            Booking__c booking = [SELECT Id, Booking_Status__c, Journey_Date__c FROM Booking__c WHERE Id = :bookingId LIMIT 1];
            
            // Validate cancellation
            if (booking.Booking_Status__c == 'Cancelled') {
                return new CancellationResult(false, 'Booking is already cancelled', null);
            }
            
            Date today = Date.today();
            if (booking.Journey_Date__c <= today) {
                return new CancellationResult(false, 'Cannot cancel booking for past or current date', null);
            }
            
            // Calculate refund amount (simplified logic)
            Decimal refundAmount = calculateRefundAmount(bookingId, cancellationReason);
            
            // Update booking status
            booking.Booking_Status__c = 'Cancelled';
            booking.Cancellation_Reason__c = cancellationReason;
            booking.Cancellation_Date__c = Datetime.now();
            booking.Refund_Amount__c = refundAmount;
            
            update booking;
            
            // Release allocated seats (this would trigger seat reallocation logic)
            releaseCancelledSeats(bookingId);
            
            return new CancellationResult(true, 'Booking cancelled successfully', refundAmount);
            
        } catch (Exception e) {
            System.debug('Cancellation error: ' + e.getMessage());
            return new CancellationResult(false, 'Cancellation failed: ' + e.getMessage(), null);
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static PricingInfo getBookingPricing(String trainId, String coachType, 
                                              Integer fromStationOrder, Integer toStationOrder, 
                                              Integer passengerCount) {
        try {
            // Get base fare information
            List<Train_Fare__c> fares = [
                SELECT Base_Fare__c, Distance_Multiplier__c, Coach_Type_Multiplier__c
                FROM Train_Fare__c 
                WHERE Train__c = :trainId 
                AND Coach_Type__c = :coachType
                LIMIT 1
            ];
            
            if (fares.isEmpty()) {
                throw new AuraHandledException('Fare information not available for selected train and coach type');
            }
            
            Train_Fare__c fare = fares[0];
            
            // Calculate distance-based fare
            Decimal distance = calculateSegmentDistance(trainId, fromStationOrder, toStationOrder);
            Decimal baseFare = fare.Base_Fare__c * (distance * fare.Distance_Multiplier__c);
            
            // Apply coach type multiplier
            Decimal farePerPassenger = baseFare * fare.Coach_Type_Multiplier__c;
            
            // Calculate taxes and fees
            Decimal gst = farePerPassenger * 0.05; // 5% GST
            Decimal serviceFee = 20; // Fixed service fee
            Decimal totalPerPassenger = farePerPassenger + gst + serviceFee;
            
            return new PricingInfo(farePerPassenger, gst, serviceFee, totalPerPassenger, passengerCount);
            
        } catch (Exception e) {
            System.debug('Pricing calculation error: ' + e.getMessage());
            throw new AuraHandledException('Failed to calculate pricing: ' + e.getMessage());
        }
    }
    
    // Helper methods
    private static ValidationResult validateBookingRequest(BookingRequestData requestData) {
        if (String.isBlank(requestData.trainId)) {
            return new ValidationResult(false, 'Train ID is required');
        }
        if (requestData.journeyDate == null) {
            return new ValidationResult(false, 'Journey date is required');
        }
        if (requestData.journeyDate <= Date.today()) {
            return new ValidationResult(false, 'Journey date must be in the future');
        }
        if (requestData.passengerCount <= 0 || requestData.passengerCount > 6) {
            return new ValidationResult(false, 'Passenger count must be between 1 and 6');
        }
        if (requestData.fromStationOrder == null || requestData.toStationOrder == null) {
            return new ValidationResult(false, 'Station orders are required');
        }
        if (requestData.fromStationOrder >= requestData.toStationOrder) {
            return new ValidationResult(false, 'Invalid station sequence');
        }
        
        return new ValidationResult(true, null);
    }
    
    private static Booking__c createBookingRecord(BookingRequestData requestData, AvailabilityResponse availability) {
        Booking__c booking = new Booking__c();
        booking.Train__c = requestData.trainId;
        booking.Source_Station__c = getStationIdFromOrder(requestData.trainId, requestData.fromStationOrder);
        booking.Destination_Station__c = getStationIdFromOrder(requestData.trainId, requestData.toStationOrder);
        booking.Journey_Date__c = requestData.journeyDate;
        booking.Coach_Type__c = requestData.coachType;
        booking.Total_Passengers__c = requestData.passengerCount;
        booking.Contact__c = requestData.contactId;
        booking.Booking_Status__c = 'Processing';
        booking.Booking_Source__c = 'Online';
        booking.Special_Requirements__c = requestData.specialRequirements;
        
        // Calculate and set amount
        PricingInfo pricing = getBookingPricing(requestData.trainId, requestData.coachType, 
                                              requestData.fromStationOrder, requestData.toStationOrder, 
                                              requestData.passengerCount);
        booking.Total_Amount__c = pricing.totalAmount;
        
        return booking;
    }
    
    private static String getStationIdFromOrder(String trainId, Integer stationOrder) {
        List<Route__c> routes = [
            SELECT Station__c 
            FROM Route__c 
            WHERE Train__c = :trainId AND Stop_Number__c = :stationOrder 
            LIMIT 1
        ];
        return routes.isEmpty() ? null : routes[0].Station__c;
    }
    
    private static Decimal calculateSegmentDistance(String trainId, Integer fromOrder, Integer toOrder) {
        List<Route__c> routes = [
            SELECT Distance_from_Source__c, Stop_Number__c
            FROM Route__c 
            WHERE Train__c = :trainId 
            AND Stop_Number__c IN (:fromOrder, :toOrder)
            ORDER BY Stop_Number__c
        ];
        
        if (routes.size() != 2) return 100; // Default distance
        
        return routes[1].Distance_from_Source__c - routes[0].Distance_from_Source__c;
    }
    
    private static Decimal calculateRefundAmount(String bookingId, String cancellationReason) {
        // Simplified refund calculation - in reality, this would be more complex
        Booking__c booking = [SELECT Total_Amount__c, Journey_Date__c FROM Booking__c WHERE Id = :bookingId];
        
        Integer daysToJourney = booking.Journey_Date__c.daysBetween(Date.today());
        
        if (daysToJourney > 1) {
            return booking.Total_Amount__c * 0.9; // 90% refund
        } else {
            return booking.Total_Amount__c * 0.5; // 50% refund for same day
        }
    }
    
    private static void releaseCancelledSeats(String bookingId) {
        // Update seat allocations to cancelled status
        List<Seat_Segment_Allocation__c> allocations = [
            SELECT Id FROM Seat_Segment_Allocation__c WHERE Booking__c = :bookingId
        ];
        
        for (Seat_Segment_Allocation__c allocation : allocations) {
            allocation.Allocation_Status__c = 'Cancelled';
        }
        
        if (!allocations.isEmpty()) {
            update allocations;
        }
    }
    
    // Wrapper Classes
    public class BookingRequestData {
        @AuraEnabled public String trainId;
        @AuraEnabled public String coachType;
        @AuraEnabled public Date journeyDate;
        @AuraEnabled public Integer fromStationOrder;
        @AuraEnabled public Integer toStationOrder;
        @AuraEnabled public Integer passengerCount;
        @AuraEnabled public String contactId;
        @AuraEnabled public Boolean allowWaitlist;
        @AuraEnabled public String specialRequirements;
        @AuraEnabled public List<PassengerData> passengers;
    }
    
    public class PassengerData {
        @AuraEnabled public String name;
        @AuraEnabled public Integer age;
        @AuraEnabled public String gender;
        @AuraEnabled public String berthPreference;
    }
    
    public class BookingInitiationResult {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String message;
        @AuraEnabled public AvailabilityResponse availabilityData;
        @AuraEnabled public String bookingId;
        
        public BookingInitiationResult(Boolean success, String msg, AvailabilityResponse avail) {
            this(success, msg, avail, null);
        }
        
        public BookingInitiationResult(Boolean success, String msg, AvailabilityResponse avail, String bId) {
            this.isSuccess = success;
            this.message = msg;
            this.availabilityData = avail;
            this.bookingId = bId;
        }
    }
    
    public class BookingStatusResult {
        @AuraEnabled public String bookingId;
        @AuraEnabled public String status;
        @AuraEnabled public String trainName;
        @AuraEnabled public String trainNumber;
        @AuraEnabled public String fromStation;
        @AuraEnabled public String toStation;
        @AuraEnabled public Date journeyDate;
        @AuraEnabled public String coachType;
        @AuraEnabled public Integer totalPassengers;
        @AuraEnabled public Integer confirmedSeats;
        @AuraEnabled public Integer waitlistedSeats;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public String allocationDetails;
        @AuraEnabled public String failureReason;
        @AuraEnabled public List<SeatAllocationInfo> seatAllocations;
        
        public BookingStatusResult(Booking__c booking, List<SeatAllocationInfo> allocations) {
            this.bookingId = booking.Id;
            this.status = booking.Booking_Status__c;
            this.trainName = booking.Train__r.Name;
            this.trainNumber = String.valueOf(booking.Train__r.Train_Number__c);
            this.fromStation = booking.Source_Station__r.Name + ' (' + booking.Source_Station__r.Station_Code__c + ')';
            this.toStation = booking.Destination_Station__r.Name + ' (' + booking.Destination_Station__r.Station_Code__c + ')';
            this.journeyDate = booking.Journey_Date__c;
            this.coachType = booking.Coach_Type__c;
            this.totalPassengers = Integer.valueOf(booking.Total_Passengers__c);
            this.confirmedSeats = Integer.valueOf(booking.Confirmed_Seats__c);
            this.waitlistedSeats = Integer.valueOf(booking.Waitlisted_Seats__c);
            this.totalAmount = booking.Total_Amount__c;
            this.allocationDetails = booking.Allocation_Details__c;
            this.failureReason = booking.Failure_Reason__c;
            this.seatAllocations = allocations;
        }
    }
    
    public class BookingSummary {
        @AuraEnabled public String bookingId;
        @AuraEnabled public String status;
        @AuraEnabled public String trainInfo;
        @AuraEnabled public String route;
        @AuraEnabled public Date journeyDate;
        @AuraEnabled public String coachType;
        @AuraEnabled public Integer passengers;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Date bookingDate;
        
        public BookingSummary(Booking__c booking) {
            this.bookingId = booking.Id;
            this.status = booking.Booking_Status__c;
            this.trainInfo = booking.Train__r.Name + ' (' + booking.Train__r.Train_Number__c + ')';
            this.route = booking.Source_Station__r.Station_Code__c + ' → ' + booking.Destination_Station__r.Station_Code__c;
            this.journeyDate = booking.Journey_Date__c;
            this.coachType = booking.Coach_Type__c;
            this.passengers = Integer.valueOf(booking.Total_Passengers__c);
            this.amount = booking.Total_Amount__c;
            this.bookingDate = booking.CreatedDate.date();
        }
    }
    
    public class SeatAllocationInfo {
        @AuraEnabled public String passengerName;
        @AuraEnabled public String coachNumber;
        @AuraEnabled public String seatNumber;
        @AuraEnabled public String status;
        
        public SeatAllocationInfo(String name, String coach, String seat, String stat) {
            this.passengerName = name;
            this.coachNumber = coach;
            this.seatNumber = seat;
            this.status = stat;
        }
    }
    
    public class CancellationResult {
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String message;
        @AuraEnabled public Decimal refundAmount;
        
        public CancellationResult(Boolean success, String msg, Decimal refund) {
            this.isSuccess = success;
            this.message = msg;
            this.refundAmount = refund;
        }
    }
    
    public class PricingInfo {
        @AuraEnabled public Decimal baseFare;
        @AuraEnabled public Decimal gst;
        @AuraEnabled public Decimal serviceFee;
        @AuraEnabled public Decimal farePerPassenger;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Integer passengerCount;
        
        public PricingInfo(Decimal base, Decimal tax, Decimal fee, Decimal perPassenger, Integer count) {
            this.baseFare = base;
            this.gst = tax;
            this.serviceFee = fee;
            this.farePerPassenger = perPassenger;
            this.passengerCount = count;
            this.totalAmount = perPassenger * count;
        }
    }
    
    private class ValidationResult {
        public Boolean isValid;
        public String errorMessage;
        
        public ValidationResult(Boolean valid, String error) {
            this.isValid = valid;
            this.errorMessage = error;
        }
    }
}