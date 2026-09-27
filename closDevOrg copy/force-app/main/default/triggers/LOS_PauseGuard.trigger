trigger LOS_PauseGuard on LOS_TAT_Pause__c(
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
