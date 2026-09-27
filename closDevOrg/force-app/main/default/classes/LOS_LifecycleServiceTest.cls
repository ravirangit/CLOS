@IsTest
private class LOS_LifecycleServiceTest {
  @TestSetup
  static void setup() {
    LOS_TestData.setup();
  }
  private class Reject implements LOS_ValidationService.Hook {
    public List<LOS_ValidationService.Result> validate(
      LOS_ValidationService.Context context
    ) {
      return new List<LOS_ValidationService.Result>{
        new LOS_ValidationService.Result(
          'Error',
          'TEST_BLOCK',
          'Test validation blocks this transition.',
          true
        )
      };
    }
  }
  @IsTest
  static void forwardLifecyclePreservesReworkZero() {
    System.runAs(LOS_TestData.actor()) {
      Test.startTest();
      LOS_ApplicationDTO app = LOS_TestData.atReview(true);
      Test.stopTest();
      Assert.areEqual('Credit_Review', app.stageCode);
      Assert.areEqual(0, app.reworkNumber);
      Assert.areEqual(3, app.version);
      Assert.areEqual(
        4,
        [
          SELECT COUNT()
          FROM LOS_Lifecycle_History__c
          WHERE LOS_Credit_Application__c = :app.applicationId
        ]
      );
      Assert.areEqual(
        3,
        [
          SELECT COUNT()
          FROM LOS_Stage_TAT__c
          WHERE
            LOS_Application__c = :app.applicationId
            AND LOS_End_Date_Time__c != NULL
        ]
      );
      Assert.areEqual(
        'Credit_Review',
        LOS_TestData.open(app.applicationId).LOS_Stage__c
      );
    }
  }
  private static void rework(Boolean credit, String destination) {
    System.runAs(LOS_TestData.actor()) {
      Test.startTest();
      LOS_ApplicationDTO app = LOS_TestData.atReview(credit);
      app = LOS_TestData.move(
        app,
        (credit ? 'Credit_Review' : 'RM_TL_Review') + '_To_' + destination
      );
      Test.stopTest();
      Assert.areEqual(destination, app.stageCode);
      Assert.areEqual(1, app.reworkNumber);
      Assert.areEqual(
        1,
        [
          SELECT LOS_Rework_Count__c
          FROM LOS_Credit_Application__c
          WHERE Id = :app.applicationId
        ]
        .LOS_Rework_Count__c
      );
      Assert.areEqual(
        1,
        LOS_TestData.open(app.applicationId).LOS_Rework_Number__c
      );
      Assert.areEqual(
        1,
        [
          SELECT COUNT()
          FROM LOS_Lifecycle_History__c
          WHERE
            LOS_Credit_Application__c = :app.applicationId
            AND LOS_Transition_Type__c = 'Rework'
            AND LOS_Rework_Number__c = 1
        ]
      );
    }
  }
  @IsTest
  static void rmToDraft() {
    rework(false, 'Draft');
  }
  @IsTest
  static void rmToUnderwriting() {
    rework(false, 'Underwriting');
  }
  @IsTest
  static void creditToDraft() {
    rework(true, 'Draft');
  }
  @IsTest
  static void creditToUnderwriting() {
    rework(true, 'Underwriting');
  }
  @IsTest
  static void creditToRM() {
    rework(true, 'RM_TL_Review');
  }
  @IsTest
  static void forwardWithinReworkDoesNotIncrementAgain() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.atReview(true);
      Test.startTest();
      app = LOS_TestData.move(app, 'Credit_Review_To_Underwriting');
      app = LOS_TestData.move(app, 'Underwriting_To_RM_TL_Review');
      app = LOS_TestData.move(app, 'RM_TL_Review_To_Credit_Review');
      Assert.areEqual(1, app.reworkNumber);
      app = LOS_TestData.move(app, 'Credit_Review_To_Draft');
      Test.stopTest();
      Assert.areEqual(2, app.reworkNumber);
    }
  }
  @IsTest
  static void rejectsInvalidAndInactiveTransitions() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      try {
        LOS_TestData.move(app, 'Draft_To_Credit_Review');
        Assert.fail('Expected failure');
      } catch (LOS_ConfigurationException e) {
        Assert.isNotNull(e);
      }
      try {
        LOS_TestData.move(app, 'RM_TL_Review_To_Credit_Review');
        Assert.fail('Expected failure');
      } catch (LOS_LifecycleException e) {
        Assert.isNotNull(e);
      }
      app = LOS_TestData.move(app, 'Draft_To_Underwriting');
      try {
        LOS_TestData.move(app, 'Underwriting_To_Approved');
        Assert.fail('Expected failure');
      } catch (LOS_ConfigurationException e) {
        Assert.isNotNull(e);
      }
      LOS_Stage_Transition__mdt t = LOS_TestData.transition(
        'Underwriting_To_RM_TL_Review'
      );
      t.LOS_Active__c = false;
      LOS_TestData.overrideTransition(t);
      try {
        LOS_TestData.move(app, 'Underwriting_To_RM_TL_Review');
        Assert.fail('Expected failure');
      } catch (LOS_ConfigurationException e) {
        Assert.isNotNull(e);
      }
      Assert.areEqual(
        2,
        [
          SELECT COUNT()
          FROM LOS_Lifecycle_History__c
          WHERE LOS_Credit_Application__c = :app.applicationId
        ]
      );
    }
  }
  @IsTest
  static void reasonAndValidationFailureAreAtomic() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.atReview(false);
      Id originalTAT = LOS_TestData.open(app.applicationId).Id;
      LOS_LifecycleService.TransitionRequest request = new LOS_LifecycleService.TransitionRequest(
        app.applicationId,
        'RM_TL_Review_To_Draft',
        app.version
      );
      try {
        LOS_LifecycleService.transitionApplications(
          new List<LOS_LifecycleService.TransitionRequest>{ request }
        );
        Assert.fail('Expected failure');
      } catch (LOS_ValidationException e) {
        Assert.areEqual('REASON_REQUIRED', e.results[0].code);
      }
      LOS_Stage_Transition__mdt t = LOS_TestData.transition(
        'RM_TL_Review_To_Credit_Review'
      );
      t.LOS_Validation_Policy_Code__c = 'TEST_BLOCK';
      LOS_TestData.overrideTransition(t);
      LOS_ValidationService.registerHook('TEST_BLOCK', new Reject());
      try {
        LOS_TestData.move(app, 'RM_TL_Review_To_Credit_Review');
        Assert.fail('Expected failure');
      } catch (LOS_ValidationException e) {
        Assert.areEqual('TEST_BLOCK', e.results[0].code);
        Assert.isTrue(e.results[0].blocking);
      }
      Assert.areEqual(
        'RM_TL_Review',
        [
          SELECT LOS_Current_Stage__c
          FROM LOS_Credit_Application__c
          WHERE Id = :app.applicationId
        ]
        .LOS_Current_Stage__c
      );
      Assert.areEqual(
        3,
        [
          SELECT COUNT()
          FROM LOS_Lifecycle_History__c
          WHERE LOS_Credit_Application__c = :app.applicationId
        ]
      );
      Assert.areEqual(originalTAT, LOS_TestData.open(app.applicationId).Id);
    }
  }
  @IsTest
  static void unknownHookFailsClosed() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      LOS_Stage_Transition__mdt t = LOS_TestData.transition(
        'Draft_To_Underwriting'
      );
      t.LOS_Validation_Policy_Code__c = 'NOT_REGISTERED';
      LOS_TestData.overrideTransition(t);
      try {
        LOS_TestData.move(app, 'Draft_To_Underwriting');
        Assert.fail('Expected failure');
      } catch (LOS_ConfigurationException e) {
        Assert.isTrue(e.getMessage().contains('not registered'));
      }
      Assert.areEqual(1, [SELECT COUNT() FROM LOS_Lifecycle_History__c]);
    }
  }
  @IsTest
  static void staleRequestAndReturnToSameStageAreRejected() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO stale = LOS_TestData.createApp();
      LOS_ApplicationDTO app = LOS_TestData.move(
        stale,
        'Draft_To_Underwriting'
      );
      try {
        LOS_TestData.move(stale, 'Draft_To_Underwriting');
        Assert.fail('Expected failure');
      } catch (LOS_LifecycleException e) {
        Assert.isTrue(e.getMessage().contains('Refresh'));
      }
      app = LOS_TestData.move(app, 'Underwriting_To_RM_TL_Review');
      app = LOS_TestData.move(app, 'RM_TL_Review_To_Draft');
      try {
        LOS_TestData.move(stale, 'Draft_To_Underwriting');
        Assert.fail('Expected failure');
      } catch (LOS_LifecycleException e) {
        Assert.isTrue(e.getMessage().contains('Refresh'));
      }
      Assert.areEqual(4, [SELECT COUNT() FROM LOS_Lifecycle_History__c]);
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM LOS_Stage_TAT__c WHERE LOS_End_Date_Time__c = NULL]
      );
    }
  }
  @IsTest
  static void duplicateBatchApplicationRejected() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      LOS_LifecycleService.TransitionRequest r = new LOS_LifecycleService.TransitionRequest(
        app.applicationId,
        'Draft_To_Underwriting',
        app.version
      );
      try {
        LOS_LifecycleService.transitionApplications(
          new List<LOS_LifecycleService.TransitionRequest>{ r, r }
        );
        Assert.fail('Expected failure');
      } catch (LOS_ValidationException e) {
        Assert.isNotNull(e);
      }
      Assert.areEqual(1, [SELECT COUNT() FROM LOS_Lifecycle_History__c]);
    }
  }
  @IsTest
  static void lateFailureRollsBackAllDML() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      Id initial = LOS_TestData.open(app.applicationId).Id;
      LOS_TestData.sla(-1, null); // new interval creation fails AFTER close, application update and history insert.
      try {
        LOS_TestData.move(app, 'Draft_To_Underwriting');
        Assert.fail('Expected failure');
      } catch (LOS_ConfigurationException e) {
        Assert.isNotNull(e);
      }
      Assert.areEqual(
        'Draft',
        [
          SELECT LOS_Current_Stage__c
          FROM LOS_Credit_Application__c
          WHERE Id = :app.applicationId
        ]
        .LOS_Current_Stage__c
      );
      Assert.areEqual(initial, LOS_TestData.open(app.applicationId).Id);
      Assert.areEqual(1, [SELECT COUNT() FROM LOS_Lifecycle_History__c]);
    }
  }

  @IsTest
  static void mixedValidityBatchRollsBackEveryApplication() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO first = LOS_TestData.createApp();
      LOS_ApplicationDTO second = LOS_TestData.createApp();
      List<LOS_LifecycleService.TransitionRequest> requests = new List<LOS_LifecycleService.TransitionRequest>{
        new LOS_LifecycleService.TransitionRequest(
          first.applicationId,
          'Draft_To_Underwriting',
          first.version
        ),
        new LOS_LifecycleService.TransitionRequest(
          second.applicationId,
          'RM_TL_Review_To_Credit_Review',
          second.version
        )
      };
      try {
        LOS_LifecycleService.transitionApplications(requests);
        Assert.fail('Expected failure');
      } catch (LOS_LifecycleException e) {
        Assert.isNotNull(e);
      }
      Assert.areEqual(
        2,
        [
          SELECT COUNT()
          FROM LOS_Credit_Application__c
          WHERE LOS_Current_Stage__c = 'Draft'
        ]
      );
      Assert.areEqual(2, [SELECT COUNT() FROM LOS_Lifecycle_History__c]);
      Assert.areEqual(
        2,
        [SELECT COUNT() FROM LOS_Stage_TAT__c WHERE LOS_End_Date_Time__c = NULL]
      );
    }
  }

  @IsTest
  static void inactiveApplicationsCannotTransition() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      LOS_RuntimeService.persist(
        new List<SObject>{
          new LOS_Credit_Application__c(
            Id = app.applicationId,
            LOS_Active__c = false
          )
        },
        false
      );
      try {
        LOS_TestData.move(app, 'Draft_To_Underwriting');
        Assert.fail('Expected failure');
      } catch (LOS_LifecycleException e) {
        Assert.isTrue(e.getMessage().contains('inactive'));
      }
      Assert.areEqual(
        0,
        LOS_LifecycleService.getAvailableTransitions(app.applicationId).size()
      );
      Assert.areEqual(1, [SELECT COUNT() FROM LOS_Lifecycle_History__c]);
    }
  }
  @IsTest
  static void configuredTerminalDestinationDoesNotStartTAT() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      LOS_Stage_Transition__mdt transition = LOS_TestData.transition(
        'Draft_To_Underwriting'
      );
      transition = (LOS_Stage_Transition__mdt) LOS_TestData.withRelationship(
        transition,
        'LOS_To_Stage__r',
        new LOS_Stage__mdt(LOS_Code__c = 'Monitoring')
      );
      LOS_TestData.overrideTransition(transition);
      app = LOS_TestData.move(app, 'Draft_To_Underwriting');
      Assert.areEqual('Monitoring', app.stageCode);
      Assert.isNull(LOS_TATService.getCurrentTAT(app.applicationId));
      Assert.areEqual(
        0,
        LOS_LifecycleService.getAvailableTransitions(app.applicationId).size()
      );
      try {
        LOS_TestData.move(app, 'Draft_To_Underwriting');
        Assert.fail('Expected failure');
      } catch (LOS_LifecycleException e) {
        Assert.isNotNull(e);
      }
    }
  }
  private class SideEffect implements LOS_ValidationService.Hook {
    public List<LOS_ValidationService.Result> validate(
      LOS_ValidationService.Context context
    ) {
      insert as system new Account(Name = 'Forbidden Validation Side Effect');
      return new List<LOS_ValidationService.Result>();
    }
  }
  @IsTest
  static void validationHooksCannotCommitSideEffects() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      LOS_Stage_Transition__mdt transition = LOS_TestData.transition(
        'Draft_To_Underwriting'
      );
      transition.LOS_Validation_Policy_Code__c = 'SIDE_EFFECT';
      LOS_TestData.overrideTransition(transition);
      LOS_ValidationService.registerHook('SIDE_EFFECT', new SideEffect());
      try {
        LOS_TestData.move(app, 'Draft_To_Underwriting');
        Assert.fail('Expected failure');
      } catch (LOS_ConfigurationException e) {
        Assert.isTrue(e.getMessage().contains('must not perform'));
      }
      Assert.areEqual(
        0,
        [
          SELECT COUNT()
          FROM Account
          WHERE Name = 'Forbidden Validation Side Effect'
          WITH SYSTEM_MODE
        ]
      );
      Assert.areEqual(1, [SELECT COUNT() FROM LOS_Lifecycle_History__c]);
    }
  }
}
