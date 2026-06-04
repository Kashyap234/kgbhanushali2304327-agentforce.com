/**
 * SeatAllocationResult.cls - Result wrapper for allocation data
 */
public class SeatAllocationResult {
    @AuraEnabled public Boolean isSuccess;
    @AuraEnabled public String message;
    @AuraEnabled public List<Seat_Segment_Allocation__c> allocations;
    @AuraEnabled public Integer confirmedCount;
    @AuraEnabled public Integer waitlistedCount;
    @AuraEnabled public String allocationDetails;
    
    public SeatAllocationResult(Boolean success, String msg, List<Seat_Segment_Allocation__c> allocs) {
        this.isSuccess = success;
        this.message = msg;
        this.allocations = allocs;
        this.confirmedCount = allocs != null ? allocs.size() : 0;
        this.waitlistedCount = 0;
        this.allocationDetails = msg;
    }
}