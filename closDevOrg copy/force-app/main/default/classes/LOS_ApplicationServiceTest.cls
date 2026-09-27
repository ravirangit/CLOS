@IsTest
private class LOS_ApplicationServiceTest {
  @TestSetup
  static void setup() {
    LOS_TestData.setup();
  }
  @IsTest
  static void createsContextHistoryAndInitialTAT() {
    System.runAs(LOS_TestData.actor()) {
      Test.startTest();
      LOS_ApplicationDTO dto = LOS_TestData.createApp();
      Test.stopTest();
      LOS_Credit_Application__c app = [
        SELECT
          LOS_Current_Stage__c,
          LOS_Status__c,
          LOS_Organization_Unit__c,
          LOS_Primary_RM__c,
          LOS_Business_Unit_Snapshot__c,
          LOS_Segment_Snapshot__c,
          LOS_Branch_Snapshot__c,
          LOS_Rework_Count__c,
          LOS_Runtime_Version__c
        FROM LOS_Credit_Application__c
        WHERE Id = :dto.applicationId
      ];
      Assert.areEqual('Draft', dto.stageCode);
      Assert.areEqual('Draft', app.LOS_Status__c);
      Assert.areEqual(0, app.LOS_Rework_Count__c);
      Assert.areEqual(0, dto.version);
      Assert.isNotNull(dto.applicationNumber);
      Assert.areEqual(
        LOS_TestData.relationship().LOS_Primary_Organization_Unit__c,
        app.LOS_Organization_Unit__c
      );
      Assert.areEqual(UserInfo.getUserId(), app.LOS_Primary_RM__c);
      Assert.areEqual('TEST_BU', app.LOS_Business_Unit_Snapshot__c);
      Assert.areEqual('TEST_SEGMENT', app.LOS_Segment_Snapshot__c);
      Assert.areEqual('TEST_BRANCH', app.LOS_Branch_Snapshot__c);
      LOS_Lifecycle_History__c event = [
        SELECT
          LOS_From_Stage__c,
          LOS_To_Stage__c,
          LOS_Transition_Type__c,
          LOS_Performed_By__c,
          LOS_Rework_Number__c
        FROM LOS_Lifecycle_History__c
        WHERE LOS_Credit_Application__c = :dto.applicationId
      ];
      Assert.isNull(event.LOS_From_Stage__c);
      Assert.areEqual('Draft', event.LOS_To_Stage__c);
      Assert.areEqual('Initial', event.LOS_Transition_Type__c);
      Assert.areEqual(UserInfo.getUserId(), event.LOS_Performed_By__c);
      Assert.areEqual(0, event.LOS_Rework_Number__c);
      Assert.areEqual(
        'Draft',
        LOS_TestData.open(dto.applicationId).LOS_Stage__c
      );
    }
  }
  @IsTest
  static void rejectsInactiveRelationship() {
    LOS_Relationship__c row = LOS_TestData.relationship();
    row.LOS_Active__c = false;
    update as system row;
    System.runAs(LOS_TestData.actor()) {
      try {
        LOS_TestData.createApp();
        Assert.fail('Expected failure');
      } catch (LOS_ValidationException e) {
        Assert.isTrue(e.getMessage().contains('inactive'));
      }
      Assert.areEqual(0, [SELECT COUNT() FROM LOS_Credit_Application__c]);
    }
  }
  @IsTest
  static void rejectsUnknownTypeAndMissingBaseline() {
    System.runAs(LOS_TestData.actor()) {
      for (String code : new List<String>{ 'UNKNOWN', 'Renewal' }) {
        try {
          LOS_ApplicationService.createApplications(
            new List<LOS_ApplicationService.CreateRequest>{
              new LOS_ApplicationService.CreateRequest(
                LOS_TestData.relationship().Id,
                code
              )
            }
          );
          Assert.fail('Expected failure');
        } catch (LOS_Exception e) {
          Assert.isNotNull(e.getMessage());
        }
      }
      Assert.areEqual(0, [SELECT COUNT() FROM LOS_Credit_Application__c]);
    }
  }
  @IsTest
  static void missingRelationshipAndInputsFail() {
    System.runAs(LOS_TestData.actor()) {
      try {
        LOS_ApplicationService.createApplications(null);
        Assert.fail('Expected failure');
      } catch (LOS_ValidationException e) {
        Assert.isNotNull(e);
      }
      try {
        LOS_ApplicationService.createApplications(
          new List<LOS_ApplicationService.CreateRequest>{ null }
        );
        Assert.fail('Expected failure');
      } catch (LOS_ValidationException e) {
        Assert.isNotNull(e);
      }
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
        Assert.isNotNull(e);
      }
    }
  }
  @IsTest
  static void snapshotsDoNotFollowRelationshipChanges() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      LOS_Relationship__c relationship = LOS_TestData.relationship();
      relationship.LOS_Branch_Snapshot__c = 'CHANGED';
      update as system relationship;
      Assert.areEqual(
        'TEST_BRANCH',
        [
          SELECT LOS_Branch_Snapshot__c
          FROM LOS_Credit_Application__c
          WHERE Id = :app.applicationId
        ]
        .LOS_Branch_Snapshot__c
      );
    }
  }
  @IsTest
  static void newConfiguredTypeAndInitialStageRequireNoCode() {
    LOS_Application_Type__mdt typeConfig = new LOS_Application_Type__mdt(
      MasterLabel = 'Test Type',
      LOS_Code__c = 'TEST_ADDITIONAL',
      LOS_Active__c = true,
      LOS_Baseline_Required__c = false
    );
    typeConfig = (LOS_Application_Type__mdt) LOS_TestData.withRelationship(
      typeConfig,
      'LOS_Initial_Stage__r',
      new LOS_Stage__mdt(LOS_Code__c = 'Underwriting')
    );
    LOS_ConfigurationService.testData.put(
      'Application_Type',
      new List<SObject>{ typeConfig }
    );
    LOS_ConfigurationService.reset();
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_ApplicationService.createApplications(
        new List<LOS_ApplicationService.CreateRequest>{
          new LOS_ApplicationService.CreateRequest(
            LOS_TestData.relationship().Id,
            'TEST_ADDITIONAL'
          )
        }
      )[0];
      Assert.areEqual('Underwriting', app.stageCode);
      Assert.areEqual('TEST_ADDITIONAL', app.applicationTypeCode);
    }
  }
  @IsTest
  static void bulkCreationAndTransitionStayBounded() {
    System.runAs(LOS_TestData.actor()) {
      Id relationshipId = LOS_TestData.relationship().Id;
      List<LOS_ApplicationService.CreateRequest> requests = new List<LOS_ApplicationService.CreateRequest>();
      for (Integer i = 0; i < 200; i++)
        requests.add(
          new LOS_ApplicationService.CreateRequest(relationshipId, 'New')
        );
      Test.startTest();
      List<LOS_ApplicationDTO> apps = LOS_ApplicationService.createApplications(
        requests
      );
      List<LOS_LifecycleService.TransitionRequest> transitions = new List<LOS_LifecycleService.TransitionRequest>();
      for (LOS_ApplicationDTO app : apps)
        transitions.add(
          new LOS_LifecycleService.TransitionRequest(
            app.applicationId,
            'Draft_To_Underwriting',
            app.version
          )
        );
      List<LOS_ApplicationDTO> moved = LOS_LifecycleService.transitionApplications(
        transitions
      );
      Assert.isTrue(
        Limits.getQueries() < 40,
        'SOQL must not grow per application'
      );
      Assert.isTrue(
        Limits.getDmlStatements() < 20,
        'DML must not grow per application'
      );
      Test.stopTest();
      Assert.areEqual(200, moved.size());
      Assert.areEqual('Underwriting', moved[199].stageCode);
      Assert.areEqual(400, [SELECT COUNT() FROM LOS_Lifecycle_History__c]);
      Assert.areEqual(
        200,
        [SELECT COUNT() FROM LOS_Stage_TAT__c WHERE LOS_End_Date_Time__c = NULL]
      );
    }
  }
}
