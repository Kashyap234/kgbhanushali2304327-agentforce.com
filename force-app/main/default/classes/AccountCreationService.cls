public class AccountCreationService {
    
    @InvocableMethod(label='Create Account' description='Creates a new account from bot input')
    public static List<AccountCreationResult> createAccount(List<AccountCreationRequest> requests) {
        List<AccountCreationResult> results = new List<AccountCreationResult>();
        List<Account> accountsToInsert = new List<Account>();
        
        // Process each request
        for (AccountCreationRequest request : requests) {
            try {
                // Create new account with provided details
                Account newAccount = new Account();
                newAccount.Name = request.accountName;
                
                // Set optional fields if provided
                if (String.isNotBlank(request.industry)) {
                    newAccount.Industry = request.industry;
                }
                if (String.isNotBlank(request.accountType)) {
                    newAccount.Type = request.accountType;
                }
                if (String.isNotBlank(request.phone)) {
                    newAccount.Phone = request.phone;
                }
                if (String.isNotBlank(request.website)) {
                    newAccount.Website = request.website;
                }
                if (String.isNotBlank(request.billingCity)) {
                    newAccount.BillingCity = request.billingCity;
                }
                if (String.isNotBlank(request.billingState)) {
                    newAccount.BillingState = request.billingState;
                }
                if (String.isNotBlank(request.billingCountry)) {
                    newAccount.BillingCountry = request.billingCountry;
                }
                
                accountsToInsert.add(newAccount);
                
            } catch (Exception e) {
                AccountCreationResult errorResult = new AccountCreationResult();
                errorResult.isSuccess = false;
                errorResult.errorMessage = 'Error preparing account: ' + e.getMessage();
                results.add(errorResult);
            }
        }
        
        // Insert accounts if any were prepared successfully
        if (!accountsToInsert.isEmpty()) {
            try {
                insert accountsToInsert;
                
                // Create success results
                for (Integer i = 0; i < accountsToInsert.size(); i++) {
                    AccountCreationResult successResult = new AccountCreationResult();
                    successResult.isSuccess = true;
                    successResult.accountId = accountsToInsert[i].Id;
                    successResult.accountName = accountsToInsert[i].Name;
                    successResult.message = 'Account created successfully: ' + accountsToInsert[i].Name;
                    results.add(successResult);
                }
                
            } catch (DmlException e) {
                // Handle DML errors
                for (Integer i = 0; i < requests.size(); i++) {
                    AccountCreationResult errorResult = new AccountCreationResult();
                    errorResult.isSuccess = false;
                    errorResult.errorMessage = 'Failed to create account: ' + e.getMessage();
                    results.add(errorResult);
                }
            }
        }
        
        return results;
    }
    
    // Input class for the invocable method
    public class AccountCreationRequest {
        @InvocableVariable(label='Account Name' description='Name of the account to create' required=true)
        public String accountName;
        
        @InvocableVariable(label='Industry' description='Industry of the account')
        public String industry;
        
        @InvocableVariable(label='Account Type' description='Type of account (Customer, Prospect, etc.)')
        public String accountType;
        
        @InvocableVariable(label='Phone' description='Phone number')
        public String phone;
        
        @InvocableVariable(label='Website' description='Website URL')
        public String website;
        
        @InvocableVariable(label='Billing City' description='Billing address city')
        public String billingCity;
        
        @InvocableVariable(label='Billing State' description='Billing address state')
        public String billingState;
        
        @InvocableVariable(label='Billing Country' description='Billing address country')
        public String billingCountry;
    }
    
    // Output class for the invocable method
    public class AccountCreationResult {
        @InvocableVariable(label='Success' description='Whether the account was created successfully')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Account ID' description='ID of the created account')
        public String accountId;
        
        @InvocableVariable(label='Account Name' description='Name of the created account')
        public String accountName;
        
        @InvocableVariable(label='Message' description='Success or error message')
        public String message;
        
        @InvocableVariable(label='Error Message' description='Error details if creation failed')
        public String errorMessage;
    }
}