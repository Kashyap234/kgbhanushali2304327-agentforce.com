/**
 * AvailabilityResponse.cls - Response wrapper for availability data
 */
public class AvailabilityResponse {
    @AuraEnabled public Integer totalSeats;
    @AuraEnabled public Integer totalAvailable;
    @AuraEnabled public Integer partiallyAvailable;
    @AuraEnabled public Integer completelyFree;
    @AuraEnabled public Integer occupied;
    @AuraEnabled public Decimal availabilityPercentage;
    @AuraEnabled public String utilizationMessage;
    @AuraEnabled public String status;
    @AuraEnabled public Boolean hasAvailability;
    @AuraEnabled public String errorMessage;
    
    public AvailabilityResponse(Integer total, Integer available, Integer partial, Integer fresh) {
        this.totalSeats = total;
        this.totalAvailable = available;
        this.partiallyAvailable = partial;
        this.completelyFree = fresh;
        this.occupied = total - available;
        this.availabilityPercentage = total > 0 ? (Decimal.valueOf(available) / total) * 100 : 0;
        this.hasAvailability = available > 0;
        this.status = available > 0 ? 'AVAILABLE' : 'WAITING_LIST';
        this.utilizationMessage = generateUtilizationMessage();
    }
    
    // Error constructor
    public AvailabilityResponse(Integer total, Integer available, Integer partial, Integer fresh, String error) {
        this(total, available, partial, fresh);
        this.errorMessage = error;
        this.status = 'ERROR';
    }
    
    private String generateUtilizationMessage() {
        if (partiallyAvailable > 0 && completelyFree > 0) {
            return partiallyAvailable + ' seats through smart reallocation + ' + completelyFree + ' fresh seats available';
        } else if (partiallyAvailable > 0) {
            return partiallyAvailable + ' seats available through smart reallocation';
        } else if (completelyFree > 0) {
            return completelyFree + ' fresh seats available';
        } else {
            return 'No seats available - join waiting list';
        }
    }
}