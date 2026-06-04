/**
 * BookingTriggerHandler.cls - Handles booking lifecycle events
 */
public class BookingTriggerHandler {
    
    public static void handleAfterInsert(Set<Id> newBookingIds) {
        // Correctly pass IDs to the future method
        processNewBookings(newBookingIds);
    }
    
    public static void handleAfterUpdate(List<Booking__c> newBookings, Map<Id, Booking__c> oldMap) {
        List<Booking__c> statusChangedBookings = new List<Booking__c>();
        
        for (Booking__c booking : newBookings) {
            Booking__c oldBooking = oldMap.get(booking.Id);
            if (booking.Booking_Status__c != oldBooking.Booking_Status__c) {
                statusChangedBookings.add(booking);
            }
        }
        
        if (!statusChangedBookings.isEmpty()) {
            // Add the missing method call
            handleStatusChanges(statusChangedBookings, oldMap);
        }
    }
    
    @future
    private static void processNewBookings(Set<Id> bookingIds) {
        // Query the records inside the future method
        List<Booking__c> bookings = [SELECT Id, Train__c, Coach_Type__c, Journey_Date__c, Source_Station__c, Destination_Station__c, Total_Passengers__c FROM Booking__c WHERE Id IN :bookingIds];
        for (Booking__c booking : bookings) {
            try {
                // Execute smart seat allocation
                BookingRequest request = createBookingRequest(booking);
                SeatAllocationResult result = SmartSeatAllocationEngine.allocateSeats(request);
                
                // Update booking with allocation results
                updateBookingWithResults(booking.Id, result);
                
                // Send confirmation/waitlist notification
                sendBookingNotification(booking.Id, result);
                
            } catch (Exception e) {
                System.debug('Booking processing error for ' + booking.Id + ': ' + e.getMessage());
                // Update booking status to error
                updateBookingStatus(booking.Id, 'Error', e.getMessage());
            }
        }
    }
    
    private static BookingRequest createBookingRequest(Booking__c booking) {
        // Get route information to determine station orders
        List<Route__c> routes = [
            SELECT Stop_Number__c, Station__r.Station_Code__c
            FROM Route__c 
            WHERE Train__c = :booking.Train__c
            AND (Station__c = :booking.Source_Station__c OR Station__c = :booking.Destination_Station__c)
            ORDER BY Stop_Number__c
        ];
        
        Integer fromOrder = null, toOrder = null;
        for (Route__c route : routes) {
            if (route.Station__c == booking.Source_Station__c) {
                fromOrder = Integer.valueOf(route.Stop_Number__c);
            } else if (route.Station__c == booking.Destination_Station__c) {
                toOrder = Integer.valueOf(route.Stop_Number__c);
            }
        }
        
        BookingRequest request = new BookingRequest(
            booking.Train__c,
            booking.Coach_Type__c, // Correct field name
            booking.Journey_Date__c,
            fromOrder,
            toOrder,
            Integer.valueOf(booking.Total_Passengers__c),
            booking.Id
        );
        
        return request;
    }
    
    private static void updateBookingWithResults(Id bookingId, SeatAllocationResult result) {
        Booking__c booking = new Booking__c(Id = bookingId);
        
        if (result.isSuccess) {
            booking.Booking_Status__c = result.confirmedCount > 0 ? 'Confirmed' : 'Waitlisted';
            booking.Confirmed_Seats__c = result.confirmedCount;
            booking.Waitlisted_Seats__c = result.waitlistedCount;
            booking.Allocation_Details__c = result.message;
        } else {
            booking.Booking_Status__c = 'Failed';
            booking.Failure_Reason__c = result.message;
        }
        
        update booking;
        
        // Create passenger records if seats were allocated
        if (result.isSuccess && result.allocations != null && !result.allocations.isEmpty()) {
            createPassengerRecords(bookingId, result.allocations);
        }
    }
    
    private static void createPassengerRecords(Id bookingId, List<Seat_Segment_Allocation__c> allocations) {
        // This will be expanded in Phase 2 with passenger details
        // For now, create placeholder passenger records
        
        List<Passenger__c> passengers = new List<Passenger__c>();
        Integer passengerNumber = 1;
        
        for (Seat_Segment_Allocation__c allocation : allocations) {
            passengers.add(new Passenger__c(
                Booking__c = bookingId,
                Name__c = 'Passenger ' + passengerNumber,
                Passenger_Number__c = passengerNumber,
                Assigned_Seat_Allocation__c = allocation.Id,
                Ticket_Status__c = allocation.Allocation_Status__c
            ));
            passengerNumber++;
        }
        
        if (!passengers.isEmpty()) {
            insert passengers;
        }
    }
    
    // Empty stub methods added to resolve compile errors
    private static void handleStatusChanges(List<Booking__c> statusChangedBookings, Map<Id, Booking__c> oldMap) {
        // Implementation for handling status changes
    }

    private static void sendBookingNotification(Id bookingId, SeatAllocationResult result) {
        // Implementation for sending notifications
    }

    private static void updateBookingStatus(Id bookingId, String status, String message) {
        // Implementation for updating booking status
    }
}