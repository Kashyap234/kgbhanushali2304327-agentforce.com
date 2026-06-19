public class ContactDetailsWrapper {
    @AuraEnabled public String contactId;
    @AuraEnabled public String name;
    @AuraEnabled public String email;
    @AuraEnabled public String phone;
    @AuraEnabled public String title;

    // Constructor to parse the Contact record
    public ContactDetailsWrapper(Contact con) {
        this.contactId = con.Id;
        this.name = con.Name;
        this.email = con.Email;
        this.phone = con.Phone;
        this.title = con.Title;
    }
}