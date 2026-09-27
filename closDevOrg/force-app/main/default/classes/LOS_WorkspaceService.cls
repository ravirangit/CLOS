/** Read-only UI orchestration. All transaction reads enforce sharing, CRUD and FLS in USER_MODE. */
public with sharing class LOS_WorkspaceService {
  private static final Set<String> COMPONENTS = new Set<String>{
    'OVERVIEW',
    'LIFECYCLE',
    'TAT'
  };
  private static void requireRead() {
    LOS_Security.requireRuntime(false);
  }
  private static void applicationIdRequired(Id value) {
    if (
      value == null ||
      value.getSObjectType() != LOS_Credit_Application__c.SObjectType
    )
      throw new LOS_ValidationException('Select a credit application.');
  }
  private static String clip(String value) {
    return value == null ? null : value.left(500);
  }
  private static Boolean matches(String scope, String value) {
    return String.isBlank(scope) || scope == value;
  }
  private static Boolean applies(
    LOS_ConfigurationService.Config config,
    LOS_Credit_Application__c app,
    Set<String> personas
  ) {
    return matches(config.applicationType, app.LOS_Application_Type__c) &&
      matches(config.stage, app.LOS_Current_Stage__c) &&
      (String.isBlank(config.persona) || personas.contains(config.persona));
  }
  private static List<LOS_ConfigurationService.Config> ordered(
    List<LOS_ConfigurationService.Config> values
  ) {
    // Catalogs are small; stable insertion ordering avoids mutable shared cached wrappers.
    List<LOS_ConfigurationService.Config> result = new List<LOS_ConfigurationService.Config>();
    for (LOS_ConfigurationService.Config item : values) {
      Integer pos = 0;
      Decimal rank = item.sequence == null ? 0 : item.sequence;
      while (
        pos < result.size() &&
        (result[pos].sequence == null ? 0 : result[pos].sequence) <= rank
      )
        pos++;
      if (pos == result.size())
        result.add(item);
      else
        result.add(pos, item);
    }
    return result;
  }
  private static Set<String> personas(LOS_Credit_Application__c app) {
    Set<String> result = new Set<String>();
    Date today = LOS_BusinessTimeService.nowValue().dateGmt();
    for (LOS_User_Org_Assignment__c row : [
      SELECT LOS_Persona_Code__c
      FROM LOS_User_Org_Assignment__c
      WHERE
        LOS_User__c = :UserInfo.getUserId()
        AND LOS_Organization_Unit__c = :app.LOS_Organization_Unit__c
        AND LOS_Active__c = TRUE
        AND (LOS_Effective_From__c = NULL
        OR LOS_Effective_From__c <= :today)
        AND (LOS_Effective_To__c = NULL
        OR LOS_Effective_To__c >= :today)
      WITH USER_MODE
      LIMIT 201
    ])
      result.add(row.LOS_Persona_Code__c);
    for (LOS_Application_Team__c row : [
      SELECT LOS_Persona_Code__c
      FROM LOS_Application_Team__c
      WHERE
        LOS_User__c = :UserInfo.getUserId()
        AND LOS_Credit_Application__c = :app.Id
        AND LOS_Active__c = TRUE
        AND (LOS_Effective_From__c = NULL
        OR LOS_Effective_From__c <= :today)
        AND (LOS_Effective_To__c = NULL
        OR LOS_Effective_To__c >= :today)
      WITH USER_MODE
      LIMIT 201
    ])
      result.add(row.LOS_Persona_Code__c);
    Set<String> active = new Set<String>();
    for (
      LOS_ConfigurationService.Config item : LOS_ConfigurationService.getPersonas()
    )
      active.add(item.code);
    result.retainAll(active);
    return result;
  }
  @AuraEnabled(cacheable=true)
  public static LOS_WorkspaceContext getWorkspace(Id applicationId) {
    try {
      requireRead();
      applicationIdRequired(applicationId);
      List<LOS_Credit_Application__c> rows = [
        SELECT
          Id,
          Name,
          LOS_Application_Type__c,
          LOS_Current_Stage__c,
          LOS_Status__c,
          LOS_Current_Rework_Number__c,
          LOS_Rework_Count__c,
          LOS_Runtime_Version__c,
          LOS_Active__c,
          LOS_Relationship__c,
          LOS_Relationship__r.Name,
          LOS_Primary_RM__r.Name,
          LOS_Current_Owner_User__r.Name,
          LOS_Current_Queue_Key__c,
          LOS_Organization_Unit__c,
          LOS_Organization_Unit__r.Name,
          LOS_Business_Unit_Snapshot__c,
          LOS_Segment_Snapshot__c,
          LOS_Branch_Snapshot__c
        FROM LOS_Credit_Application__c
        WHERE Id = :applicationId
        WITH USER_MODE
        LIMIT 1
      ];
      if (rows.isEmpty())
        throw new LOS_SecurityException(
          'The application is unavailable or you do not have access.'
        );
      LOS_Credit_Application__c app = rows[0];
      LOS_ConfigurationService.Config stage = LOS_ConfigurationService.getStage(
        app.LOS_Current_Stage__c
      );
      LOS_WorkspaceContext context = new LOS_WorkspaceContext();
      context.application = new LOS_ApplicationDTO(app);
      context.relationshipId = app.LOS_Relationship__c;
      context.relationshipName = app.LOS_Relationship__r.Name;
      context.stageLabel = stage.label;
      context.applicationTypeLabel = LOS_ConfigurationService.getApplicationType(
          app.LOS_Application_Type__c
        )
        .label;
      context.reworkCount = app.LOS_Rework_Count__c;
      context.primaryRM = app.LOS_Primary_RM__r.Name;
      context.currentOwnerUser = app.LOS_Current_Owner_User__r.Name;
      context.currentQueueKey = app.LOS_Current_Queue_Key__c;
      context.organizationUnit = app.LOS_Organization_Unit__r.Name;
      context.businessUnitSnapshot = app.LOS_Business_Unit_Snapshot__c;
      context.segmentSnapshot = app.LOS_Segment_Snapshot__c;
      context.branchSnapshot = app.LOS_Branch_Snapshot__c;
      context.loadedAt = LOS_BusinessTimeService.nowValue();
      context.canTransition =
        app.LOS_Active__c && LOS_Security.canEditRecord(app.Id);
      Set<String> roles = personas(app);
      context.personas = new List<String>(roles);
      context.personas.sort();
      context.health = new List<String>{
        'Current stage configuration resolved',
        'State loaded from server; each command rechecks version'
      };
      context.navigationSections = new List<LOS_WorkspaceSectionDTO>();
      Set<String> visibleSections = new Set<String>();
      for (
        LOS_ConfigurationService.Config config : ordered(
          LOS_ConfigurationService.getWorkspaceSections()
        )
      ) {
        if (!applies(config, app, roles))
          continue;
        if (
          !String.isBlank(config.visibilityPolicy) ||
          !COMPONENTS.contains(config.componentKey)
        )
          throw new LOS_ConfigurationException(
            'A workspace section uses an unsupported component or visibility policy.'
          );
        LOS_WorkspaceSectionDTO item = new LOS_WorkspaceSectionDTO();
        item.code = config.code;
        item.label = config.label;
        item.componentKey = config.componentKey;
        item.sequence = config.sequence;
        context.navigationSections.add(item);
        visibleSections.add(item.code);
      }
      context.availableTransitions = new List<LOS_WorkspaceActionDTO>();
      Map<String, LOS_WorkspaceActionDTO> transitions = new Map<String, LOS_WorkspaceActionDTO>();
      if (context.canTransition)
        for (
          LOS_ConfigurationService.Config config : LOS_ConfigurationService.getTransitions(
            app.LOS_Current_Stage__c,
            app.LOS_Application_Type__c
          )
        ) {
          LOS_WorkspaceActionDTO item = new LOS_WorkspaceActionDTO();
          item.code = config.code;
          item.transitionCode = config.code;
          item.label = config.label;
          item.handlerKey = 'TRANSITION';
          item.transitionType = config.transitionType;
          item.requiresReason = config.requiresReason;
          item.requiresValidation = config.requiresValidation;
          item.requiresConfirmation = false;
          item.expectedVersion = app.LOS_Runtime_Version__c;
          context.availableTransitions.add(item);
          transitions.put(item.transitionCode, item);
        }
      context.actions = new List<LOS_WorkspaceActionDTO>();
      for (
        LOS_ConfigurationService.Config config : ordered(
          LOS_ConfigurationService.getWorkspaceActions()
        )
      ) {
        if (
          !applies(config, app, roles) ||
          (!String.isBlank(config.section) &&
          !visibleSections.contains(config.section))
        )
          continue;
        if (
          !String.isBlank(config.authorizationPolicy) ||
          !new Set<String>{ 'TRANSITION', 'REFRESH' }
            .contains(config.handlerKey)
        )
          throw new LOS_ConfigurationException(
            'A workspace action uses an unsupported handler or authorization policy.'
          );
        LOS_WorkspaceActionDTO item;
        if (config.handlerKey == 'TRANSITION') {
          if (String.isBlank(config.transition))
            throw new LOS_ConfigurationException(
              'A lifecycle action requires a configured transition.'
            );
          if (!transitions.containsKey(config.transition))
            continue;
          item = (LOS_WorkspaceActionDTO) JSON.deserialize(
            JSON.serialize(transitions.get(config.transition)),
            LOS_WorkspaceActionDTO.class
          );
        } else {
          item = new LOS_WorkspaceActionDTO();
          item.label = config.label;
          item.handlerKey = 'REFRESH';
        }
        item.code = config.code;
        item.sectionCode = config.section;
        item.sequence = config.sequence;
        item.requiresConfirmation = config.requiresConfirmation;
        context.actions.add(item);
      }
      context.lifecycleHistory = new List<LOS_WorkspaceHistoryDTO>();
      List<LOS_Lifecycle_History__c> history = [
        SELECT
          Id,
          LOS_From_Stage__c,
          LOS_To_Stage__c,
          LOS_Transition_Type__c,
          LOS_Transition_Date_Time__c,
          LOS_Performed_By__r.Name,
          LOS_Rework_Number__c,
          LOS_Reason__c,
          LOS_Comments__c
        FROM LOS_Lifecycle_History__c
        WHERE LOS_Credit_Application__c = :applicationId
        WITH USER_MODE
        ORDER BY LOS_Transition_Date_Time__c DESC, CreatedDate DESC, Id DESC
        LIMIT 51
      ];
      context.historyHasMore = history.size() > 50;
      Map<String, String> stageLabels = new Map<String, String>();
      for (
        LOS_ConfigurationService.Config config : LOS_ConfigurationService.getStages()
      )
        stageLabels.put(config.code, config.label);
      for (Integer i = 0; i < Math.min(50, history.size()); i++) {
        LOS_Lifecycle_History__c row = history[i];
        LOS_WorkspaceHistoryDTO item = new LOS_WorkspaceHistoryDTO();
        item.id = row.Id;
        item.occurredAt = row.LOS_Transition_Date_Time__c;
        item.fromStage = stageLabels.containsKey(row.LOS_From_Stage__c)
          ? stageLabels.get(row.LOS_From_Stage__c)
          : row.LOS_From_Stage__c;
        item.toStage = stageLabels.containsKey(row.LOS_To_Stage__c)
          ? stageLabels.get(row.LOS_To_Stage__c)
          : row.LOS_To_Stage__c;
        item.transitionType = row.LOS_Transition_Type__c;
        item.performedBy = row.LOS_Performed_By__r.Name;
        item.reworkNumber = row.LOS_Rework_Number__c;
        item.reason = clip(row.LOS_Reason__c);
        item.comments = clip(row.LOS_Comments__c);
        context.lifecycleHistory.add(item);
      }
      context.tat = timing(app, context.loadedAt);
      return context;
    } catch (Exception e) {
      throw LOS_Exception.forClient(e);
    }
  }
  private static LOS_WorkspaceTatDTO timing(
    LOS_Credit_Application__c app,
    Datetime stamp
  ) {
    LOS_WorkspaceTatDTO result = new LOS_WorkspaceTatDTO();
    List<LOS_Stage_TAT__c> rows = [
      SELECT
        Id,
        LOS_Stage__c,
        LOS_Rework_Number__c,
        LOS_Start_Date_Time__c,
        LOS_Business_Minutes__c,
        LOS_SLA_Target_Minutes__c,
        LOS_Paused_Minutes__c
      FROM LOS_Stage_TAT__c
      WHERE LOS_Application__c = :app.Id AND LOS_End_Date_Time__c = NULL
      WITH USER_MODE
      LIMIT 2
    ];
    if (rows.size() > 1)
      throw new LOS_TATException(
        'Multiple visible open timing intervals require administrator review.'
      );
    if (rows.isEmpty()) {
      result.availability = 'No open timing interval is visible to you.';
      return result;
    }
    LOS_Stage_TAT__c row = rows[0];
    if (
      row.LOS_Stage__c != app.LOS_Current_Stage__c ||
      row.LOS_Rework_Number__c != app.LOS_Current_Rework_Number__c
    )
      throw new LOS_TATException(
        'The visible timing interval does not match the current application context.'
      );
    result.id = row.Id;
    result.stageCode = row.LOS_Stage__c;
    result.startedAt = row.LOS_Start_Date_Time__c;
    result.grossMinutes = LOS_BusinessTimeService.grossMinutes(
      result.startedAt,
      stamp
    );
    result.businessMinutes = row.LOS_Business_Minutes__c;
    result.targetMinutes = row.LOS_SLA_Target_Minutes__c;
    result.pausedMinutes = row.LOS_Paused_Minutes__c;
    result.hasVisiblePause = ![
        SELECT Id
        FROM LOS_TAT_Pause__c
        WHERE LOS_Stage_TAT__c = :row.Id AND LOS_Pause_End__c = NULL
        WITH USER_MODE
        LIMIT 1
      ]
      .isEmpty();
    result.availability = 'Gross elapsed time at last refresh. Business-calendar and remaining-SLA calculations are deferred.';
    return result;
  }
  @AuraEnabled(cacheable=true)
  public static List<LOS_WorkspaceApplicationDTO> getApplications() {
    try {
      requireRead();
      List<LOS_WorkspaceApplicationDTO> result = new List<LOS_WorkspaceApplicationDTO>();
      Map<String, String> stages = new Map<String, String>();
      Map<String, String> types = new Map<String, String>();
      for (
        LOS_ConfigurationService.Config item : LOS_ConfigurationService.getStages()
      )
        stages.put(item.code, item.label);
      for (
        LOS_ConfigurationService.Config item : LOS_ConfigurationService.getApplicationTypes()
      )
        types.put(item.code, item.label);
      for (LOS_Credit_Application__c row : [
        SELECT
          Id,
          Name,
          LOS_Relationship__r.Name,
          LOS_Application_Type__c,
          LOS_Current_Stage__c,
          LOS_Status__c,
          LOS_Current_Owner_User__r.Name,
          LOS_Organization_Unit__r.Name,
          LOS_Current_Rework_Number__c,
          LastModifiedDate
        FROM LOS_Credit_Application__c
        WITH USER_MODE
        ORDER BY LastModifiedDate DESC, Id DESC
        LIMIT 50
      ]) {
        LOS_WorkspaceApplicationDTO item = new LOS_WorkspaceApplicationDTO();
        item.id = row.Id;
        item.applicationNumber = row.Name;
        item.relationship = row.LOS_Relationship__r.Name;
        item.applicationType = types.get(row.LOS_Application_Type__c);
        item.stage = stages.containsKey(row.LOS_Current_Stage__c)
          ? stages.get(row.LOS_Current_Stage__c)
          : row.LOS_Current_Stage__c;
        item.status = row.LOS_Status__c;
        item.assignee = row.LOS_Current_Owner_User__r.Name;
        item.organizationUnit = row.LOS_Organization_Unit__r.Name;
        item.reworkNumber = row.LOS_Current_Rework_Number__c;
        item.modifiedAt = row.LastModifiedDate;
        result.add(item);
      }
      return result;
    } catch (Exception e) {
      throw LOS_Exception.forClient(e);
    }
  }
  @AuraEnabled(cacheable=true)
  public static List<LOS_WorkspaceOptionDTO> getApplicationTypes() {
    try {
      requireRead();
      List<LOS_WorkspaceOptionDTO> result = new List<LOS_WorkspaceOptionDTO>();
      for (
        LOS_ConfigurationService.Config config : ordered(
          LOS_ConfigurationService.getApplicationTypes()
        )
      ) {
        LOS_WorkspaceOptionDTO item = new LOS_WorkspaceOptionDTO();
        item.value = config.code;
        item.label = config.label;
        item.baselineRequired = config.baselineRequired;
        result.add(item);
      }
      return result;
    } catch (Exception e) {
      throw LOS_Exception.forClient(e);
    }
  }
  @AuraEnabled(cacheable=true)
  public static List<LOS_WorkspaceOptionDTO> searchRelationships(
    String searchTerm
  ) {
    try {
      requireRead();
      List<LOS_WorkspaceOptionDTO> result = new List<LOS_WorkspaceOptionDTO>();
      if (String.isBlank(searchTerm) || searchTerm.trim().length() < 2)
        return result;
      String pattern =
        '%' +
        searchTerm.trim()
          .left(80)
          .replace('\\', '\\\\')
          .replace('%', '\\%')
          .replace('_', '\\_') +
        '%';
      for (LOS_Relationship__c row : [
        SELECT Id, Name, LOS_Relationship_Number__c
        FROM LOS_Relationship__c
        WHERE
          LOS_Active__c = TRUE
          AND (Name LIKE :pattern
          OR LOS_Relationship_Number__c LIKE :pattern)
        WITH USER_MODE
        ORDER BY Name, Id
        LIMIT 20
      ]) {
        LOS_WorkspaceOptionDTO item = new LOS_WorkspaceOptionDTO();
        item.value = row.Id;
        item.label = row.Name + ' · ' + row.LOS_Relationship_Number__c;
        result.add(item);
      }
      return result;
    } catch (Exception e) {
      throw LOS_Exception.forClient(e);
    }
  }
  @AuraEnabled(cacheable=true)
  public static List<LOS_WorkspaceOptionDTO> searchBaselines(
    Id relationshipId,
    String searchTerm
  ) {
    try {
      requireRead();
      List<LOS_WorkspaceOptionDTO> result = new List<LOS_WorkspaceOptionDTO>();
      if (
        relationshipId == null ||
        String.isBlank(searchTerm) ||
        searchTerm.trim().length() < 2
      )
        return result;
      String pattern =
        '%' +
        searchTerm.trim()
          .left(80)
          .replace('\\', '\\\\')
          .replace('%', '\\%')
          .replace('_', '\\_') +
        '%';
      for (LOS_Credit_Application__c row : [
        SELECT Id, Name
        FROM LOS_Credit_Application__c
        WHERE
          LOS_Relationship__c = :relationshipId
          AND LOS_Approved_Date__c != NULL
          AND Name LIKE :pattern
        WITH USER_MODE
        ORDER BY Name, Id
        LIMIT 20
      ]) {
        LOS_WorkspaceOptionDTO item = new LOS_WorkspaceOptionDTO();
        item.value = row.Id;
        item.label = row.Name;
        result.add(item);
      }
      return result;
    } catch (Exception e) {
      throw LOS_Exception.forClient(e);
    }
  }
}
