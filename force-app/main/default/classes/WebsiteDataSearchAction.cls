public class WebsiteDataSearchAction {
    
    /**
     * Invocable method to search website data for Agentforce
     * This can be called from Flows or directly by Agentforce
     */
    @InvocableMethod(
        label='Search Website Data' 
        description='Search W3Schools tutorial data by keyword, category, or topic'
        category='Agentforce Actions'
    )
    public static List<SearchResult> searchWebsiteData(List<SearchRequest> requests) {
        List<SearchResult> results = new List<SearchResult>();
        
        for (SearchRequest request : requests) {
            SearchResult result = new SearchResult();
            result.records = performSearch(request);
            result.totalFound = result.records.size();
            result.searchQuery = request.searchKeyword;
            results.add(result);
        }
        
        return results;
    }
    
    /**
     * Perform the actual search logic
     */
    private static List<Website_Data__c> performSearch(SearchRequest request) {
        String searchKeyword = request.searchKeyword;
        String category = request.category;
        Integer maxResults = request.maxResults != null ? request.maxResults : 10;
        
        // Build dynamic SOQL query
        String query = 'SELECT Id, Title__c, URL__c, Category__c, Content__c, Code_Examples__c, Word_Count__c, Scraped_Date__c FROM Website_Data__c WHERE ';
        List<String> conditions = new List<String>();
        
        // Add keyword search condition
        if (String.isNotBlank(searchKeyword)) {
            String searchPattern = '%' + String.escapeSingleQuotes(searchKeyword) + '%';
            conditions.add('(Title__c LIKE :searchPattern OR Content__c LIKE :searchPattern)');
        }
        
        // Add category filter
        if (String.isNotBlank(category)) {
            conditions.add('Category__c = :category');
        }
        
        // If no conditions, return all
        if (conditions.isEmpty()) {
            query = 'SELECT Id, Title__c, URL__c, Category__c, Content__c, Code_Examples__c, Word_Count__c, Scraped_Date__c FROM Website_Data__c ORDER BY Title__c LIMIT :maxResults';
        } else {
            query += String.join(conditions, ' AND ') + ' ORDER BY Title__c LIMIT :maxResults';
        }
        
        return Database.query(query);
    }
    
    /**
     * Get content by specific URL
     */
    @AuraEnabled(cacheable=true)
    public static Website_Data__c getContentByUrl(String url) {
        try {
            List<Website_Data__c> records = [
                SELECT Id, Title__c, URL__c, Category__c, Content__c, 
                       Code_Examples__c, Word_Count__c, Scraped_Date__c 
                FROM Website_Data__c 
                WHERE URL__c = :url 
                LIMIT 1
            ];
            return records.isEmpty() ? null : records[0];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching content: ' + e.getMessage());
        }
    }
    
    /**
     * Get all available categories
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getAvailableCategories() {
        List<String> categories = new List<String>();
        
        AggregateResult[] results = [
            SELECT Category__c 
            FROM Website_Data__c 
            GROUP BY Category__c 
            ORDER BY Category__c
        ];
        
        for (AggregateResult ar : results) {
            categories.add(String.valueOf(ar.get('Category__c')));
        }
        
        return categories;
    }
    
    /**
     * Get summary statistics
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getCategoryStats() {
        Map<String, Integer> stats = new Map<String, Integer>();
        
        AggregateResult[] results = [
            SELECT Category__c, COUNT(Id) recordCount 
            FROM Website_Data__c 
            GROUP BY Category__c
        ];
        
        for (AggregateResult ar : results) {
            String category = String.valueOf(ar.get('Category__c'));
            Integer count = Integer.valueOf(ar.get('recordCount'));
            stats.put(category, count);
        }
        
        return stats;
    }
    
    // Wrapper classes for invocable method
    public class SearchRequest {
        @InvocableVariable(label='Search Keyword' description='Keyword to search in title and content' required=false)
        public String searchKeyword;
        
        @InvocableVariable(label='Category' description='Filter by category (e.g., Python, HTML, CSS)' required=false)
        public String category;
        
        @InvocableVariable(label='Max Results' description='Maximum number of results to return' required=false)
        public Integer maxResults;
    }
    
    public class SearchResult {
        @InvocableVariable(label='Website Data Records')
        public List<Website_Data__c> records;
        
        @InvocableVariable(label='Total Found')
        public Integer totalFound;
        
        @InvocableVariable(label='Search Query')
        public String searchQuery;
    }
}