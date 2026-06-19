public class GetContactDetailsAction {
    
    // Defines the Input for the Agent
    public class ActionInput {
        @InvocableVariable(required=true description='The email address of the contact to fetch.')
        public String emailAddress;
    }

    // Defines the Output for the Agent
    public class ActionOutput {
        @InvocableVariable(description='The nested contact details object to be displayed via Custom Lightning Type.')
        public ContactDetailsWrapper contactDetails;
    }

    @InvocableMethod(label='Get Contact Details by Email' description='Searches Salesforce for a contact using their email address and returns the details.')
    public static List<ActionOutput> getContactByEmail(List<ActionInput> inputs) {
        List<ActionOutput> outputs = new List<ActionOutput>();
        
        for(ActionInput input : inputs) {
            ActionOutput output = new ActionOutput();
            
            // Query the contact matching the email
            List<Contact> contacts = [
                SELECT Id, Name, Email, Phone, Title 
                FROM Contact 
                WHERE Email = :input.emailAddress 
                LIMIT 1
            ];
            
            if(!contacts.isEmpty()) {
                output.contactDetails = new ContactDetailsWrapper(contacts[0]);
            }
            outputs.add(output);
        }
        
        return outputs;
    }
}