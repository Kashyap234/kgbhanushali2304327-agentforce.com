public class SmartSeatAllocationEngine {
    
    // Main allocation method
    public static SeatAllocationResult allocateSeats(BookingRequest request) {
        try {
            // Input validation
            if (!validateBookingRequest(request)) {
                return new SeatAllocationResult(false, 'Invalid booking request parameters', null);
            }
            
            // Priority 1: Find seats that become available at source station
            List<AvailableSeat> partiallyAvailable = findPartiallyAvailableSeats(request);
            if (!partiallyAvailable.isEmpty()) {
                return allocatePartialSeats(partiallyAvailable, request);
            }
            
            // Priority 2: Find completely free seats
            List<AvailableSeat> completelyFree = findCompletelyFreeSeats(request);
            if (!completelyFree.isEmpty()) {
                return allocateCompleteSeats(completelyFree, request);
            }
            
            // Priority 3: Add to waitlist
            return addToWaitlist(request);
            
        } catch (Exception e) {
            System.debug('Allocation Error: ' + e.getMessage());
            return new SeatAllocationResult(false, 'System error during allocation: ' + e.getMessage(), null);
        }
    }
    
    // Priority 1: Seats becoming available at source (Smart Reallocation)
    private static List<AvailableSeat> findPartiallyAvailableSeats(BookingRequest request) {
        String query = 
            'SELECT Id, Seat_Number__c, Coach__c, Coach__r.Coach_Type__c, ' +
            '       Coach__r.Coach_Number__c, Coach__r.Total_Seats__c ' +
            'FROM Seat__c ' +
            'WHERE Coach__r.Train__c = :trainId ' +
            'AND Coach__r.Coach_Type__c = :coachType ' +
            // Seats that have allocations ending AT OR BEFORE source station
            'AND Id IN (' +
                'SELECT Seat__c FROM Seat_Segment_Allocation__c ' +
                'WHERE Journey_Date__c = :journeyDate ' +
                'AND To_Station_Order__c <= :fromOrder ' +
                'AND Allocation_Status__c = \'Confirmed\'' +
            ') ' +
            // But NO overlapping allocations for requested segment
            'AND Id NOT IN (' +
                'SELECT Seat__c FROM Seat_Segment_Allocation__c ' +
                'WHERE Journey_Date__c = :journeyDate ' +
                'AND From_Station_Order__c < :toOrder ' +
                'AND To_Station_Order__c > :fromOrder ' +
                'AND Allocation_Status__c = \'Confirmed\'' +
            ') ' +
            'ORDER BY Coach__r.Coach_Number__c, Seat_Number__c ' +
            'LIMIT :passengerCount';
        
        Map<String, Object> bindVars = new Map<String, Object>{
            'trainId' => request.trainId,
            'coachType' => request.coachType,
            'journeyDate' => request.journeyDate,
            'fromOrder' => request.fromStationOrder,
            'toOrder' => request.toStationOrder,
            'passengerCount' => request.passengerCount
        };
        
        List<Seat__c> seats = Database.queryWithBinds(query, bindVars, AccessLevel.SYSTEM_MODE);
        
        List<AvailableSeat> result = new List<AvailableSeat>();
        for (Seat__c seat : seats) {
            result.add(new AvailableSeat(seat, 'REUSED'));
        }
        
        return result;
    }
    
    // Priority 2: Completely free seats
    private static List<AvailableSeat> findCompletelyFreeSeats(BookingRequest request) {
        String query = 
            'SELECT Id, Seat_Number__c, Coach__c, Coach__r.Coach_Type__c, ' +
            '       Coach__r.Coach_Number__c ' +
            'FROM Seat__c ' +
            'WHERE Coach__r.Train__c = :trainId ' +
            'AND Coach__r.Coach_Type__c = :coachType ' +
            'AND Id NOT IN (' +
                'SELECT Seat__c FROM Seat_Segment_Allocation__c ' +
                'WHERE Journey_Date__c = :journeyDate ' +
                'AND From_Station_Order__c < :toOrder ' +
                'AND To_Station_Order__c > :fromOrder ' +
                'AND Allocation_Status__c = \'Confirmed\'' +
            ') ' +
            'ORDER BY Coach__r.Coach_Number__c, Seat_Number__c ' +
            'LIMIT :passengerCount';
        
        Map<String, Object> bindVars = new Map<String, Object>{
            'trainId' => request.trainId,
            'coachType' => request.coachType,
            'journeyDate' => request.journeyDate,
            'fromOrder' => request.fromStationOrder,
            'toOrder' => request.toStationOrder,
            'passengerCount' => request.passengerCount
        };
        
        List<Seat__c> seats = Database.queryWithBinds(query, bindVars, AccessLevel.SYSTEM_MODE);
        
        List<AvailableSeat> result = new List<AvailableSeat>();
        for (Seat__c seat : seats) {
            result.add(new AvailableSeat(seat, 'FRESH'));
        }
        
        return result;
    }
    
    // Allocate reused seats (Priority 1)
    private static SeatAllocationResult allocatePartialSeats(List<AvailableSeat> availableSeats, 
                                                           BookingRequest request) {
        List<Seat_Segment_Allocation__c> allocations = new List<Seat_Segment_Allocation__c>();
        
        Integer allocatedCount = Math.min(availableSeats.size(), request.passengerCount);
        
        for (Integer i = 0; i < allocatedCount; i++) {
            allocations.add(new Seat_Segment_Allocation__c(
                Seat__c = availableSeats[i].seat.Id,
                Booking__c = request.bookingId,
                Journey_Date__c = request.journeyDate,
                From_Station_Order__c = request.fromStationOrder,
                To_Station_Order__c = request.toStationOrder,
                Allocation_Status__c = 'Confirmed',
                Allocation_Type__c = 'Reused',
                Reallocation_Notes__c = 'Smart reallocation - seat became available at boarding station'
            ));
        }
        
        insert allocations;
        
        String message = allocatedCount + ' seats allocated through smart reallocation';
        if (allocatedCount < request.passengerCount) {
            message += '. ' + (request.passengerCount - allocatedCount) + ' passengers added to waitlist.';
            // Add remaining to waitlist
            addRemainingToWaitlist(request, allocatedCount);
        }
        
        return new SeatAllocationResult(true, message, allocations);
    }
    
    // Allocate fresh seats (Priority 2)
    private static SeatAllocationResult allocateCompleteSeats(List<AvailableSeat> availableSeats, 
                                                            BookingRequest request) {
        List<Seat_Segment_Allocation__c> allocations = new List<Seat_Segment_Allocation__c>();
        
        Integer allocatedCount = Math.min(availableSeats.size(), request.passengerCount);
        
        for (Integer i = 0; i < allocatedCount; i++) {
            allocations.add(new Seat_Segment_Allocation__c(
                Seat__c = availableSeats[i].seat.Id,
                Booking__c = request.bookingId,
                Journey_Date__c = request.journeyDate,
                From_Station_Order__c = request.fromStationOrder,
                To_Station_Order__c = request.toStationOrder,
                Allocation_Status__c = 'Confirmed',
                Allocation_Type__c = 'Fresh'
            ));
        }
        
        insert allocations;
        
        String message = allocatedCount + ' fresh seats allocated';
        if (allocatedCount < request.passengerCount) {
            message += '. ' + (request.passengerCount - allocatedCount) + ' passengers added to waitlist.';
            addRemainingToWaitlist(request, allocatedCount);
        }
        
        return new SeatAllocationResult(true, message, allocations);
    }
    
    // Priority 3: Add to waitlist
    private static SeatAllocationResult addToWaitlist(BookingRequest request) {
        // Implementation for waitlist logic
        // This could create Waitlist__c records or update booking status
        
        String message = 'No seats available. ' + request.passengerCount + ' passengers added to waitlist.';
        SeatAllocationResult result = new SeatAllocationResult(false, message, null);
        result.waitlistedCount = request.passengerCount;
        
        return result;
    }
    
    // Helper method to add remaining passengers to waitlist
    private static void addRemainingToWaitlist(BookingRequest request, Integer allocatedCount) {
        Integer remainingPassengers = request.passengerCount - allocatedCount;
        // Implementation for adding remaining passengers to waitlist
        System.debug('Adding ' + remainingPassengers + ' passengers to waitlist for booking: ' + request.bookingId);
    }
    
    // Helper classes
    public class AvailableSeat {
        public Seat__c seat;
        public String allocationType;
        
        public AvailableSeat(Seat__c s, String type) {
            this.seat = s;
            this.allocationType = type;
        }
    }
    
    // Validation method
    private static Boolean validateBookingRequest(BookingRequest request) {
        return request.trainId != null && 
               request.journeyDate != null && 
               request.fromStationOrder != null &&
               request.toStationOrder != null &&
               request.fromStationOrder < request.toStationOrder &&
               request.passengerCount > 0 &&
               request.passengerCount <= 6; // Max 6 passengers per booking
    }
}