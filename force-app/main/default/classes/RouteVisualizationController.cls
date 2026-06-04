/**
 * RouteVisualizationController.cls - Enhanced with fully dynamic route and timing data
 */
public with sharing class RouteVisualizationController {
    
    @AuraEnabled(cacheable=true)
    public static RouteVisualizationData getTrainRoute(String trainId) {
        try {
            // Get train details with complete route information
            Train__c train = [
                SELECT Id, Name, Train_Number__c, Train_Type__c, Days_of_Operation__c,
                       Source_Station__r.Name, Source_Station__r.Station_Code__c,
                       Destination_Station__r.Name, Destination_Station__r.Station_Code__c,
                       Total_Distance__c, Average_Speed__c
                FROM Train__c 
                WHERE Id = :trainId
                LIMIT 1
            ];
            
            List<RouteStation> routeStations = new List<RouteStation>();
            
            List<Route__c> routes = [
                SELECT Id, Station__r.Id, Station__r.Name, Station__r.Station_Code__c,
                       Station__r.City__c, Station__r.State__c, Station__r.Zone__c,
                       Stop_Number__c, Arrival_Time__c, Departure_Time__c,
                       Distance_from_Source__c, Platform_Number__c, Halt_Duration_Minutes__c,
                       Is_Technical_Stop__c, Has_Pantry_Car__c
                FROM Route__c 
                WHERE Train__c = :trainId
                ORDER BY Stop_Number__c
            ];
            
            for (Integer i = 0; i < routes.size(); i++) {
                Route__c route = routes[i];
                RouteStation station = new RouteStation();
                station.id = route.Id;
                station.stationId = route.Station__r.Id;
                station.stationName = route.Station__r.Name;
                station.stationCode = route.Station__r.Station_Code__c;
                station.city = route.Station__r.City__c;
                station.state = route.Station__r.State__c;
                station.zone = route.Station__r.Zone__c;
                station.stopNumber = Integer.valueOf(route.Stop_Number__c);
                station.arrivalTime = formatTime(route.Arrival_Time__c);
                station.departureTime = formatTime(route.Departure_Time__c);
                station.distanceFromSource = route.Distance_from_Source__c;
                station.platformNumber = route.Platform_Number__c;
                station.haltDuration = Integer.valueOf(route.Halt_Duration_Minutes__c);
                station.isTechnicalStop = route.Is_Technical_Stop__c;
                station.hasPantryCar = route.Has_Pantry_Car__c;
                station.isFirst = (i == 0);
                station.isLast = (i == routes.size() - 1);
                
                // Calculate running time and delay information
                if (i > 0) {
                    Route__c previousRoute = routes[i-1];
                    station.runningTime = calculateRunningTime(
                        previousRoute.Departure_Time__c, 
                        route.Arrival_Time__c
                    );
                    station.distanceFromPrevious = route.Distance_from_Source__c - previousRoute.Distance_from_Source__c;
                }
                
                routeStations.add(station);
            }
            
            return new RouteVisualizationData(train, routeStations);
            
        } catch (Exception e) {
            System.debug('Route loading error: ' + e.getMessage());
            throw new AuraHandledException('Failed to load route data: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<SegmentUtilization> getSegmentUtilization(String trainId, Date journeyDate) {
        try {
            List<SegmentUtilization> utilizationData = new List<SegmentUtilization>();
            
            // Get all route segments for the train
            List<Route__c> routes = [
                SELECT Stop_Number__c, Station__r.Station_Code__c, Station__r.Name,
                       Arrival_Time__c, Departure_Time__c
                FROM Route__c 
                WHERE Train__c = :trainId
                ORDER BY Stop_Number__c
            ];
            
            // Get total seats per coach type with pricing information
            Map<String, CoachTypeInfo> coachTypeData = getCoachTypeData(trainId);
            
            // Calculate utilization for each segment
            for (Integer i = 0; i < routes.size() - 1; i++) {
                Route__c fromRoute = routes[i];
                Route__c toRoute = routes[i + 1];
                
                for (String coachType : coachTypeData.keySet()) {
                    CoachTypeInfo coachInfo = coachTypeData.get(coachType);
                    
                    SegmentOccupancyData occupancyData = getSegmentOccupancyData(
                        trainId, journeyDate, 
                        Integer.valueOf(fromRoute.Stop_Number__c),
                        Integer.valueOf(toRoute.Stop_Number__c),
                        coachType
                    );
                    
                    SegmentUtilization utilization = new SegmentUtilization();
                    utilization.fromStationCode = fromRoute.Station__r.Station_Code__c;
                    utilization.fromStationName = fromRoute.Station__r.Name;
                    utilization.toStationCode = toRoute.Station__r.Station_Code__c;
                    utilization.toStationName = toRoute.Station__r.Name;
                    utilization.fromOrder = Integer.valueOf(fromRoute.Stop_Number__c);
                    utilization.toOrder = Integer.valueOf(toRoute.Stop_Number__c);
                    utilization.coachType = coachType;
                    utilization.totalSeats = coachInfo.totalSeats;
                    utilization.totalCoaches = coachInfo.totalCoaches;
                    utilization.occupiedSeats = occupancyData.occupiedSeats;
                    utilization.confirmedSeats = occupancyData.confirmedSeats;
                    utilization.waitlistedSeats = occupancyData.waitlistedSeats;
                    utilization.availableSeats = coachInfo.totalSeats - occupancyData.occupiedSeats;
                    utilization.occupancyPercentage = coachInfo.totalSeats > 0 ? 
                        Integer.valueOf((occupancyData.occupiedSeats * 100.0) / coachInfo.totalSeats) : 0;
                    utilization.departureTime = formatTime(fromRoute.Departure_Time__c);
                    utilization.arrivalTime = formatTime(toRoute.Arrival_Time__c);
                    utilization.segmentDuration = calculateRunningTime(fromRoute.Departure_Time__c, toRoute.Arrival_Time__c);
                    
                    utilizationData.add(utilization);
                }
            }
            
            return utilizationData;
            
        } catch (Exception e) {
            System.debug('Utilization loading error: ' + e.getMessage());
            throw new AuraHandledException('Failed to load utilization data: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<LiveTrainStatus> getLiveTrainStatus(String trainId, Date journeyDate) {
        try {
            // Get current train status and predictions
            List<LiveTrainStatus> statusList = new List<LiveTrainStatus>();
            
            List<Route__c> routes = [
                SELECT Station__r.Station_Code__c, Station__r.Name, Stop_Number__c,
                       Arrival_Time__c, Departure_Time__c, Platform_Number__c
                FROM Route__c 
                WHERE Train__c = :trainId
                ORDER BY Stop_Number__c
            ];
            
            // This would typically integrate with real-time tracking systems
            // For now, we'll simulate based on scheduled times with some realistic delays
            Integer accumulatedDelay = 0;
            Datetime currentTime = Datetime.now();
            
            for (Route__c route : routes) {
                LiveTrainStatus status = new LiveTrainStatus();
                status.stationCode = route.Station__r.Station_Code__c;
                status.stationName = route.Station__r.Name;
                status.stopNumber = Integer.valueOf(route.Stop_Number__c);
                status.scheduledArrival = formatTime(route.Arrival_Time__c);
                status.scheduledDeparture = formatTime(route.Departure_Time__c);
                status.platform = route.Platform_Number__c;
                
                // Simulate realistic status based on current time and journey progress
                Datetime stationDateTime = Datetime.newInstance(journeyDate, route.Arrival_Time__c);
                
                if (currentTime > stationDateTime.addMinutes(accumulatedDelay + 30)) {
                    status.status = 'Departed';
                    status.actualTime = formatDateTime(stationDateTime.addMinutes(accumulatedDelay));
                    status.delay = accumulatedDelay;
                    accumulatedDelay += Integer.valueOf(Math.random() * 10); // Accumulate small delays
                } else if (currentTime > stationDateTime.addMinutes(accumulatedDelay - 5)) {
                    status.status = 'At Platform';
                    status.actualTime = formatDateTime(currentTime);
                    status.delay = accumulatedDelay;
                } else {
                    status.status = 'Expected';
                    status.expectedTime = formatDateTime(stationDateTime.addMinutes(accumulatedDelay));
                    status.delay = accumulatedDelay;
                }
                
                statusList.add(status);
            }
            
            return statusList;
            
        } catch (Exception e) {
            System.debug('Live status error: ' + e.getMessage());
            throw new AuraHandledException('Failed to load live status: ' + e.getMessage());
        }
    }
    
    private static Map<String, CoachTypeInfo> getCoachTypeData(String trainId) {
        Map<String, CoachTypeInfo> coachData = new Map<String, CoachTypeInfo>();
        
        for (AggregateResult result : [
            SELECT Coach_Type__c, SUM(Total_Seats__c) totalSeats, COUNT(Id) totalCoaches
            FROM Coach__c 
            WHERE Train__c = :trainId
            GROUP BY Coach_Type__c
        ]) {
            coachData.put(
                (String)result.get('Coach_Type__c'),
                new CoachTypeInfo(
                    Integer.valueOf(result.get('totalSeats')),
                    Integer.valueOf(result.get('totalCoaches'))
                )
            );
        }
        
        return coachData;
    }
    
    private static SegmentOccupancyData getSegmentOccupancyData(String trainId, Date journeyDate,
                                                               Integer fromOrder, Integer toOrder, 
                                                               String coachType) {
        // Count confirmed seats
        Integer confirmedSeats = [
            SELECT COUNT()
            FROM Seat_Segment_Allocation__c 
            WHERE Seat__r.Coach__r.Train__c = :trainId
            AND Seat__r.Coach__r.Coach_Type__c = :coachType
            AND Journey_Date__c = :journeyDate
            AND From_Station_Order__c < :toOrder
            AND To_Station_Order__c > :fromOrder
            AND Allocation_Status__c = 'Confirmed'
        ];
        
        // Count waitlisted requests
        Integer waitlistedSeats = [
            SELECT COUNT()
            FROM Seat_Segment_Allocation__c 
            WHERE Seat__r.Coach__r.Train__c = :trainId
            AND Seat__r.Coach__r.Coach_Type__c = :coachType
            AND Journey_Date__c = :journeyDate
            AND From_Station_Order__c < :toOrder
            AND To_Station_Order__c > :fromOrder
            AND Allocation_Status__c = 'Waitlisted'
        ];
        
        return new SegmentOccupancyData(confirmedSeats, waitlistedSeats);
    }
    
    private static String formatTime(Time timeValue) {
        if (timeValue == null) return null;
        
        Integer hour = timeValue.hour();
        Integer minute = timeValue.minute();
        String period = hour >= 12 ? 'PM' : 'AM';
        
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        
        return String.format('{0}:{1} {2}', new Object[]{
            hour,
            minute < 10 ? '0' + minute : String.valueOf(minute),
            period
        });
    }
    
    private static String formatDateTime(Datetime dt) {
        return dt.format('MMM dd, HH:mm');
    }
    
    private static String calculateRunningTime(Time departure, Time arrival) {
        if (departure == null || arrival == null) return '';
        
        Integer departureMinutes = departure.hour() * 60 + departure.minute();
        Integer arrivalMinutes = arrival.hour() * 60 + arrival.minute();
        
        // Handle next day arrival
        if (arrivalMinutes < departureMinutes) {
            arrivalMinutes += 24 * 60;
        }
        
        Integer durationMinutes = arrivalMinutes - departureMinutes;
        Integer hours = durationMinutes / 60;
        Integer minutes = Math.mod(durationMinutes, 60);
        
        return hours + 'h ' + (minutes > 0 ? minutes + 'm' : '');
    }
    
    // Enhanced Wrapper Classes
    public class RouteVisualizationData {
        @AuraEnabled public TrainInfo trainInfo;
        @AuraEnabled public List<RouteStation> routeStations;
        
        public RouteVisualizationData(Train__c train, List<RouteStation> stations) {
            this.trainInfo = new TrainInfo(train);
            this.routeStations = stations;
        }
    }
    
    public class TrainInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String trainNumber;
        @AuraEnabled public String trainType;
        @AuraEnabled public String sourceStation;
        @AuraEnabled public String destinationStation;
        @AuraEnabled public Decimal totalDistance;
        @AuraEnabled public Decimal averageSpeed;
        @AuraEnabled public List<String> daysOfOperation;
        
        public TrainInfo(Train__c train) {
            this.id = train.Id;
            this.name = train.Name;
            this.trainNumber = String.valueOf(train.Train_Number__c);
            this.trainType = train.Train_Type__c;
            this.sourceStation = train.Source_Station__r.Name + ' (' + train.Source_Station__r.Station_Code__c + ')';
            this.destinationStation = train.Destination_Station__r.Name + ' (' + train.Destination_Station__r.Station_Code__c + ')';
            this.totalDistance = train.Total_Distance__c;
            this.averageSpeed = train.Average_Speed__c;
            this.daysOfOperation = train.Days_of_Operation__c != null ? 
                train.Days_of_Operation__c.split(';') : new List<String>();
        }
    }
    
    public class RouteStation {
        @AuraEnabled public String id;
        @AuraEnabled public String stationId;
        @AuraEnabled public String stationName;
        @AuraEnabled public String stationCode;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String zone;
        @AuraEnabled public Integer stopNumber;
        @AuraEnabled public String arrivalTime;
        @AuraEnabled public String departureTime;
        @AuraEnabled public Decimal distanceFromSource;
        @AuraEnabled public Decimal distanceFromPrevious;
        @AuraEnabled public String platformNumber;
        @AuraEnabled public Integer haltDuration;
        @AuraEnabled public String runningTime;
        @AuraEnabled public Boolean isTechnicalStop;
        @AuraEnabled public Boolean hasPantryCar;
        @AuraEnabled public Boolean isFirst;
        @AuraEnabled public Boolean isLast;
    }
    
    public class SegmentUtilization {
        @AuraEnabled public String fromStationCode;
        @AuraEnabled public String fromStationName;
        @AuraEnabled public String toStationCode;
        @AuraEnabled public String toStationName;
        @AuraEnabled public Integer fromOrder;
        @AuraEnabled public Integer toOrder;
        @AuraEnabled public String coachType;
        @AuraEnabled public Integer totalSeats;
        @AuraEnabled public Integer totalCoaches;
        @AuraEnabled public Integer occupiedSeats;
        @AuraEnabled public Integer confirmedSeats;
        @AuraEnabled public Integer waitlistedSeats;
        @AuraEnabled public Integer availableSeats;
        @AuraEnabled public Integer occupancyPercentage;
        @AuraEnabled public String departureTime;
        @AuraEnabled public String arrivalTime;
        @AuraEnabled public String segmentDuration;
    }
    
    public class LiveTrainStatus {
        @AuraEnabled public String stationCode;
        @AuraEnabled public String stationName;
        @AuraEnabled public Integer stopNumber;
        @AuraEnabled public String scheduledArrival;
        @AuraEnabled public String scheduledDeparture;
        @AuraEnabled public String actualTime;
        @AuraEnabled public String expectedTime;
        @AuraEnabled public String platform;
        @AuraEnabled public String status; // Expected, At Platform, Departed, Cancelled
        @AuraEnabled public Integer delay; // in minutes
    }
    
    // Helper classes
    private class CoachTypeInfo {
        public Integer totalSeats;
        public Integer totalCoaches;
        
        public CoachTypeInfo(Integer seats, Integer coaches) {
            this.totalSeats = seats;
            this.totalCoaches = coaches;
        }
    }
    
    private class SegmentOccupancyData {
        public Integer confirmedSeats;
        public Integer waitlistedSeats;
        public Integer occupiedSeats;
        
        public SegmentOccupancyData(Integer confirmed, Integer waitlisted) {
            this.confirmedSeats = confirmed;
            this.waitlistedSeats = waitlisted;
            this.occupiedSeats = confirmed; // Only count confirmed for occupancy
        }
    }
}