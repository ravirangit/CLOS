trigger LOS_HistoryGuard on LOS_Lifecycle_History__c(
  before insert,
  before update,
  before delete,
  after undelete
) {
  LOS_RecordGuard.enforce(
    Trigger.isDelete ? Trigger.old : Trigger.new,
    Trigger.isInsert,
    Trigger.isDelete || Trigger.isUndelete,
    true
  );
}
