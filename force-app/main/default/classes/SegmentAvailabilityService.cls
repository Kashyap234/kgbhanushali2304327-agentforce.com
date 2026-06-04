/**
 * SegmentAvailabilityService.cls - Real-time availability checking
 */
public class SegmentAvailabilityService {
    
    @AuraEnabled(cacheable=true)
    public static AvailabilityResponse checkSegmentAvailability(String trainId, Date journeyDate,
                                                               Integer fromOrder, Integer toOrder, 
                                                               String coachType) {
        try {
            // Get total seats in coach type
            Integer totalSeats = getTotalSeatsInCoach(trainId, coachType);
            
            // Count partially available seats (smart reallocation candidates)
            Integer partiallyAvailable = countPartiallyAvailableSeats(trainId, journeyDate, 
                                                                     fromOrder, toOrder, coachType);
            
            // Count completely free seats
            Integer completelyFree = countCompletelyFreeSeats(trainId, journeyDate, 
                                                            fromOrder, toOrder, coachType);
            
            Integer totalAvailable = partiallyAvailable + completelyFree;
            
            return new AvailabilityResponse(totalSeats, totalAvailable, partiallyAvailable, completelyFree);
            
        } catch (Exception e) {
            System.debug('Availability Check Error: ' + e.getMessage());
            return new AvailabilityResponse(0, 0, 0, 0, 'Error: ' + e.getMessage());
        }
    }
    
    private static Integer getTotalSeatsInCoach(String trainId, String coachType) {
        List<AggregateResult> results = [
            SELECT SUM(Total_Seats__c) totalSeats
            FROM Coach__c 
            WHERE Train__c = :trainId 
            AND Coach_Type__c = :coachType
        ];
        
        return results.isEmpty() ? 0 : (Integer)results[0].get('totalSeats');
    }
    
    private static Integer countPartiallyAvailableSeats(String trainId, Date journeyDate, 
                                                      Integer fromOrder, Integer toOrder, String coachType) {
        String countQuery = 
            'SELECT COUNT(Id) seatCount ' +
            'FROM Seat__c ' +
            'WHERE Coach__r.Train__c = :trainId ' +
            'AND Coach__r.Coach_Type__c = :coachType ' +
            'AND Id IN (' +
                'SELECT Seat__c FROM Seat_Segment_Allocation__c ' +
                'WHERE Journey_Date__c = :journeyDate ' +
                'AND To_Station_Order__c <= :fromOrder ' +
                'AND Allocation_Status__c = \'Confirmed\'' +
            ') ' +
            'AND Id NOT IN (' +
                'SELECT Seat__c FROM Seat_Segment_Allocation__c ' +
                'WHERE Journey_Date__c = :journeyDate ' +
                'AND From_Station_Order__c < :toOrder ' +
                'AND To_Station_Order__c > :fromOrder ' +
                'AND Allocation_Status__c = \'Confirmed\'' +
            ')';
        
        Map<String, Object> bindVars = new Map<String, Object>{
            'trainId' => trainId,
            'coachType' => coachType,
            'journeyDate' => journeyDate,
            'fromOrder' => fromOrder,
            'toOrder' => toOrder
        };
        
        List<AggregateResult> results = Database.queryWithBinds(countQuery, bindVars, AccessLevel.SYSTEM_MODE);
        return results.isEmpty() ? 0 : (Integer)results[0].get('seatCount');
    }
    
    private static Integer countCompletelyFreeSeats(String trainId, Date journeyDate, 
                                                  Integer fromOrder, Integer toOrder, String coachType) {
        String countQuery = 
            'SELECT COUNT(Id) seatCount ' +
            'FROM Seat__c ' +
            'WHERE Coach__r.Train__c = :trainId ' +
            'AND Coach__r.Coach_Type__c = :coachType ' +
            'AND Id NOT IN (' +
                'SELECT Seat__c FROM Seat_Segment_Allocation__c ' +
                'WHERE Journey_Date__c = :journeyDate ' +
                'AND From_Station_Order__c < :toOrder ' +
                'AND To_Station_Order__c > :fromOrder ' +
                'AND Allocation_Status__c = \'Confirmed\'' +
            ')';
        
        Map<String, Object> bindVars = new Map<String, Object>{
            'trainId' => trainId,
            'coachType' => coachType,
            'journeyDate' => journeyDate,
            'fromOrder' => fromOrder,
            'toOrder' => toOrder
        };
        
        List<AggregateResult> results = Database.queryWithBinds(countQuery, bindVars, AccessLevel.SYSTEM_MODE);
        return results.isEmpty() ? 0 : (Integer)results[0].get('seatCount');
    }
}