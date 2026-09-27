@IsTest
private class LOS_TATServiceTest {
  @TestSetup
  static void setup() {
    LOS_TestData.setup();
  }
  @IsTest
  static void pauseResumeAndCloseUseGrossTimeAndSnapshotPolicy() {
    System.runAs(LOS_TestData.actor()) {
      Datetime start = Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0);
      LOS_BusinessTimeService.fixedNow = start;
      LOS_TestData.sla(10, null);
      LOS_TestData.pauseRule(false);
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      LOS_Stage_TAT__c initial = LOS_TestData.open(app.applicationId);
      LOS_BusinessTimeService.fixedNow = start.addMinutes(2);
      Id pauseId = LOS_TATService.pauseTAT(
        app.applicationId,
        initial.Id,
        'WAIT_TEST',
        'Waiting'
      );
      Assert.areEqual(
        pauseId,
        LOS_TATService.getCurrentTAT(app.applicationId).activePauseId
      );
      LOS_TestData.pauseRule(true); // stored policy is still false for the already-open pause.
      LOS_BusinessTimeService.fixedNow = start.addMinutes(7);
      LOS_TATService.resumeTAT(app.applicationId, pauseId);
      Assert.areEqual(
        5,
        LOS_TestData.open(app.applicationId).LOS_Paused_Minutes__c
      );
      LOS_BusinessTimeService.fixedNow = start.addMinutes(14);
      LOS_TestData.sla(100, null);
      app = LOS_TestData.move(app, 'Draft_To_Underwriting');
      LOS_Stage_TAT__c closed = [
        SELECT
          LOS_Gross_Minutes__c,
          LOS_Paused_Minutes__c,
          LOS_SLA_Target_Minutes__c,
          LOS_SLA_Status__c,
          LOS_Completed_By__c,
          LOS_Open_Context_Key__c,
          LOS_Business_Minutes__c
        FROM LOS_Stage_TAT__c
        WHERE Id = :initial.Id
      ];
      Assert.areEqual(14, closed.LOS_Gross_Minutes__c);
      Assert.areEqual(5, closed.LOS_Paused_Minutes__c);
      Assert.areEqual(10, closed.LOS_SLA_Target_Minutes__c);
      Assert.areEqual('Preliminary_Within_Target', closed.LOS_SLA_Status__c);
      Assert.areEqual(UserInfo.getUserId(), closed.LOS_Completed_By__c);
      Assert.isNull(closed.LOS_Open_Context_Key__c);
      Assert.isNull(closed.LOS_Business_Minutes__c);
      Assert.areEqual(
        100,
        LOS_TestData.open(app.applicationId).LOS_SLA_Target_Minutes__c
      );
    }
  }
  @IsTest
  static void countTowardSLAAndCalendarPendingAreExplicit() {
    System.runAs(LOS_TestData.actor()) {
      Datetime start = Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0);
      LOS_BusinessTimeService.fixedNow = start;
      LOS_TestData.sla(2, null);
      LOS_TestData.pauseRule(true);
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      Id original = LOS_TestData.open(app.applicationId).Id;
      Id pauseId = LOS_TATService.pauseTAT(
        app.applicationId,
        original,
        'WAIT_TEST',
        'Counts'
      );
      LOS_BusinessTimeService.fixedNow = start.addMinutes(3);
      LOS_TATService.resumeTAT(app.applicationId, pauseId);
      LOS_TestData.sla(10, 'CLIENT_CALENDAR');
      app = LOS_TestData.move(app, 'Draft_To_Underwriting');
      Assert.areEqual(
        'Preliminary_Exceeded',
        [SELECT LOS_SLA_Status__c FROM LOS_Stage_TAT__c WHERE Id = :original]
        .LOS_SLA_Status__c
      );
      Id nextId = LOS_TestData.open(app.applicationId).Id;
      LOS_BusinessTimeService.fixedNow = start.addMinutes(4);
      LOS_TestData.move(app, 'Underwriting_To_RM_TL_Review');
      Assert.areEqual(
        'Pending_Calendar',
        [SELECT LOS_SLA_Status__c FROM LOS_Stage_TAT__c WHERE Id = :nextId]
        .LOS_SLA_Status__c
      );
    }
  }
  @IsTest
  static void overlapUnknownReasonAndMissingCommentsFail() {
    System.runAs(LOS_TestData.actor()) {
      LOS_TestData.pauseRule(false);
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      Id tat = LOS_TestData.open(app.applicationId).Id;
      try {
        LOS_TATService.pauseTATs(
          new List<LOS_TATService.PauseRequest>{
            new LOS_TATService.PauseRequest(
              app.applicationId,
              tat,
              'UNKNOWN',
              'test'
            )
          }
        );
        Assert.fail('Expected failure');
      } catch (LOS_ConfigurationException e) {
        Assert.isNotNull(e);
      }
      try {
        LOS_TATService.pauseTATs(
          new List<LOS_TATService.PauseRequest>{
            new LOS_TATService.PauseRequest(
              app.applicationId,
              tat,
              'WAIT_TEST',
              null
            )
          }
        );
        Assert.fail('Expected failure');
      } catch (LOS_ValidationException e) {
        Assert.isNotNull(e);
      }
      Id pauseId = LOS_TATService.pauseTAT(
        app.applicationId,
        tat,
        'WAIT_TEST',
        'test'
      );
      try {
        LOS_TATService.pauseTATs(
          new List<LOS_TATService.PauseRequest>{
            new LOS_TATService.PauseRequest(
              app.applicationId,
              tat,
              'WAIT_TEST',
              'test'
            )
          }
        );
        Assert.fail('Expected failure');
      } catch (LOS_TATException e) {
        Assert.isNotNull(e);
      }
      try {
        LOS_TestData.move(app, 'Draft_To_Underwriting');
        Assert.fail('Expected failure');
      } catch (LOS_TATException e) {
        Assert.isTrue(e.getMessage().contains('Resume'));
      }
      Assert.areEqual(1, [SELECT COUNT() FROM LOS_TAT_Pause__c]);
      Assert.areEqual(1, [SELECT COUNT() FROM LOS_Lifecycle_History__c]);
      LOS_TATService.resumeTAT(app.applicationId, pauseId);
      try {
        LOS_TATService.resumeTATs(
          new List<LOS_TATService.ResumeRequest>{
            new LOS_TATService.ResumeRequest(app.applicationId, pauseId)
          }
        );
        Assert.fail('Expected failure');
      } catch (LOS_TATException e) {
        Assert.isNotNull(e);
      }
    }
  }
  @IsTest
  static void stalePauseAndResumeCannotAffectNewInterval() {
    System.runAs(LOS_TestData.actor()) {
      LOS_TestData.pauseRule(false);
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      Id oldId = LOS_TestData.open(app.applicationId).Id;
      Id oldPause = LOS_TATService.pauseTAT(
        app.applicationId,
        oldId,
        'WAIT_TEST',
        'test'
      );
      LOS_TATService.resumeTAT(app.applicationId, oldPause);
      app = LOS_TestData.move(app, 'Draft_To_Underwriting');
      Id newId = LOS_TestData.open(app.applicationId).Id;
      try {
        LOS_TATService.pauseTATs(
          new List<LOS_TATService.PauseRequest>{
            new LOS_TATService.PauseRequest(
              app.applicationId,
              oldId,
              'WAIT_TEST',
              'test'
            )
          }
        );
        Assert.fail('Expected failure');
      } catch (LOS_TATException e) {
        Assert.isNotNull(e);
      }
      Id currentPause = LOS_TATService.pauseTAT(
        app.applicationId,
        newId,
        'WAIT_TEST',
        'test'
      );
      try {
        LOS_TATService.resumeTATs(
          new List<LOS_TATService.ResumeRequest>{
            new LOS_TATService.ResumeRequest(app.applicationId, oldPause)
          }
        );
        Assert.fail('Expected failure');
      } catch (LOS_TATException e) {
        Assert.isNotNull(e);
      }
      Assert.isNull(
        [SELECT LOS_Pause_End__c FROM LOS_TAT_Pause__c WHERE Id = :currentPause]
        .LOS_Pause_End__c
      );
    }
  }
  @IsTest
  static void subminutePausesAccumulateBeforeRounding() {
    System.runAs(LOS_TestData.actor()) {
      Datetime start = Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0);
      LOS_BusinessTimeService.fixedNow = start;
      LOS_TestData.pauseRule(false);
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      Id tat = LOS_TestData.open(app.applicationId).Id;
      Id p = LOS_TATService.pauseTAT(
        app.applicationId,
        tat,
        'WAIT_TEST',
        'first'
      );
      LOS_BusinessTimeService.fixedNow = start.addSeconds(40);
      LOS_TATService.resumeTAT(app.applicationId, p);
      p = LOS_TATService.pauseTAT(
        app.applicationId,
        tat,
        'WAIT_TEST',
        'second'
      );
      LOS_BusinessTimeService.fixedNow = start.addSeconds(80);
      LOS_TATService.resumeTAT(app.applicationId, p);
      Assert.areEqual(
        1,
        LOS_TestData.open(app.applicationId).LOS_Paused_Minutes__c
      );
    }
  }
  @IsTest
  static void durationBoundaryRejectsReversedClock() {
    Datetime start = Datetime.newInstanceGmt(2026, 1, 1, 0, 0, 0);
    Assert.areEqual(
      1,
      LOS_BusinessTimeService.grossMinutes(start, start.addSeconds(119))
    );
    Assert.isNull(
      LOS_BusinessTimeService.businessMinutes(start, start.addHours(2), null)
    );
    try {
      LOS_BusinessTimeService.grossMinutes(start, start.addSeconds(-1));
      Assert.fail('Expected failure');
    } catch (LOS_TATException e) {
      Assert.isNotNull(e);
    }
    try {
      LOS_BusinessTimeService.minutes(-1);
      Assert.fail('Expected failure');
    } catch (LOS_TATException e) {
      Assert.isNotNull(e);
    }
  }

  @IsTest
  static void bulkPauseAndResumeAreBounded() {
    System.runAs(LOS_TestData.actor()) {
      LOS_TestData.pauseRule(false);
      Id rel = LOS_TestData.relationship().Id;
      List<LOS_ApplicationService.CreateRequest> creates = new List<LOS_ApplicationService.CreateRequest>();
      for (Integer i = 0; i < 200; i++)
        creates.add(new LOS_ApplicationService.CreateRequest(rel, 'New'));
      List<LOS_ApplicationDTO> apps = LOS_ApplicationService.createApplications(
        creates
      );
      Map<Id, Id> intervals = new Map<Id, Id>();
      for (LOS_Stage_TAT__c tat : [
        SELECT Id, LOS_Application__c
        FROM LOS_Stage_TAT__c
      ])
        intervals.put(tat.LOS_Application__c, tat.Id);
      List<LOS_TATService.PauseRequest> requests = new List<LOS_TATService.PauseRequest>();
      for (LOS_ApplicationDTO app : apps)
        requests.add(
          new LOS_TATService.PauseRequest(
            app.applicationId,
            intervals.get(app.applicationId),
            'WAIT_TEST',
            'bulk'
          )
        );
      Test.startTest();
      List<Id> pauseIds = LOS_TATService.pauseTATs(requests);
      List<LOS_TATService.ResumeRequest> resumes = new List<LOS_TATService.ResumeRequest>();
      for (Integer i = 0; i < apps.size(); i++)
        resumes.add(
          new LOS_TATService.ResumeRequest(apps[i].applicationId, pauseIds[i])
        );
      LOS_TATService.resumeTATs(resumes);
      Assert.isTrue(Limits.getQueries() < 40);
      Assert.isTrue(Limits.getDmlStatements() < 12);
      Test.stopTest();
      Assert.areEqual(200, [SELECT COUNT() FROM LOS_TAT_Pause__c]);
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM LOS_TAT_Pause__c WHERE LOS_Pause_End__c = NULL]
      );
    }
  }

  @IsTest
  static void databaseKeysRejectDuplicateOpenIntervalsAndPauses() {
    System.runAs(LOS_TestData.actor()) {
      LOS_TestData.pauseRule(false);
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      Id tat = LOS_TestData.open(app.applicationId).Id;
      try {
        LOS_RuntimeService.persist(
          new List<SObject>{
            new LOS_Stage_TAT__c(
              LOS_Application__c = app.applicationId,
              LOS_Stage__c = 'Draft',
              LOS_Rework_Number__c = 0,
              LOS_Start_Date_Time__c = System.now(),
              LOS_Started_By__c = UserInfo.getUserId(),
              LOS_Open_Context_Key__c = String.valueOf(app.applicationId)
            )
          },
          true
        );
        Assert.fail('Expected duplicate key failure');
      } catch (DmlException e) {
        Assert.areEqual('DUPLICATE_VALUE', e.getDmlStatusCode(0));
      }
      LOS_TATService.pauseTAT(app.applicationId, tat, 'WAIT_TEST', 'first');
      try {
        LOS_RuntimeService.persist(
          new List<SObject>{
            new LOS_TAT_Pause__c(
              LOS_Application__c = app.applicationId,
              LOS_Stage_TAT__c = tat,
              LOS_Pause_Reason__c = 'WAIT_TEST',
              LOS_Pause_Start__c = System.now(),
              LOS_Open_Context_Key__c = String.valueOf(tat)
            )
          },
          true
        );
        Assert.fail('Expected duplicate key failure');
      } catch (DmlException e) {
        Assert.areEqual('DUPLICATE_VALUE', e.getDmlStatusCode(0));
      }
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM LOS_Stage_TAT__c WHERE LOS_End_Date_Time__c = NULL]
      );
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM LOS_TAT_Pause__c WHERE LOS_Pause_End__c = NULL]
      );
    }
  }
  @IsTest
  static void effectivePersonaMembershipSelectsScopedSLA() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ConfigurationService.testData.put(
        'Persona',
        new List<SObject>{
          new LOS_Persona__mdt(
            MasterLabel = 'Test',
            LOS_Code__c = 'TEST_PERSONA',
            LOS_Active__c = true
          )
        }
      );
      LOS_SLA_Rule__mdt rule = new LOS_SLA_Rule__mdt(
        MasterLabel = 'Scoped',
        LOS_Code__c = 'SCOPED',
        LOS_Active__c = true,
        LOS_Target_Minutes__c = 17,
        LOS_Priority__c = 1
      );
      rule = (LOS_SLA_Rule__mdt) LOS_TestData.withRelationship(
        rule,
        'LOS_Persona__r',
        new LOS_Persona__mdt(LOS_Code__c = 'TEST_PERSONA')
      );
      LOS_ConfigurationService.testData.put(
        'SLA_Rule',
        new List<SObject>{ rule }
      );
      LOS_ConfigurationService.reset();
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      Assert.isNull(
        LOS_TestData.open(app.applicationId).LOS_SLA_Target_Minutes__c
      );
      insert as system new LOS_Application_Team__c(
        LOS_Credit_Application__c = app.applicationId,
        LOS_User__c = UserInfo.getUserId(),
        LOS_Persona_Code__c = 'TEST_PERSONA',
        LOS_Access_Level__c = 'TEST',
        LOS_Active__c = true,
        LOS_Effective_From__c = Date.today()
      );
      app = LOS_TestData.move(app, 'Draft_To_Underwriting');
      Assert.areEqual(
        17,
        LOS_TestData.open(app.applicationId).LOS_SLA_Target_Minutes__c
      );
    }
  }
}
