@IsTest
private class LOS_ConfigurationServiceTest {
  @IsTest
  static void activeCatalogsCacheAndUnknownCodes() {
    Assert.areEqual(3, LOS_ConfigurationService.getApplicationTypes().size());
    Assert.areEqual(9, LOS_ConfigurationService.getStages().size());
    Assert.areEqual(
      'Draft',
      LOS_ConfigurationService.getInitialStage('New').code
    );
    Assert.areEqual(
      'Underwriting',
      LOS_ConfigurationService.getTransition('Draft_To_Underwriting', 'New')
        .toStage
    );
    Assert.areEqual(
      1,
      LOS_ConfigurationService.getTransitions('Draft', 'New').size()
    );
    Assert.areEqual(
      0,
      LOS_ConfigurationService.getTransitions('Monitoring', 'New').size()
    );
    Integer queries = Limits.getQueries();
    LOS_ConfigurationService.getStages();
    LOS_ConfigurationService.getApplicationTypes();
    Assert.areEqual(queries, Limits.getQueries());
    List<LOS_ConfigurationService.Config> copy = LOS_ConfigurationService.getStages();
    copy.clear();
    Assert.areEqual(9, LOS_ConfigurationService.getStages().size());
    try {
      LOS_ConfigurationService.getStage('UNKNOWN');
      Assert.fail('Expected failure');
    } catch (LOS_ConfigurationException e) {
      Assert.isNotNull(e);
    }
    LOS_ConfigurationService.getPersonas();
    LOS_ConfigurationService.getWorkspaceSections();
    LOS_ConfigurationService.getWorkspaceActions();
    LOS_ConfigurationService.getSLARules();
    LOS_ConfigurationService.getPauseRules();
    LOS_ConfigurationService.getOrgUnitTypes();
  }
  @IsTest
  static void scopedTransitionOverridesGlobal() {
    LOS_Stage_Transition__mdt globalRule = LOS_TestData.transition(
      'Draft_To_Underwriting'
    );
    LOS_Stage_Transition__mdt scoped = globalRule.clone(
      false,
      true,
      false,
      false
    );
    scoped.LOS_Action_Label__c = 'Scoped Action';
    scoped = (LOS_Stage_Transition__mdt) LOS_TestData.withRelationship(
      scoped,
      'LOS_Application_Type__r',
      new LOS_Application_Type__mdt(LOS_Code__c = 'New')
    );
    LOS_ConfigurationService.testData.put(
      'Stage_Transition',
      new List<SObject>{ globalRule, scoped }
    );
    LOS_ConfigurationService.reset();
    Assert.areEqual(
      'Scoped Action',
      LOS_ConfigurationService.getTransition('Draft_To_Underwriting', 'New')
        .label
    );
    Assert.areNotEqual(
      'Scoped Action',
      LOS_ConfigurationService.getTransition('Draft_To_Underwriting', 'Renewal')
        .label
    );
    Assert.areEqual(
      1,
      LOS_ConfigurationService.getTransitions('Draft', 'New').size()
    );
  }
  @IsTest
  static void inactiveDestinationAndDuplicateCodesFailClosed() {
    LOS_Stage__mdt disabled = new LOS_Stage__mdt(
      MasterLabel = 'Test',
      LOS_Code__c = 'Underwriting',
      LOS_Active__c = false
    );
    LOS_Stage__mdt draft = new LOS_Stage__mdt(
      MasterLabel = 'Draft',
      LOS_Default_Application_Status__c = 'In Progress',
      LOS_Code__c = 'Draft',
      LOS_Active__c = true
    );
    LOS_ConfigurationService.testData.put(
      'Stage',
      new List<SObject>{ draft, disabled }
    );
    LOS_ConfigurationService.reset();
    try {
      LOS_ConfigurationService.getTransition('Draft_To_Underwriting', 'New');
      Assert.fail('Expected failure');
    } catch (LOS_ConfigurationException e) {
      Assert.isNotNull(e);
    }
    LOS_ConfigurationService.testData.put(
      'Stage',
      new List<SObject>{ draft, draft.clone() }
    );
    LOS_ConfigurationService.reset();
    try {
      LOS_ConfigurationService.getStages();
      Assert.fail('Expected failure');
    } catch (LOS_ConfigurationException e) {
      Assert.isTrue(e.getMessage().contains('Duplicate'));
    }
  }
  @IsTest
  static void emptyAndTerminalInitialConfigurationFails() {
    LOS_Application_Type__mdt row = new LOS_Application_Type__mdt(
      MasterLabel = 'Test',
      LOS_Code__c = 'TEST',
      LOS_Active__c = true
    );
    LOS_ConfigurationService.testData.put(
      'Application_Type',
      new List<SObject>{ row }
    );
    LOS_ConfigurationService.reset();
    try {
      LOS_ConfigurationService.getInitialStage('TEST');
      Assert.fail('Expected failure');
    } catch (LOS_ConfigurationException e) {
      Assert.isNotNull(e);
    }
    row = (LOS_Application_Type__mdt) LOS_TestData.withRelationship(
      row,
      'LOS_Initial_Stage__r',
      new LOS_Stage__mdt(LOS_Code__c = 'Monitoring')
    );
    LOS_ConfigurationService.testData.put(
      'Application_Type',
      new List<SObject>{ row }
    );
    LOS_ConfigurationService.reset();
    try {
      LOS_ConfigurationService.getInitialStage('TEST');
      Assert.fail('Expected failure');
    } catch (LOS_ConfigurationException e) {
      Assert.isNotNull(e);
    }
    row.LOS_Code__c = null;
    LOS_ConfigurationService.reset();
    try {
      LOS_ConfigurationService.getApplicationTypes();
      Assert.fail('Expected failure');
    } catch (LOS_ConfigurationException e) {
      Assert.isNotNull(e);
    }
  }
  @IsTest
  static void scopedCatalogsAndSLASelection() {
    LOS_Persona__mdt persona = new LOS_Persona__mdt(
      MasterLabel = 'Test',
      LOS_Code__c = 'TEST_PERSONA',
      LOS_Active__c = true,
      LOS_Display_Label__c = 'Test persona'
    );
    LOS_Org_Unit_Type__mdt unit = new LOS_Org_Unit_Type__mdt(
      MasterLabel = 'Test',
      LOS_Code__c = 'TEST_TYPE',
      LOS_Active__c = true
    );
    LOS_Workspace_Section__mdt section = new LOS_Workspace_Section__mdt(
      MasterLabel = 'Test',
      LOS_Code__c = 'TEST_SECTION',
      LOS_Active__c = true,
      LOS_Component_Key__c = 'test'
    );
    section = (LOS_Workspace_Section__mdt) LOS_TestData.withRelationship(
      section,
      'LOS_Persona__r',
      persona
    );
    section = (LOS_Workspace_Section__mdt) LOS_TestData.withRelationship(
      section,
      'LOS_Stage__r',
      new LOS_Stage__mdt(LOS_Code__c = 'Draft')
    );
    LOS_Workspace_Action__mdt action = new LOS_Workspace_Action__mdt(
      MasterLabel = 'Test',
      LOS_Code__c = 'TEST_ACTION',
      LOS_Active__c = true,
      LOS_Handler_Key__c = 'test'
    );
    action = (LOS_Workspace_Action__mdt) LOS_TestData.withRelationship(
      action,
      'LOS_Section__r',
      section
    );
    LOS_SLA_Rule__mdt sla = new LOS_SLA_Rule__mdt(
      MasterLabel = 'Test',
      LOS_Code__c = 'SLA',
      LOS_Active__c = true,
      LOS_Target_Minutes__c = 20,
      LOS_Priority__c = 2,
      LOS_Effective_From__c = Date.today().addDays(-1),
      LOS_Effective_To__c = Date.today().addDays(1)
    );
    sla = (LOS_SLA_Rule__mdt) LOS_TestData.withRelationship(
      sla,
      'LOS_Persona__r',
      persona
    );
    sla = (LOS_SLA_Rule__mdt) LOS_TestData.withRelationship(
      sla,
      'LOS_Org_Unit_Type__r',
      unit
    );
    LOS_ConfigurationService.testData.put(
      'Persona',
      new List<SObject>{ persona }
    );
    LOS_ConfigurationService.testData.put(
      'Org_Unit_Type',
      new List<SObject>{ unit }
    );
    LOS_ConfigurationService.testData.put(
      'Workspace_Section',
      new List<SObject>{ section }
    );
    LOS_ConfigurationService.testData.put(
      'Workspace_Action',
      new List<SObject>{ action }
    );
    LOS_ConfigurationService.testData.put('SLA_Rule', new List<SObject>{ sla });
    LOS_ConfigurationService.reset();
    Assert.areEqual(
      'TEST_PERSONA',
      LOS_ConfigurationService.getPersonas()[0].code
    );
    Assert.areEqual(
      'TEST_TYPE',
      LOS_ConfigurationService.getOrgUnitTypes()[0].code
    );
    Assert.areEqual(
      'test',
      LOS_ConfigurationService.getWorkspaceSections()[0].componentKey
    );
    Assert.areEqual(
      'TEST_SECTION',
      LOS_ConfigurationService.getWorkspaceActions()[0].section
    );
    Assert.isNull(
      LOS_ConfigurationService.selectSLA(
        'New',
        'Draft',
        'TEST_TYPE',
        new Set<String>(),
        Date.today()
      )
    );
    Assert.areEqual(
      20,
      LOS_ConfigurationService.selectSLA(
          'New',
          'Draft',
          'TEST_TYPE',
          new Set<String>{ 'TEST_PERSONA' },
          Date.today()
        )
        .targetMinutes
    );
    Assert.isNull(
      LOS_ConfigurationService.selectSLA(
        'New',
        'Draft',
        'TEST_TYPE',
        new Set<String>{ 'TEST_PERSONA' },
        Date.today().addDays(2)
      )
    );
    LOS_SLA_Rule__mdt duplicate = sla.clone(false, true, false, false);
    duplicate.LOS_Code__c = 'TIE';
    LOS_ConfigurationService.testData.get('SLA_Rule').add(duplicate);
    LOS_ConfigurationService.reset();
    try {
      LOS_ConfigurationService.selectSLA(
        'New',
        'Draft',
        'TEST_TYPE',
        new Set<String>{ 'TEST_PERSONA' },
        Date.today()
      );
      Assert.fail('Expected failure');
    } catch (LOS_ConfigurationException e) {
      Assert.isTrue(e.getMessage().contains('ambiguous'));
    }
  }
  @IsTest
  static void pauseScopeResolutionAndAmbiguity() {
    LOS_TestData.pauseRule(false);
    LOS_TAT_Pause_Rule__mdt general = (LOS_TAT_Pause_Rule__mdt) LOS_ConfigurationService.testData.get(
      'TAT_Pause_Rule'
    )[0];
    LOS_TAT_Pause_Rule__mdt specific = general.clone(false, true, false, false);
    specific.LOS_Count_Toward_SLA__c = true;
    specific = (LOS_TAT_Pause_Rule__mdt) LOS_TestData.withRelationship(
      specific,
      'LOS_Stage__r',
      new LOS_Stage__mdt(LOS_Code__c = 'Draft')
    );
    LOS_ConfigurationService.testData.get('TAT_Pause_Rule').add(specific);
    LOS_ConfigurationService.reset();
    Assert.isTrue(
      LOS_ConfigurationService.getPauseRule('WAIT_TEST', 'New', 'Draft')
        .countTowardSLA
    );
    Assert.isFalse(
      LOS_ConfigurationService.getPauseRule('WAIT_TEST', 'New', 'Underwriting')
        .countTowardSLA
    );
    LOS_TAT_Pause_Rule__mdt tie = general.clone(false, true, false, false);
    tie = (LOS_TAT_Pause_Rule__mdt) LOS_TestData.withRelationship(
      tie,
      'LOS_Application_Type__r',
      new LOS_Application_Type__mdt(LOS_Code__c = 'New')
    );
    LOS_ConfigurationService.testData.get('TAT_Pause_Rule').add(tie);
    LOS_ConfigurationService.reset();
    try {
      LOS_ConfigurationService.getPauseRule('WAIT_TEST', 'New', 'Draft');
      Assert.fail('Expected failure');
    } catch (LOS_ConfigurationException e) {
      Assert.isTrue(e.getMessage().contains('ambiguous'));
    }
  }
}
