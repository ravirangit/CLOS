@IsTest
private class LOS_WorkspaceServiceTest {
  @TestSetup
  static void setup() {
    LOS_TestData.setup();
    insert as system new PermissionSetAssignment(
      AssigneeId = LOS_TestData.denied().Id,
      PermissionSetId = [
        SELECT Id
        FROM PermissionSet
        WHERE Name = 'LOS_Lending_User'
      ]
      .Id
    );
  }
  @IsTest
  static void workspaceContractAndQueryBound() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      Test.startTest();
      Integer dml = Limits.getDmlStatements();
      LOS_WorkspaceContext ctx = LOS_WorkspaceService.getWorkspace(
        app.applicationId
      );
      Assert.isTrue(Limits.getQueries() < 25);
      Assert.areEqual(dml, Limits.getDmlStatements());
      Assert.isTrue(JSON.serialize(ctx).length() < 50000);
      Test.stopTest();
      Assert.areEqual('Draft', ctx.application.stageCode);
      Assert.areEqual('In Progress', ctx.application.status);
      Assert.areEqual(0, ctx.application.version);
      Assert.areEqual(0, ctx.application.reworkNumber);
      Assert.areEqual('Test Relationship', ctx.relationshipName);
      Assert.isTrue(ctx.canTransition);
      Assert.areEqual(3, ctx.navigationSections.size());
      Assert.areEqual(2, ctx.actions.size());
      Assert.areEqual(1, ctx.availableTransitions.size());
      Assert.areEqual(
        'Draft_To_Underwriting',
        ctx.availableTransitions[0].transitionCode
      );
      Assert.areEqual('Draft', ctx.tat.stageCode);
      Assert.areEqual(1, ctx.lifecycleHistory.size());
      Assert.isFalse(ctx.tat.hasVisiblePause);
      Assert.areEqual(0, ctx.personas.size());
    }
  }
  @IsTest
  static void unauthorizedRecordAndInvalidIdFail() {
    Id appId;
    System.runAs(LOS_TestData.actor()) {
      appId = LOS_TestData.createApp().applicationId;
    }
    System.runAs(LOS_TestData.denied()) {
      Assert.areEqual(0, LOS_WorkspaceService.getApplications().size());
      Assert.areEqual(
        0,
        LOS_WorkspaceService.searchRelationships('Test').size()
      );
      for (Id key : new List<Id>{ appId, null, UserInfo.getUserId() }) {
        try {
          LOS_WorkspaceService.getWorkspace(key);
          Assert.fail('Expected denial');
        } catch (AuraHandledException e) {
          Assert.isFalse(e.getMessage().contains(String.valueOf(appId)));
        }
      }
    }
  }
  @IsTest
  static void readonlySharedApplicationDoesNotGrantChildAccess() {
    Id appId;
    System.runAs(LOS_TestData.actor()) {
      appId = LOS_TestData.createApp().applicationId;
    }
    insert as system new LOS_Credit_Application__Share(
      ParentId = appId,
      UserOrGroupId = LOS_TestData.denied().Id,
      AccessLevel = 'Read',
      RowCause = Schema.LOS_Credit_Application__Share.RowCause.Manual
    );
    System.runAs(LOS_TestData.denied()) {
      LOS_WorkspaceContext ctx = LOS_WorkspaceService.getWorkspace(appId);
      Assert.isFalse(ctx.canTransition);
      Assert.areEqual(0, ctx.availableTransitions.size());
      Assert.areEqual(1, ctx.actions.size());
      Assert.areEqual('REFRESH', ctx.actions[0].handlerKey);
      Assert.areEqual(0, ctx.lifecycleHistory.size());
      Assert.isNull(ctx.tat.id);
      Assert.areEqual(1, LOS_WorkspaceService.getApplications().size());
    }
  }
  @IsTest
  static void reworkReloadAndHistory() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.atReview(true);
      LOS_WorkspaceContext credit = LOS_WorkspaceService.getWorkspace(
        app.applicationId
      );
      Assert.areEqual('In Review', credit.application.status);
      Assert.areEqual(4, credit.availableTransitions.size());
      Test.startTest();
      app = LOS_TestData.move(app, 'Credit_Review_To_Underwriting');
      LOS_WorkspaceContext back = LOS_WorkspaceService.getWorkspace(
        app.applicationId
      );
      Assert.areEqual('Underwriting', back.application.stageCode);
      Assert.areEqual('In Progress', back.application.status);
      Assert.areEqual(1, back.application.reworkNumber);
      Assert.areEqual(app.version, back.application.version);
      Assert.areEqual(app.stageCode, back.tat.stageCode);
      Assert.areEqual(5, back.lifecycleHistory.size());
      Assert.areEqual('Rework', back.lifecycleHistory[0].transitionType);
      for (Integer i = 1; i < back.lifecycleHistory.size(); i++)
        Assert.isTrue(
          back.lifecycleHistory[i - 1].occurredAt >=
          back.lifecycleHistory[i].occurredAt
        );
      Test.stopTest();
    }
  }
  @IsTest
  static void staleWorkspaceVersionCannotOverwrite() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      LOS_WorkspaceContext old = LOS_WorkspaceService.getWorkspace(
        app.applicationId
      );
      Test.startTest();
      LOS_TestData.move(app, 'Draft_To_Underwriting');
      try {
        LOS_LifecycleService.transitionApplication(
          app.applicationId,
          old.actions[1].transitionCode,
          old.application.version,
          null,
          null
        );
        Assert.fail('Expected stale rejection');
      } catch (AuraHandledException e) {
        Assert.areEqual(
          'The application changed. Refresh before retrying.',
          e.getMessage()
        );
      }
      LOS_WorkspaceContext current = LOS_WorkspaceService.getWorkspace(
        app.applicationId
      );
      Test.stopTest();
      Assert.areEqual('Underwriting', current.application.stageCode);
      Assert.areEqual(1, current.application.version);
      Assert.areEqual(2, current.lifecycleHistory.size());
    }
  }
  private static LOS_Workspace_Section__mdt section(String key, String policy) {
    return new LOS_Workspace_Section__mdt(
      MasterLabel = 'Test section',
      LOS_Code__c = 'TEST_SECTION',
      LOS_Display_Label__c = 'Configured title',
      LOS_Active__c = true,
      LOS_Component_Key__c = key,
      LOS_Visibility_Policy_Code__c = policy
    );
  }
  @IsTest
  static void configurationControlsSectionsAndActions() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      LOS_ConfigurationService.testData.put(
        'Workspace_Section',
        new List<SObject>{ section('TAT', null) }
      );
      LOS_Workspace_Action__mdt action = new LOS_Workspace_Action__mdt(
        MasterLabel = 'Reload',
        LOS_Code__c = 'RELOAD',
        LOS_Display_Label__c = 'Reload context',
        LOS_Active__c = true,
        LOS_Handler_Key__c = 'REFRESH'
      );
      LOS_ConfigurationService.testData.put(
        'Workspace_Action',
        new List<SObject>{ action }
      );
      LOS_ConfigurationService.reset();
      LOS_WorkspaceContext ctx = LOS_WorkspaceService.getWorkspace(
        app.applicationId
      );
      Assert.areEqual(1, ctx.navigationSections.size());
      Assert.areEqual('Configured title', ctx.navigationSections[0].label);
      Assert.areEqual('TAT', ctx.navigationSections[0].componentKey);
      Assert.areEqual('Reload context', ctx.actions[0].label);
    }
  }
  @IsTest
  static void unregisteredComponentsPoliciesAndHandlersFailClosed() {
    System.runAs(LOS_TestData.actor()) {
      Id appId = LOS_TestData.createApp().applicationId;
      for (
        LOS_Workspace_Section__mdt bad : new List<LOS_Workspace_Section__mdt>{
          section('arbitraryComponent', null),
          section('OVERVIEW', 'UNKNOWN_POLICY')
        }
      ) {
        LOS_ConfigurationService.testData.put(
          'Workspace_Section',
          new List<SObject>{ bad }
        );
        LOS_ConfigurationService.reset();
        try {
          LOS_WorkspaceService.getWorkspace(appId);
          Assert.fail('Expected configuration failure');
        } catch (AuraHandledException e) {
          Assert.isTrue(e.getMessage().contains('unsupported'));
        }
      }
      LOS_ConfigurationService.testData.put(
        'Workspace_Section',
        new List<SObject>()
      );
      LOS_ConfigurationService.testData.put(
        'Workspace_Action',
        new List<SObject>{
          new LOS_Workspace_Action__mdt(
            MasterLabel = 'Bad',
            LOS_Code__c = 'BAD',
            LOS_Active__c = true,
            LOS_Handler_Key__c = 'eval'
          )
        }
      );
      LOS_ConfigurationService.reset();
      try {
        LOS_WorkspaceService.getWorkspace(appId);
        Assert.fail('Expected handler failure');
      } catch (AuraHandledException e) {
        Assert.isTrue(e.getMessage().contains('unsupported'));
      }
    }
  }
  @IsTest
  static void personaSetScopesNeverGrantsAccess() {
    System.runAs(LOS_TestData.actor()) {
      LOS_ApplicationDTO app = LOS_TestData.createApp();
      LOS_ConfigurationService.testData.put(
        'Persona',
        new List<SObject>{
          new LOS_Persona__mdt(
            MasterLabel = 'Test',
            LOS_Code__c = 'TEST_PERSONA',
            LOS_Active__c = true,
            LOS_Display_Label__c = 'Test'
          )
        }
      );
      LOS_Workspace_Section__mdt scoped = (LOS_Workspace_Section__mdt) LOS_TestData.withRelationship(
        section('OVERVIEW', null),
        'LOS_Persona__r',
        new LOS_Persona__mdt(LOS_Code__c = 'TEST_PERSONA')
      );
      LOS_ConfigurationService.testData.put(
        'Workspace_Section',
        new List<SObject>{ scoped }
      );
      LOS_ConfigurationService.reset();
      Assert.areEqual(
        0,
        LOS_WorkspaceService.getWorkspace(app.applicationId)
          .navigationSections.size()
      );
      insert as system new LOS_Application_Team__c(
        LOS_Credit_Application__c = app.applicationId,
        LOS_User__c = UserInfo.getUserId(),
        LOS_Persona_Code__c = 'TEST_PERSONA',
        LOS_Access_Level__c = 'TEST',
        LOS_Active__c = true
      );
      Test.startTest();
      LOS_WorkspaceContext ctx = LOS_WorkspaceService.getWorkspace(
        app.applicationId
      );
      Test.stopTest();
      Assert.areEqual(new List<String>{ 'TEST_PERSONA' }, ctx.personas);
      Assert.areEqual(1, ctx.navigationSections.size());
    }
  }
  @IsTest
  static void relationshipSearchIsBoundedAndEscaped() {
    System.runAs(LOS_TestData.actor()) {
      LOS_Relationship__c base = [
        SELECT LOS_Account__c, LOS_Primary_Organization_Unit__c
        FROM LOS_Relationship__c
        WITH SYSTEM_MODE
        LIMIT 1
      ];
      List<LOS_Relationship__c> rows = new List<LOS_Relationship__c>();
      for (Integer i = 0; i < 25; i++)
        rows.add(
          new LOS_Relationship__c(
            Name = 'Search Test ' + i,
            LOS_Relationship_Number__c = 'SEARCH' + i,
            LOS_Account__c = base.LOS_Account__c,
            LOS_Primary_Organization_Unit__c = base.LOS_Primary_Organization_Unit__c,
            LOS_Active__c = true
          )
        );
      rows.add(
        new LOS_Relationship__c(
          Name = 'O\'Brien_%',
          LOS_Relationship_Number__c = 'SPECIAL',
          LOS_Account__c = base.LOS_Account__c,
          LOS_Primary_Organization_Unit__c = base.LOS_Primary_Organization_Unit__c,
          LOS_Active__c = true
        )
      );
      insert as system rows;
      Test.startTest();
      Assert.areEqual(0, LOS_WorkspaceService.searchRelationships('a').size());
      Assert.areEqual(
        20,
        LOS_WorkspaceService.searchRelationships('Search').size()
      );
      Assert.areEqual(
        1,
        LOS_WorkspaceService.searchRelationships('O\'Brien_%').size()
      );
      Assert.areEqual(
        0,
        LOS_WorkspaceService.searchRelationships('%\' OR Name != \'').size()
      );
      Test.stopTest();
    }
  }
  @IsTest
  static void creationOptionsBaselineAndListBounds() {
    System.runAs(LOS_TestData.actor()) {
      Assert.areEqual(3, LOS_WorkspaceService.getApplicationTypes().size());
      Assert.areEqual(
        0,
        LOS_WorkspaceService.searchBaselines(
            LOS_TestData.relationship().Id,
            'AP'
          )
          .size()
      );
      List<LOS_ApplicationService.CreateRequest> requests = new List<LOS_ApplicationService.CreateRequest>();
      Id relationshipId = LOS_TestData.relationship().Id;
      for (Integer i = 0; i < 55; i++)
        requests.add(
          new LOS_ApplicationService.CreateRequest(relationshipId, 'New')
        );
      Test.startTest();
      List<LOS_ApplicationDTO> apps = LOS_ApplicationService.createApplications(
        requests
      );
      Assert.areEqual(50, LOS_WorkspaceService.getApplications().size());
      LOS_RuntimeService.persist(
        new List<SObject>{
          new LOS_Credit_Application__c(
            Id = apps[0].applicationId,
            LOS_Approved_Date__c = System.now()
          )
        },
        false
      );
      Assert.areEqual(
        1,
        LOS_WorkspaceService.searchBaselines(
            LOS_TestData.relationship().Id,
            'APP'
          )
          .size()
      );
      Test.stopTest();
    }
  }
}
