@IsTest
private class LOS_ArchitectureHardeningTest {
  @TestSetup
  static void setup() {
    LOS_TestData.setup();
  }
  private class Accept implements LOS_ValidationService.Hook {
    public List<LOS_ValidationService.Result> validate(
      LOS_ValidationService.Context context
    ) {
      return new List<LOS_ValidationService.Result>();
    }
  }
  private static void overrideStatus(String code, String status) {
    List<SObject> rows = new List<SObject>();
    for (LOS_Stage__mdt stage : [
      SELECT
        MasterLabel,
        LOS_Code__c,
        LOS_Active__c,
        LOS_Description__c,
        LOS_Sequence__c,
        LOS_Display_Label__c,
        LOS_Terminal_Stage__c,
        LOS_TAT_Enabled__c,
        LOS_Approval_Stage__c,
        LOS_Documentation_Stage__c,
        LOS_Booking_Stage__c,
        LOS_Default_Application_Status__c
      FROM LOS_Stage__mdt
    ]) {
      if (stage.LOS_Code__c == code)
        stage.LOS_Default_Application_Status__c = status;
      rows.add(stage);
    }
    LOS_ConfigurationService.testData.put('Stage', rows);
    LOS_ConfigurationService.reset();
  }
  private static void assertStatus(
    LOS_ApplicationDTO app,
    String stage,
    String status
  ) {
    Assert.areEqual(stage, app.stageCode);
    Assert.areEqual(status, app.status);
    Assert.areEqual(
      LOS_ConfigurationService.getStage(stage).defaultApplicationStatus,
      app.status
    );
  }
  @IsTest
  static void forwardStatusesFollowConfiguration() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      assertStatus(app, 'Draft', 'In Progress');
      app = LOS_TestData.move(app, 'Draft_To_Underwriting');
      assertStatus(app, 'Underwriting', 'In Progress');
      app = LOS_TestData.move(app, 'Underwriting_To_RM_TL_Review');
      assertStatus(app, 'RM_TL_Review', 'In Review');
      app = LOS_TestData.move(app, 'RM_TL_Review_To_Credit_Review');
      assertStatus(app, 'Credit_Review', 'In Review');
      app = LOS_TestData.move(app, 'Credit_Review_To_Approved');
      assertStatus(app, 'Approved', 'Approved');
      Assert.areEqual(0, app.reworkNumber);
    }
  }
  @IsTest
  static void configuredCustomStatusNeedsNoCodeChange() {
    overrideStatus('Draft', 'Test Custom Business State');
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      assertStatus(app, 'Draft', 'Test Custom Business State');
      overrideStatus('Underwriting', 'Test Destination State');
      assertStatus(
        LOS_TestData.move(app, 'Draft_To_Underwriting'),
        'Underwriting',
        'Test Destination State'
      );
    }
  }
  @IsTest
  static void reworkStatusAndNumberRemainIndependent() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.atReview(true);
      Test.startTest();
      app = LOS_TestData.move(app, 'Credit_Review_To_Underwriting');
      assertStatus(app, 'Underwriting', 'In Progress');
      Assert.areEqual(1, app.reworkNumber);
      app = LOS_TestData.move(app, 'Underwriting_To_RM_TL_Review');
      assertStatus(app, 'RM_TL_Review', 'In Review');
      Assert.areEqual(1, app.reworkNumber);
      app = LOS_TestData.move(app, 'RM_TL_Review_To_Credit_Review');
      Assert.areEqual(1, app.reworkNumber);
      app = LOS_TestData.move(app, 'Credit_Review_To_Draft');
      assertStatus(app, 'Draft', 'In Progress');
      Assert.areEqual(2, app.reworkNumber);
      Test.stopTest();
    }
  }
  @IsTest
  static void missingInitialStatusLeavesNoRecords() {
    overrideStatus('Draft', null);
    System.runAs(LOS_TestData.actor()) {
      try {
        LOS_TestData.createApp();
        Assert.fail('Expected missing status failure');
      } catch (LOS_ConfigurationException e) {
        Assert.isTrue(e.getMessage().contains('status'));
      }
      Assert.areEqual(0, [SELECT COUNT() FROM LOS_Credit_Application__c]);
      Assert.areEqual(0, [SELECT COUNT() FROM LOS_Lifecycle_History__c]);
      Assert.areEqual(0, [SELECT COUNT() FROM LOS_Stage_TAT__c]);
    }
  }
  @IsTest
  static void invalidDestinationStatusPreservesRuntime() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      Id intervalId = LOS_TestData.open(app.applicationId).Id;
      for (
        String invalid : new List<String>{
          null,
          ' ',
          ' Padded ',
          'x'.repeat(256)
        }
      ) {
        overrideStatus('Underwriting', invalid);
        try {
          LOS_TestData.move(app, 'Draft_To_Underwriting');
          Assert.fail('Expected invalid status failure');
        } catch (LOS_ConfigurationException e) {
          Assert.isTrue(e.getMessage().contains('status'));
        }
        LOS_Credit_Application__c stored = [
          SELECT
            LOS_Current_Stage__c,
            LOS_Status__c,
            LOS_Runtime_Version__c,
            LOS_Rework_Count__c
          FROM LOS_Credit_Application__c
          WHERE Id = :app.applicationId
        ];
        Assert.areEqual(app.stageCode, stored.LOS_Current_Stage__c);
        Assert.areEqual(app.status, stored.LOS_Status__c);
        Assert.areEqual(app.version, stored.LOS_Runtime_Version__c);
        Assert.areEqual(0, stored.LOS_Rework_Count__c);
        Assert.areEqual(intervalId, LOS_TestData.open(app.applicationId).Id);
        Assert.areEqual(1, [SELECT COUNT() FROM LOS_Lifecycle_History__c]);
        Assert.areEqual(1, [SELECT COUNT() FROM LOS_Stage_TAT__c]);
        Assert.areEqual(0, [SELECT COUNT() FROM LOS_TAT_Pause__c]);
      }
    }
  }
  @IsTest
  static void teamRequiresUserOnInsertAndUpdate() {
    System.runAs(LOS_TestData.actor()) {
      LOS_Application_Team__c team = new LOS_Application_Team__c(
        LOS_Credit_Application__c = LOS_TestData.createApp().applicationId,
        LOS_Persona_Code__c = 'TEST_ROLE',
        LOS_Access_Level__c = 'TEST_ACCESS',
        LOS_Active__c = true
      );
      Database.SaveResult missing = Database.insert(
        team,
        false,
        AccessLevel.SYSTEM_MODE
      );
      Assert.isFalse(missing.isSuccess());
      Assert.areEqual(
        StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
        missing.getErrors()[0].getStatusCode()
      );
      Assert.isTrue(
        missing.getErrors()[0].getMessage().contains('User is required')
      );
      team.LOS_User__c = UserInfo.getUserId();
      insert as system team;
      team.LOS_User__c = null;
      Database.SaveResult removed = Database.update(
        team,
        false,
        AccessLevel.SYSTEM_MODE
      );
      Assert.isFalse(removed.isSuccess());
      Assert.areEqual(
        UserInfo.getUserId(),
        [SELECT LOS_User__c FROM LOS_Application_Team__c WHERE Id = :team.Id]
        .LOS_User__c
      );
    }
  }
  @IsTest
  static void registryResolvesOnlyControlledKeys() {
    Accept hook = new Accept();
    LOS_ValidationRegistry.registerTestHook('TEST_ALLOWED', hook);
    Assert.areEqual(hook, LOS_ValidationRegistry.resolve('TEST_ALLOWED'));
    for (
      String code : new List<String>{
        null,
        'UNKNOWN',
        'LOS_ArchitectureHardeningTest.Accept',
        'System.Http'
      }
    ) {
      try {
        LOS_ValidationRegistry.resolve(code);
        Assert.fail('Arbitrary key must fail');
      } catch (LOS_ConfigurationException e) {
        Assert.isTrue(e.getMessage().contains('not registered'));
      }
    }
    for (String code : new List<String>{ null, ' ', 'TEST_ALLOWED' }) {
      try {
        LOS_ValidationRegistry.registerTestHook(code, hook);
        Assert.fail('Invalid registration must fail');
      } catch (LOS_ConfigurationException e) {
        Assert.isTrue(e.getMessage().contains('registration'));
      }
    }
    try {
      LOS_ValidationRegistry.registerTestHook('NULL_HOOK', null);
      Assert.fail('Null hook must fail');
    } catch (LOS_ConfigurationException e) {
      Assert.isNotNull(e);
    }
  }
}
