/** Parent-authorized projection for future workspace pause/resume controls. */
public class LOS_TATDTO {
  @AuraEnabled
  public Id stageTATId { get; private set; }
  @AuraEnabled
  public Id activePauseId { get; private set; }
  @AuraEnabled
  public String stageCode { get; private set; }
  @AuraEnabled
  public Datetime startedAt { get; private set; }
  @AuraEnabled
  public Decimal pausedMinutes { get; private set; }
  public LOS_TATDTO(LOS_Stage_TAT__c row, Id pauseId) {
    stageTATId = row.Id;
    activePauseId = pauseId;
    stageCode = row.LOS_Stage__c;
    startedAt = row.LOS_Start_Date_Time__c;
    pausedMinutes = row.LOS_Paused_Minutes__c;
  }
}
