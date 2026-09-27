@IsTest
private class LOS_SecurityTest {
  @TestSetup
  static void setup() {
    LOS_TestData.setup();
  }
  @IsTest
  static void permissionDeniedAndClientMessagesAreSafe() {
    System.runAs(LOS_TestData.denied()) {
      try {
        LOS_ApplicationService.createApplications(
          new List<LOS_ApplicationService.CreateRequest>{
            new LOS_ApplicationService.CreateRequest(
              UserInfo.getUserId(),
              'New'
            )
          }
        );
        Assert.fail('Expected failure');
      } catch (LOS_SecurityException e) {
        Assert.isTrue(e.getMessage().contains('not permitted'));
      }
      try {
        LOS_ApplicationService.createApplication(
          UserInfo.getUserId(),
          'New',
          null
        );
        Assert.fail('Expected failure');
      } catch (AuraHandledException e) {
        Assert.isFalse(e.getMessage().contains('SELECT'));
      }
      try {
        LOS_LifecycleService.getAvailableTransitions(UserInfo.getUserId());
        Assert.fail('Expected failure');
      } catch (AuraHandledException e) {
        Assert.isTrue(e.getMessage().contains('not permitted'));
      }
    }
  }
  @IsTest
  static void customPermissionAloneDoesNotGrantCRUD() {
    PermissionSet onlyRuntime = new PermissionSet(
      Name = 'LOS_Test_Runtime_Only',
      Label = 'Test Runtime Only'
    );
    insert as system onlyRuntime;
    insert as system new SetupEntityAccess(
      ParentId = onlyRuntime.Id,
      SetupEntityId = [
        SELECT Id
        FROM CustomPermission
        WHERE DeveloperName = 'LOS_Use_Runtime'
        LIMIT 1
      ]
      .Id
    );
    insert as system new PermissionSetAssignment(
      AssigneeId = LOS_TestData.denied().Id,
      PermissionSetId = onlyRuntime.Id
    );
    System.runAs(LOS_TestData.denied()) {
      Assert.isTrue(FeatureManagement.checkPermission('LOS_Use_Runtime'));
      try {
        LOS_ApplicationService.createApplications(
          new List<LOS_ApplicationService.CreateRequest>{
            new LOS_ApplicationService.CreateRequest(
              UserInfo.getUserId(),
              'New'
            )
          }
        );
        Assert.fail('Expected failure');
      } catch (LOS_SecurityException e) {
        Assert.isTrue(e.getMessage().contains('required application access'));
      }
    }
  }
  @IsTest
  static void recordAccessIsRequiredAndSharedParentAuthorizesChildren() {
    User actor = LOS_TestData.actor();
    User other = LOS_TestData.denied();
    insert as system new PermissionSetAssignment(
      AssigneeId = other.Id,
      PermissionSetId = [
        SELECT Id
        FROM PermissionSet
        WHERE Name = 'LOS_Lending_User'
        LIMIT 1
      ]
      .Id
    );
    LOS_ApplicationDTO app;
    System.runAs(actor) {
      app = LOS_TestData.createApp();
    }
    System.runAs(other) {
      try {
        LOS_TestData.move(app, 'Draft_To_Underwriting');
        Assert.fail('Expected failure');
      } catch (LOS_SecurityException e) {
        Assert.isTrue(e.getMessage().contains('edit access'));
      }
    }
    System.runAs(actor) {
      insert as system new LOS_Credit_Application__Share(
        ParentId = app.applicationId,
        UserOrGroupId = other.Id,
        AccessLevel = 'Edit',
        RowCause = 'Manual'
      );
    }
    System.runAs(other) {
      Assert.areEqual(
        0,
        [
          SELECT COUNT()
          FROM LOS_Stage_TAT__c
          WHERE LOS_Application__c = :app.applicationId
          WITH USER_MODE
        ]
      );
      Assert.isNotNull(
        LOS_TATService.getCurrentTAT(app.applicationId).stageTATId
      );
      LOS_ApplicationDTO moved = LOS_TestData.move(
        app,
        'Draft_To_Underwriting'
      );
      Assert.areEqual('Underwriting', moved.stageCode);
    }
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM LOS_Stage_TAT__c
        WHERE
          LOS_Application__c = :app.applicationId
          AND LOS_End_Date_Time__c = NULL
      ]
    );
  }
  @IsTest
  static void directApplicationAuditAndTATWritesFailEvenForAdmin() {
    LOS_ApplicationDTO app;
    System.runAs(LOS_TestData.actor()) {
      app = LOS_TestData.createApp();
    }
    List<SObject> attempts = new List<SObject>{
      new LOS_Credit_Application__c(
        Id = app.applicationId,
        LOS_Current_Stage__c = 'Credit_Review'
      ),
      new LOS_Stage_TAT__c(
        Id = LOS_TestData.open(app.applicationId).Id,
        LOS_Paused_Minutes__c = 500
      )
    };
    for (SObject row : attempts) {
      Database.SaveResult result = Database.update(
        row,
        false,
        AccessLevel.SYSTEM_MODE
      );
      Assert.isFalse(result.isSuccess());
      Assert.isTrue(
        result.getErrors()[0].getMessage().contains('controlled LOS')
      );
    }
    LOS_Lifecycle_History__c event = [
      SELECT Id
      FROM LOS_Lifecycle_History__c
      WHERE LOS_Credit_Application__c = :app.applicationId
      LIMIT 1
    ];
    Assert.isFalse(
      Database.delete(event, false, AccessLevel.SYSTEM_MODE).isSuccess()
    );
    event.LOS_Comments__c = 'changed';
    Assert.isFalse(
      Database.update(event, false, AccessLevel.SYSTEM_MODE).isSuccess()
    );
    Assert.isFalse(
      Database.insert(
          new LOS_Lifecycle_History__c(
            LOS_Credit_Application__c = app.applicationId,
            LOS_To_Stage__c = 'Draft',
            LOS_Transition_Type__c = 'Initial',
            LOS_Transition_Date_Time__c = System.now(),
            LOS_Performed_By__c = UserInfo.getUserId()
          ),
          false,
          AccessLevel.SYSTEM_MODE
        )
        .isSuccess()
    );
    Assert.isFalse(
      Database.insert(
          new LOS_TAT_Pause__c(
            LOS_Application__c = app.applicationId,
            LOS_Stage_TAT__c = LOS_TestData.open(app.applicationId).Id,
            LOS_Pause_Reason__c = 'fake',
            LOS_Pause_Start__c = System.now()
          ),
          false,
          AccessLevel.SYSTEM_MODE
        )
        .isSuccess()
    );
    Assert.isFalse(
      Database.delete(
          new LOS_Credit_Application__c(Id = app.applicationId),
          false,
          AccessLevel.SYSTEM_MODE
        )
        .isSuccess()
    );
    Database.SaveResult assignment = Database.insert(
      new LOS_Assignment_TAT__c(
        LOS_Application__c = app.applicationId,
        LOS_Stage_TAT__c = LOS_TestData.open(app.applicationId).Id,
        LOS_User__c = UserInfo.getUserId(),
        LOS_Assignment_Start__c = System.now(),
        LOS_Assignment_Type__c = 'TEST'
      ),
      false,
      AccessLevel.SYSTEM_MODE
    );
    Assert.isFalse(assignment.isSuccess());
    Assert.isTrue(
      assignment.getErrors()[0].getMessage().contains('controlled LOS')
    );
    Assert.isTrue(
      LOS_Stage_TAT__c.LOS_Open_Context_Key__c.getDescribe().isUnique()
    );
    Assert.isTrue(
      LOS_TAT_Pause__c.LOS_Open_Context_Key__c.getDescribe().isUnique()
    );
    try {
      LOS_RuntimeWriter.write(
        new List<SObject>{ new Account(Name = 'Unsupported') },
        true
      );
      Assert.fail('Expected failure');
    } catch (LOS_SecurityException e) {
      Assert.isNotNull(e);
    }
    try {
      LOS_RuntimeWriter.write(
        new List<SObject>{
          new LOS_Credit_Application__c(
            Id = app.applicationId,
            LOS_Rework_Count__c = 100
          )
        },
        false
      );
      Assert.fail('Expected failure');
    } catch (DmlException e) {
      Assert.isTrue(e.getMessage().contains('controlled LOS'));
    }
  }
  @IsTest
  static void availableTransitionsAndSingleFacadeUseVersion() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_ApplicationService.createApplication(
        LOS_TestData.relationship().Id,
        'New',
        null
      );
      List<LOS_TransitionDTO> choices = LOS_LifecycleService.getAvailableTransitions(
        app.applicationId
      );
      Assert.areEqual(1, choices.size());
      Assert.areEqual(0, choices[0].expectedVersion);
      app = LOS_LifecycleService.transitionApplication(
        app.applicationId,
        choices[0].code,
        choices[0].expectedVersion,
        null,
        null
      );
      Assert.areEqual('Underwriting', app.stageCode);
      try {
        LOS_LifecycleService.transitionApplication(
          app.applicationId,
          choices[0].code,
          choices[0].expectedVersion,
          null,
          null
        );
        Assert.fail('Expected failure');
      } catch (AuraHandledException e) {
        Assert.isTrue(e.getMessage().contains('Refresh'));
      }
    }
  }
}
