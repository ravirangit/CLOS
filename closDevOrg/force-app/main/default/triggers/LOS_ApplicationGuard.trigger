trigger LOS_ApplicationGuard on LOS_Credit_Application__c(
  before insert,
  before update,
  before delete,
  after undelete
) {
  LOS_RecordGuard.enforce(
    Trigger.isDelete ? Trigger.old : Trigger.new,
    Trigger.isInsert,
    Trigger.isDelete || Trigger.isUndelete,
    false
  );
}
