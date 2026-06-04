/**
 * TrainSearchController.cls - Enhanced with fully dynamic data handling
 */
public with sharing class TrainSearchController {
    
    @AuraEnabled(cacheable=true)
    public static List<TrainSearchResult> searchTrains(String fromStation, String toStation, Date journeyDate) {
        try {
            List<TrainSearchResult> results = new List<TrainSearchResult>();
            
            // Query trains with routes containing both stations
            String query = 
                'SELECT Id, Name, Train_Number__c, Train_Type__c, ' +
                '       (SELECT Id, Station__c, Station__r.Name, Station__r.Station_Code__c, ' +
                '               Stop_Number__c, Arrival_Time__c, Departure_Time__c, ' +
                '               Distance_from_Source__c, Platform_Number__c ' +
                '        FROM Routes__r ' +
                '        WHERE Station__r.Station_Code__c IN (:fromStation, :toStation) ' +
                '        ORDER BY Stop_Number__c) ' +
                'FROM Train__c ' +
                'WHERE Id IN (' +
                '    SELECT Train__c FROM Route__c ' +
                '    WHERE Station__r.Station_Code__c = :fromStation' +
                ') ' +
                'AND Id IN (' +
                '    SELECT Train__c FROM Route__c ' +
                '    WHERE Station__r.Station_Code__c = :toStation' +
                ') ' +
                'AND Days_of_Operation__c INCLUDES :dayOfWeek ' +
                'ORDER BY Train_Number__c';
            
            String dayOfWeek = getDayOfWeek(journeyDate);
            Map<String, Object> bindVars = new Map<String, Object>{
                'fromStation' => fromStation,
                'toStation' => toStation,
                'dayOfWeek' => dayOfWeek
            };
            
            List<Train__c> trains = Database.queryWithBinds(query, bindVars, AccessLevel.SYSTEM_MODE);
            
            for (Train__c train : trains) {
                TrainSearchResult result = processTrainRoutes(train, fromStation, toStation, journeyDate);
                if (result != null) {
                    results.add(result);
                }
            }
            
            return results;
            
        } catch (Exception e) {
            System.debug('Search Error: ' + e.getMessage());
            throw new AuraHandledException('Failed to search trains: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static TrainAvailabilityData getTrainWithAvailability(String trainId, Date journeyDate, 
                                                               String fromStation, String toStation, 
                                                               String coachType) {
        try {
            // Get train details with route info
            Train__c train = [
                SELECT Id, Name, Train_Number__c, Train_Type__c,
                       (SELECT Station__r.Station_Code__c, Stop_Number__c, 
                               Arrival_Time__c, Departure_Time__c
                        FROM Routes__r 
                        WHERE Station__r.Station_Code__c IN (:fromStation, :toStation)
                        ORDER BY Stop_Number__c)
                FROM Train__c 
                WHERE Id = :trainId
                LIMIT 1
            ];
            
            if (train.Routes__r.size() != 2) {
                throw new AuraHandledException('Invalid route configuration for train');
            }
            
            Route__c fromRoute = train.Routes__r[0];
            Route__c toRoute = train.Routes__r[1];
            
            // Get availability data
            AvailabilityResponse availability = SegmentAvailabilityService.checkSegmentAvailability(
                trainId, journeyDate, 
                Integer.valueOf(fromRoute.Stop_Number__c),
                Integer.valueOf(toRoute.Stop_Number__c),
                coachType
            );
            
            return new TrainAvailabilityData(train, fromRoute, toRoute, availability, journeyDate);
            
        } catch (Exception e) {
            System.debug('Train availability error: ' + e.getMessage());
            throw new AuraHandledException('Failed to get train availability: ' + e.getMessage());
        }
    }
    
    private static TrainSearchResult processTrainRoutes(Train__c train, String fromStation, 
                                                       String toStation, Date journeyDate) {
        Route__c fromRoute = null;
        Route__c toRoute = null;
        
        // Find the from and to station routes
        for (Route__c route : train.Routes__r) {
            if (route.Station__r.Station_Code__c == fromStation) {
                fromRoute = route;
            } else if (route.Station__r.Station_Code__c == toStation) {
                toRoute = route;
            }
        }
        
        // Validate route sequence (from station should come before to station)
        if (fromRoute == null || toRoute == null || fromRoute.Stop_Number__c >= toRoute.Stop_Number__c) {
            return null;
        }
        
        // Create search result with enhanced data
        TrainSearchResult result = new TrainSearchResult();
        result.trainId = train.Id;
        result.trainName = train.Name;
        result.trainNumber = String.valueOf(train.Train_Number__c);
        result.trainType = train.Train_Type__c;
        result.fromStation = fromRoute.Station__r.Name;
        result.toStation = toRoute.Station__r.Name;
        result.fromStationCode = fromRoute.Station__r.Station_Code__c;
        result.toStationCode = toRoute.Station__r.Station_Code__c;
        result.fromStationOrder = Integer.valueOf(fromRoute.Stop_Number__c);
        result.toStationOrder = Integer.valueOf(toRoute.Stop_Number__c);
        result.departureTime = formatTime(fromRoute.Departure_Time__c);
        result.arrivalTime = formatTime(toRoute.Arrival_Time__c);
        result.duration = calculateDuration(fromRoute.Departure_Time__c, toRoute.Arrival_Time__c);
        result.distance = calculateDistance(fromRoute, toRoute);
        result.journeyDate = journeyDate;
        
        // Get available coach types for this train
        result.availableCoachTypes = getAvailableCoachTypes(train.Id);
        
        return result;
    }
    
    private static List<String> getAvailableCoachTypes(String trainId) {
        List<String> coachTypes = new List<String>();
        
        for (AggregateResult result : [
            SELECT Coach_Type__c 
            FROM Coach__c 
            WHERE Train__c = :trainId 
            GROUP BY Coach_Type__c
            ORDER BY Coach_Type__c
        ]) {
            coachTypes.add((String)result.get('Coach_Type__c'));
        }
        
        return coachTypes;
    }
    
    private static Decimal calculateDistance(Route__c fromRoute, Route__c toRoute) {
        if (fromRoute.Distance_from_Source__c != null && toRoute.Distance_from_Source__c != null) {
            return toRoute.Distance_from_Source__c - fromRoute.Distance_from_Source__c;
        }
        return null;
    }
    
    private static String getDayOfWeek(Date journeyDate) {
        Datetime dt = Datetime.newInstance(journeyDate, Time.newInstance(0, 0, 0, 0));
        String dayName = dt.format('E');
        
        // Convert to format used in Days_of_Operation__c picklist
        Map<String, String> dayMap = new Map<String, String>{
            'Mon' => 'Monday',
            'Tue' => 'Tuesday', 
            'Wed' => 'Wednesday',
            'Thu' => 'Thursday',
            'Fri' => 'Friday',
            'Sat' => 'Saturday',
            'Sun' => 'Sunday'
        };
        
        return dayMap.get(dayName);
    }
    
    private static String formatTime(Time t) {
        if (t == null) return '';
        
        Integer hour = t.hour();
        Integer minute = t.minute();
        String period = hour >= 12 ? 'PM' : 'AM';
        
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        
        return String.format('{0}:{1} {2}', new Object[]{
            hour, 
            minute < 10 ? '0' + minute : String.valueOf(minute),
            period
        });
    }
    
    private static String calculateDuration(Time departure, Time arrival) {
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
        
        return hours + 'h ' + minutes + 'm';
    }
    
    @AuraEnabled(cacheable=true)
    public static List<StationOption> getStationOptions() {
        List<StationOption> options = new List<StationOption>();
        
        // Get stations that are actually part of train routes
        for (Station__c station : [
            SELECT Id, Name, Station_Code__c, City__c, State__c 
            FROM Station__c 
            WHERE Id IN (SELECT Station__c FROM Route__c)
            ORDER BY Name 
            LIMIT 500
        ]) {
            options.add(new StationOption(
                station.Station_Code__c,
                station.Name + ' (' + station.Station_Code__c + ')',
                station.City__c,
                station.State__c
            ));
        }
        
        return options;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<CoachTypeOption> getCoachTypeOptions() {
        List<CoachTypeOption> options = new List<CoachTypeOption>();
        
        // Get available coach types from schema
        Schema.DescribeFieldResult fieldResult = Coach__c.Coach_Type__c.getDescribe();
        List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
        
        for (Schema.PicklistEntry entry : picklistEntries) {
            if (entry.isActive()) {
                options.add(new CoachTypeOption(
                    entry.getValue(),
                    entry.getLabel(),
                    getCoachTypeDescription(entry.getValue())
                ));
            }
        }
        
        return options;
    }
    
    private static String getCoachTypeDescription(String coachType) {
        Map<String, String> descriptions = new Map<String, String>{
            '1A' => 'First AC - Private cabins with meals',
            '2A' => 'Second AC - 4 berth compartments with AC',
            '3A' => 'Third AC - 6 berth compartments with AC',
            'SL' => 'Sleeper - Non-AC sleeping berths',
            'CC' => 'Chair Car - AC seating with push-back seats',
            '2S' => 'Second Sitting - Non-AC reserved seating'
        };
        
        return descriptions.get(coachType) != null ? descriptions.get(coachType) : coachType;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<PopularRoute> getPopularRoutes() {
        List<PopularRoute> routes = new List<PopularRoute>();
        
        // Get most frequently traveled routes from booking data
        for (AggregateResult result : [
            SELECT Source_Station__r.Station_Code__c fromCode,
                   Source_Station__r.Name fromName,
                   Destination_Station__r.Station_Code__c toCode,
                   Destination_Station__r.Name toName,
                   COUNT(Id) bookingCount
            FROM Booking__c 
            WHERE CreatedDate = LAST_N_DAYS:30
            AND Booking_Status__c != 'Cancelled'
            GROUP BY Source_Station__r.Station_Code__c, Source_Station__r.Name,
                     Destination_Station__r.Station_Code__c, Destination_Station__r.Name
            ORDER BY COUNT(Id) DESC
            LIMIT 10
        ]) {
            routes.add(new PopularRoute(
                (String)result.get('fromCode'),
                (String)result.get('fromName'),
                (String)result.get('toCode'),
                (String)result.get('toName'),
                (Integer)result.get('bookingCount')
            ));
        }
        
        return routes;
    }
    
    // Enhanced wrapper classes
    public class TrainSearchResult {
        @AuraEnabled public String trainId;
        @AuraEnabled public String trainName;
        @AuraEnabled public String trainNumber;
        @AuraEnabled public String trainType;
        @AuraEnabled public String fromStation;
        @AuraEnabled public String toStation;
        @AuraEnabled public String fromStationCode;
        @AuraEnabled public String toStationCode;
        @AuraEnabled public Integer fromStationOrder;
        @AuraEnabled public Integer toStationOrder;
        @AuraEnabled public String departureTime;
        @AuraEnabled public String arrivalTime;
        @AuraEnabled public String duration;
        @AuraEnabled public Decimal distance;
        @AuraEnabled public Date journeyDate;
        @AuraEnabled public List<String> availableCoachTypes;
    }
    
    public class StationOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        
        public StationOption(String v, String l, String c, String s) {
            this.value = v;
            this.label = l;
            this.city = c;
            this.state = s;
        }
    }
    
    public class CoachTypeOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        @AuraEnabled public String description;
        
        public CoachTypeOption(String v, String l, String d) {
            this.value = v;
            this.label = l;
            this.description = d;
        }
    }
    
    public class PopularRoute {
        @AuraEnabled public String fromCode;
        @AuraEnabled public String fromName;
        @AuraEnabled public String toCode;
        @AuraEnabled public String toName;
        @AuraEnabled public Integer bookingCount;
        
        public PopularRoute(String fc, String fn, String tc, String tn, Integer bc) {
            this.fromCode = fc;
            this.fromName = fn;
            this.toCode = tc;
            this.toName = tn;
            this.bookingCount = bc;
        }
    }
    
    public class TrainAvailabilityData {
        @AuraEnabled public String trainId;
        @AuraEnabled public String trainName;
        @AuraEnabled public String trainNumber;
        @AuraEnabled public String trainType;
        @AuraEnabled public String departureTime;
        @AuraEnabled public String arrivalTime;
        @AuraEnabled public String duration;
        @AuraEnabled public Integer fromStationOrder;
        @AuraEnabled public Integer toStationOrder;
        @AuraEnabled public AvailabilityResponse availability;
        @AuraEnabled public Date journeyDate;
        
        public TrainAvailabilityData(Train__c train, Route__c fromRoute, Route__c toRoute, 
                                   AvailabilityResponse avail, Date jDate) {
            this.trainId = train.Id;
            this.trainName = train.Name;
            this.trainNumber = String.valueOf(train.Train_Number__c);
            this.trainType = train.Train_Type__c;
            this.departureTime = formatTime(fromRoute.Departure_Time__c);
            this.arrivalTime = formatTime(toRoute.Arrival_Time__c);
            this.duration = calculateDuration(fromRoute.Departure_Time__c, toRoute.Arrival_Time__c);
            this.fromStationOrder = Integer.valueOf(fromRoute.Stop_Number__c);
            this.toStationOrder = Integer.valueOf(toRoute.Stop_Number__c);
            this.availability = avail;
            this.journeyDate = jDate;
        }
        
        private String formatTime(Time t) {
            return TrainSearchController.formatTime(t);
        }
        
        private String calculateDuration(Time departure, Time arrival) {
            return TrainSearchController.calculateDuration(departure, arrival);
        }
    }
}