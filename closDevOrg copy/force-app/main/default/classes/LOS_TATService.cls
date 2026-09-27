/** TAT policy/builders are pure. Only the runtime coordinator persists controlled writes. */
public with sharing class LOS_TATService {
  @AuraEnabled
  public static LOS_TATDTO getCurrentTAT(Id applicationId) {
    try {
      LOS_Security.requireEdit(new Set<Id>{ applicationId });
      if (
        !LOS_Stage_TAT__c.SObjectType.getDescribe().isAccessible() ||
        !LOS_TAT_Pause__c.SObjectType.getDescribe().isAccessible()
      )
        throw new LOS_SecurityException(
          'You do not have access to stage timing information.'
        );
      for (
        Schema.SObjectField field : new List<Schema.SObjectField>{
          LOS_Stage_TAT__c.LOS_Stage__c,
          LOS_Stage_TAT__c.LOS_Start_Date_Time__c,
          LOS_Stage_TAT__c.LOS_Paused_Minutes__c,
          LOS_TAT_Pause__c.LOS_Pause_End__c
        }
      )
        if (!field.getDescribe().isAccessible())
          throw new LOS_SecurityException(
            'You do not have access to stage timing information.'
          );
      LOS_Stage_TAT__c tat = LOS_RuntimeData.openIntervals(
          new Set<Id>{ applicationId }
        )
        .get(applicationId);
      if (tat == null)
        return null;
      Id active;
      for (
        LOS_TAT_Pause__c pause : LOS_RuntimeData.pauses(new Set<Id>{ tat.Id })
          .get(tat.Id)
      )
        if (pause.LOS_Pause_End__c == null) {
          if (active != null)
            throw new LOS_TATException(
              'Multiple active pauses require administrator repair.'
            );
          active = pause.Id;
        }
      return new LOS_TATDTO(tat, active);
    } catch (Exception e) {
      throw LOS_Exception.forClient(e);
    }
  }
  public class PauseRequest {
    public Id applicationId;
    public Id expectedStageTATId;
    public String reasonCode;
    public String comments;
    public PauseRequest(
      Id applicationId,
      Id expectedStageTATId,
      String reasonCode,
      String comments
    ) {
      this.applicationId = applicationId;
      this.expectedStageTATId = expectedStageTATId;
      this.reasonCode = reasonCode;
      this.comments = comments;
    }
  }
  public class ResumeRequest {
    public Id applicationId;
    public Id expectedPauseId;
    public ResumeRequest(Id applicationId, Id expectedPauseId) {
      this.applicationId = applicationId;
      this.expectedPauseId = expectedPauseId;
    }
  }
  @AuraEnabled
  public static Id pauseTAT(
    Id applicationId,
    Id expectedStageTATId,
    String reasonCode,
    String comments
  ) {
    try {
      return pauseTATs(
        new List<PauseRequest>{
          new PauseRequest(
            applicationId,
            expectedStageTATId,
            reasonCode,
            comments
          )
        }
      )[0];
    } catch (Exception e) {
      throw LOS_Exception.forClient(e);
    }
  }
  @AuraEnabled
  public static void resumeTAT(Id applicationId, Id expectedPauseId) {
    try {
      resumeTATs(
        new List<ResumeRequest>{
          new ResumeRequest(applicationId, expectedPauseId)
        }
      );
    } catch (Exception e) {
      throw LOS_Exception.forClient(e);
    }
  }
  public static List<Id> pauseTATs(List<PauseRequest> requests) {
    return LOS_RuntimeService.pauseTATs(requests);
  }
  public static void resumeTATs(List<ResumeRequest> requests) {
    LOS_RuntimeService.resumeTATs(requests);
  }
  public static LOS_Stage_TAT__c startStageTAT(
    LOS_Credit_Application__c app,
    LOS_ConfigurationService.Config stage,
    LOS_ConfigurationService.Config sla,
    Datetime stamp
  ) {
    if (!stage.tatEnabled)
      return null;
    return new LOS_Stage_TAT__c(
      LOS_Application__c = app.Id,
      LOS_Stage__c = stage.code,
      LOS_Rework_Number__c = app.LOS_Current_Rework_Number__c,
      LOS_Start_Date_Time__c = stamp,
      LOS_Started_By__c = UserInfo.getUserId(),
      LOS_Paused_Minutes__c = 0,
      LOS_SLA_Target_Minutes__c = sla == null ? null : sla.targetMinutes,
      LOS_Calendar_Key__c = sla == null ? null : sla.calendarKey,
      LOS_Open_Context_Key__c = String.valueOf(app.Id)
    );
  }
  public static void closeStageTAT(
    LOS_Stage_TAT__c tat,
    List<LOS_TAT_Pause__c> pauses,
    Datetime stamp
  ) {
    if (tat.LOS_End_Date_Time__c != null)
      throw new LOS_TATException('The stage interval has already closed.');
    for (LOS_TAT_Pause__c p : pauses)
      if (p.LOS_Pause_End__c == null)
        throw new LOS_TATException(
          'Resume the active pause before changing stage.'
        );
    tat.LOS_End_Date_Time__c = stamp;
    tat.LOS_Completed_By__c = UserInfo.getUserId();
    tat.LOS_Open_Context_Key__c = null;
    recalculate(tat, pauses, stamp);
  }
  public static void recalculate(
    LOS_Stage_TAT__c tat,
    List<LOS_TAT_Pause__c> pauses,
    Datetime stamp
  ) {
    Long total = 0;
    Long excluded = 0;
    for (LOS_TAT_Pause__c p : pauses) {
      if (p.LOS_Pause_End__c == null)
        continue;
      Long elapsed = LOS_BusinessTimeService.milliseconds(
        p.LOS_Pause_Start__c,
        p.LOS_Pause_End__c
      );
      total += elapsed;
      if (!p.LOS_Count_Toward_SLA__c)
        excluded += elapsed;
    }
    Long gross = LOS_BusinessTimeService.milliseconds(
      tat.LOS_Start_Date_Time__c,
      stamp
    );
    if (total > gross)
      throw new LOS_TATException('Pause durations exceed the stage duration.');
    tat.LOS_Gross_Minutes__c = LOS_BusinessTimeService.minutes(gross);
    tat.LOS_Paused_Minutes__c = LOS_BusinessTimeService.minutes(total);
    tat.LOS_Business_Minutes__c = LOS_BusinessTimeService.businessMinutes(
      tat.LOS_Start_Date_Time__c,
      stamp,
      tat.LOS_Calendar_Key__c
    );
    if (tat.LOS_SLA_Target_Minutes__c == null)
      tat.LOS_SLA_Status__c = 'Not_Configured';
    else if (!String.isBlank(tat.LOS_Calendar_Key__c))
      tat.LOS_SLA_Status__c = 'Pending_Calendar';
    else
      tat.LOS_SLA_Status__c = Decimal.valueOf(
          String.valueOf(gross - excluded)
        ) > tat.LOS_SLA_Target_Minutes__c * 60000
        ? 'Preliminary_Exceeded'
        : 'Preliminary_Within_Target';
  }
}
