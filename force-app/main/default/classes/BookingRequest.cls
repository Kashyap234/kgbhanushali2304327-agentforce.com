/**
 * Supporting classes for the allocation engine
 */
public class BookingRequest {
    @AuraEnabled public String trainId;
    @AuraEnabled public String coachType;
    @AuraEnabled public Date journeyDate;
    @AuraEnabled public Integer fromStationOrder;
    @AuraEnabled public Integer toStationOrder;
    @AuraEnabled public Integer passengerCount;
    @AuraEnabled public String bookingId;
    @AuraEnabled public String preferredBerthType;
    @AuraEnabled public List<String> passengerPreferences;
    
    // Constructor
    public BookingRequest(String tId, String cType, Date jDate, Integer fromOrder, 
                         Integer toOrder, Integer pCount, String bId) {
        this.trainId = tId;
        this.coachType = cType;
        this.journeyDate = jDate;
        this.fromStationOrder = fromOrder;
        this.toStationOrder = toOrder;
        this.passengerCount = pCount;
        this.bookingId = bId;
    }
}