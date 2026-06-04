/**
 * BookingTrigger.trigger
 */
trigger BookingTrigger on Booking__c (after insert, after update) {
if (Trigger.isAfter) {
if (Trigger.isInsert) {
 BookingTriggerHandler.handleAfterInsert(Trigger.newMap.keySet());
 } else if (Trigger.isUpdate) {
 BookingTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
 }
}
}