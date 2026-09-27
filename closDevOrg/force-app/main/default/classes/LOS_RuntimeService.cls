/** Transaction coordinator; the only holder of the private write capability.
 * Caller-supplied fields are allowlisted. Generated application/audit/TAT writes intentionally run
 * in system mode after parent authorization, not by granting users write access to audit data.
 */
public with sharing class LOS_RuntimeService {
  private static List<SObject> allowedWrites;
  private static Boolean inserting;
  private static Boolean running = false;
  public static Boolean consumeAuthorization(SObject row, Boolean isInsert) {
    if (allowedWrites == null || inserting != isInsert)
      return false;
    for (Integer i = 0; i < allowedWrites.size(); i++) {
      SObject expected = allowedWrites[i];
      if (row.getSObjectType() != expected.getSObjectType())
        continue;
      Boolean same = true;
      for (String field : expected.getPopulatedFieldsAsMap().keySet())
        if (row.get(field) != expected.get(field)) {
          same = false;
          break;
        }
      if (same) {
        allowedWrites.remove(i);
        return true;
      }
    }
    return false;
  }
  @TestVisible
  private static void persist(List<SObject> rows, Boolean createRows) {
    if (rows.isEmpty())
      return;
    if (allowedWrites != null)
      throw new LOS_LifecycleException(
        'Nested runtime writes are not supported.'
      );
    allowedWrites = new List<SObject>();
    for (SObject row : rows)
      allowedWrites.add(row.clone(true, true, false, false));
    inserting = createRows;
    try {
      LOS_RuntimeWriter.write(rows, createRows);
    } finally {
      allowedWrites = null;
      inserting = null;
    }
  }
  private static void beginRequest(Integer size) {
    if (running)
      throw new LOS_LifecycleException(
        'Nested runtime operations are not supported.'
      );
    if (size == null || size < 1 || size > 200)
      throw new LOS_ValidationException('Provide between 1 and 200 requests.');
    running = true;
  }
  private static void finishRequest() {
    allowedWrites = null;
    inserting = null;
    running = false;
  }
  private static void fail(Exception problem, Savepoint checkpoint) {
    Database.rollback(checkpoint);
    if (problem instanceof LOS_Exception)
      throw problem;
    throw new LOS_LifecycleException(
      'The operation could not be completed. Check access, refresh, and retry.'
    );
  }
  private static List<LOS_Credit_Application__c> lockApplications(Set<Id> ids) {
    LOS_Security.requireEdit(ids);
    List<LOS_Credit_Application__c> rows = [
      SELECT
        Id,
        Name,
        OwnerId,
        LOS_Relationship__c,
        LOS_Application_Type__c,
        LOS_Current_Stage__c,
        LOS_Status__c,
        LOS_Primary_RM__c,
        LOS_Current_Owner_User__c,
        LOS_Current_Queue_Key__c,
        LOS_Organization_Unit__c,
        LOS_Business_Unit_Snapshot__c,
        LOS_Segment_Snapshot__c,
        LOS_Branch_Snapshot__c,
        LOS_Rework_Count__c,
        LOS_Current_Rework_Number__c,
        LOS_Runtime_Version__c,
        LOS_Active__c,
        LOS_Baseline_Application__c,
        LOS_Previous_Approved_Application__c,
        LOS_Submitted_Date__c,
        LOS_Approved_Date__c,
        LOS_Booking_Date__c
      FROM LOS_Credit_Application__c
      WHERE Id IN :ids
      WITH SYSTEM_MODE
      FOR UPDATE
    ];
    if (rows.size() != ids.size())
      throw new LOS_SecurityException('An application is unavailable.');
    for (LOS_Credit_Application__c a : rows) {
      if (!a.LOS_Active__c)
        throw new LOS_LifecycleException('This application is inactive.');
      if (a.LOS_Runtime_Version__c == null)
        throw new LOS_LifecycleException(
          'This application requires runtime migration before use.'
        );
    }
    return rows;
  }
  private static LOS_Lifecycle_History__c history(
    LOS_Credit_Application__c a,
    String fromStage,
    String transitionType,
    String reason,
    String comments,
    Datetime stamp
  ) {
    return new LOS_Lifecycle_History__c(
      LOS_Credit_Application__c = a.Id,
      LOS_From_Stage__c = fromStage,
      LOS_To_Stage__c = a.LOS_Current_Stage__c,
      LOS_Transition_Type__c = transitionType,
      LOS_Transition_Date_Time__c = stamp,
      LOS_Performed_By__c = UserInfo.getUserId(),
      LOS_Reason__c = reason,
      LOS_Comments__c = comments,
      LOS_Rework_Number__c = a.LOS_Current_Rework_Number__c
    );
  }
  private static List<LOS_Stage_TAT__c> newIntervals(
    List<LOS_Credit_Application__c> apps,
    Datetime stamp
  ) {
    Map<Id, LOS_RuntimeData.Scope> scopes = LOS_RuntimeData.scopes(
      apps,
      stamp.dateGmt()
    );
    List<LOS_Stage_TAT__c> result = new List<LOS_Stage_TAT__c>();
    for (LOS_Credit_Application__c app : apps) {
      LOS_ConfigurationService.Config stage = LOS_ConfigurationService.getStage(
        app.LOS_Current_Stage__c
      );
      if (!stage.tatEnabled)
        continue;
      LOS_RuntimeData.Scope scope = scopes.get(app.Id);
      LOS_ConfigurationService.Config sla = LOS_ConfigurationService.selectSLA(
        app.LOS_Application_Type__c,
        stage.code,
        scope.unitType,
        scope.personas,
        stamp.dateGmt()
      );
      result.add(LOS_TATService.startStageTAT(app, stage, sla, stamp));
    }
    return result;
  }
  public static List<LOS_ApplicationDTO> createApplications(
    List<LOS_ApplicationService.CreateRequest> requests
  ) {
    beginRequest(requests == null ? null : requests.size());
    Savepoint checkpoint = Database.setSavepoint();
    try {
      LOS_Security.requireRuntime(true);
      Set<Id> relationshipIds = new Set<Id>();
      Set<Id> baselineIds = new Set<Id>();
      for (LOS_ApplicationService.CreateRequest r : requests) {
        if (
          r == null ||
          r.relationshipId == null ||
          String.isBlank(r.applicationTypeCode)
        )
          throw new LOS_ValidationException(
            'Relationship and application type are required.'
          );
        relationshipIds.add(r.relationshipId);
        if (r.baselineApplicationId != null)
          baselineIds.add(r.baselineApplicationId);
      }
      Map<Id, LOS_Relationship__c> relationships = new Map<Id, LOS_Relationship__c>(
        [
          SELECT
            Id,
            LOS_Active__c,
            LOS_Primary_RM__c,
            LOS_Primary_Organization_Unit__c,
            LOS_Business_Unit_Snapshot__c,
            LOS_Segment_Snapshot__c,
            LOS_Branch_Snapshot__c
          FROM LOS_Relationship__c
          WHERE Id IN :relationshipIds
          WITH USER_MODE
        ]
      );
      Map<Id, LOS_Credit_Application__c> baselines = new Map<Id, LOS_Credit_Application__c>(
        [
          SELECT Id, LOS_Relationship__c, LOS_Approved_Date__c
          FROM LOS_Credit_Application__c
          WHERE Id IN :baselineIds
          WITH USER_MODE
        ]
      );
      List<LOS_Credit_Application__c> apps = new List<LOS_Credit_Application__c>();
      for (LOS_ApplicationService.CreateRequest r : requests) {
        LOS_Relationship__c relationship = relationships.get(r.relationshipId);
        if (relationship == null)
          throw new LOS_SecurityException('The relationship is unavailable.');
        if (!relationship.LOS_Active__c)
          throw new LOS_ValidationException('The relationship is inactive.');
        LOS_ConfigurationService.Config typeConfig = LOS_ConfigurationService.getApplicationType(
          r.applicationTypeCode
        );
        LOS_ConfigurationService.Config initial = LOS_ConfigurationService.getInitialStage(
          typeConfig.code
        );
        if (typeConfig.baselineRequired && r.baselineApplicationId == null)
          throw new LOS_ValidationException(
            'This application type requires an approved baseline application.'
          );
        if (
          r.baselineApplicationId != null &&
          (!baselines.containsKey(r.baselineApplicationId) ||
          baselines.get(r.baselineApplicationId).LOS_Relationship__c !=
          r.relationshipId ||
          baselines.get(r.baselineApplicationId).LOS_Approved_Date__c == null)
        )
          throw new LOS_ValidationException(
            'The baseline must be an accessible approved application for this relationship.'
          );
        apps.add(
          new LOS_Credit_Application__c(
            LOS_Relationship__c = relationship.Id,
            LOS_Application_Type__c = typeConfig.code,
            LOS_Current_Stage__c = initial.code,
            LOS_Status__c = initial.defaultApplicationStatus,
            LOS_Primary_RM__c = relationship.LOS_Primary_RM__c,
            LOS_Current_Owner_User__c = UserInfo.getUserId(),
            LOS_Organization_Unit__c = relationship.LOS_Primary_Organization_Unit__c,
            LOS_Business_Unit_Snapshot__c = relationship.LOS_Business_Unit_Snapshot__c,
            LOS_Segment_Snapshot__c = relationship.LOS_Segment_Snapshot__c,
            LOS_Branch_Snapshot__c = relationship.LOS_Branch_Snapshot__c,
            LOS_Rework_Count__c = 0,
            LOS_Current_Rework_Number__c = 0,
            LOS_Runtime_Version__c = 0,
            LOS_Active__c = true,
            LOS_Baseline_Application__c = r.baselineApplicationId,
            LOS_Previous_Approved_Application__c = r.baselineApplicationId
          )
        );
      }
      persist(apps, true);
      Datetime stamp = LOS_BusinessTimeService.nowValue();
      List<LOS_Lifecycle_History__c> events = new List<LOS_Lifecycle_History__c>();
      List<Id> ids = new List<Id>();
      for (LOS_Credit_Application__c a : apps) {
        ids.add(a.Id);
        events.add(history(a, null, 'Initial', null, null, stamp));
      }
      persist(events, true);
      persist(newIntervals(apps, stamp), true);
      return LOS_Security.responses(ids);
    } catch (Exception e) {
      fail(e, checkpoint);
      return null;
    } finally {
      Database.releaseSavepoint(checkpoint);
      finishRequest();
    }
  }
  public static List<LOS_ApplicationDTO> transitionApplications(
    List<LOS_LifecycleService.TransitionRequest> requests
  ) {
    beginRequest(requests == null ? null : requests.size());
    Savepoint checkpoint = Database.setSavepoint();
    try {
      Set<Id> ids = new Set<Id>();
      Map<Id, LOS_LifecycleService.TransitionRequest> byId = new Map<Id, LOS_LifecycleService.TransitionRequest>();
      List<Id> order = new List<Id>();
      for (LOS_LifecycleService.TransitionRequest r : requests) {
        if (
          r == null ||
          r.applicationId == null ||
          r.expectedVersion == null ||
          String.isBlank(r.transitionCode)
        )
          throw new LOS_ValidationException(
            'Application, transition code and expected version are required.'
          );
        if (!ids.add(r.applicationId))
          throw new LOS_ValidationException(
            'An application can appear only once per request.'
          );
        order.add(r.applicationId);
        byId.put(r.applicationId, r);
      }
      List<LOS_Credit_Application__c> apps = lockApplications(ids);
      Map<Id, LOS_Stage_TAT__c> current = LOS_RuntimeData.openIntervals(ids);
      Set<Id> tatIds = new Set<Id>();
      for (LOS_Stage_TAT__c t : current.values())
        tatIds.add(t.Id);
      Map<Id, List<LOS_TAT_Pause__c>> pauses = LOS_RuntimeData.pauses(tatIds);
      List<LOS_Lifecycle_History__c> events = new List<LOS_Lifecycle_History__c>();
      List<LOS_Stage_TAT__c> closed = new List<LOS_Stage_TAT__c>();
      Datetime stamp = LOS_BusinessTimeService.nowValue();
      for (LOS_Credit_Application__c app : apps) {
        LOS_LifecycleService.TransitionRequest r = byId.get(app.Id);
        if (r.expectedVersion != app.LOS_Runtime_Version__c)
          throw new LOS_LifecycleException(
            'The application changed. Refresh before retrying.'
          );
        LOS_ConfigurationService.Config fromStage = LOS_ConfigurationService.getStage(
          app.LOS_Current_Stage__c
        );
        LOS_ConfigurationService.Config transition = LOS_ConfigurationService.getTransition(
          r.transitionCode,
          app.LOS_Application_Type__c
        );
        if (fromStage.terminal || transition.fromStage != fromStage.code)
          throw new LOS_LifecycleException(
            'This transition is not valid from the current stage.'
          );
        LOS_ConfigurationService.Config destination = LOS_ConfigurationService.getStage(
          transition.toStage
        );
        LOS_ValidationService.Context context = new LOS_ValidationService.Context();
        context.application = app.clone(true, true, false, false);
        context.transition = transition;
        context.reason = r.reason;
        context.comments = r.comments;
        LOS_ValidationService.requireValid(context);
        LOS_Stage_TAT__c interval = current.get(app.Id);
        if (fromStage.tatEnabled && interval == null)
          throw new LOS_TATException(
            'The current stage interval is missing. Contact an administrator.'
          );
        if (interval != null) {
          requireContext(app, interval);
          LOS_TATService.closeStageTAT(
            interval,
            pauses.get(interval.Id),
            stamp
          );
          closed.add(interval);
        }
        if (transition.transitionType == 'Rework') {
          app.LOS_Rework_Count__c =
            (app.LOS_Rework_Count__c == null ? 0 : app.LOS_Rework_Count__c) + 1;
          app.LOS_Current_Rework_Number__c = app.LOS_Rework_Count__c;
        }
        app.LOS_Current_Stage__c = transition.toStage;
        app.LOS_Status__c = destination.defaultApplicationStatus;
        app.LOS_Runtime_Version__c++;
        events.add(
          history(
            app,
            fromStage.code,
            transition.transitionType,
            r.reason,
            r.comments,
            stamp
          )
        );
      }
      // Close before inserting the next interval so the unique open-context key can be reused.
      persist(closed, false);
      persist(apps, false);
      persist(events, true);
      persist(newIntervals(apps, stamp), true);
      return LOS_Security.responses(order);
    } catch (Exception e) {
      fail(e, checkpoint);
      return null;
    } finally {
      Database.releaseSavepoint(checkpoint);
      finishRequest();
    }
  }
  private static void requireContext(
    LOS_Credit_Application__c app,
    LOS_Stage_TAT__c interval
  ) {
    if (
      interval == null ||
      interval.LOS_Stage__c != app.LOS_Current_Stage__c ||
      interval.LOS_Rework_Number__c != app.LOS_Current_Rework_Number__c ||
      interval.LOS_Open_Context_Key__c != String.valueOf(app.Id)
    )
      throw new LOS_TATException(
        'The open stage interval does not match the application context.'
      );
  }
  public static List<Id> pauseTATs(List<LOS_TATService.PauseRequest> requests) {
    beginRequest(requests == null ? null : requests.size());
    Savepoint checkpoint = Database.setSavepoint();
    try {
      Set<Id> ids = new Set<Id>();
      for (LOS_TATService.PauseRequest r : requests)
        if (
          r == null ||
          r.applicationId == null ||
          r.expectedStageTATId == null ||
          !ids.add(r.applicationId)
        )
          throw new LOS_ValidationException(
            'Provide distinct applications and the expected stage interval.'
          );
      Map<Id, LOS_Credit_Application__c> apps = new Map<Id, LOS_Credit_Application__c>(
        lockApplications(ids)
      );
      Map<Id, LOS_Stage_TAT__c> intervals = LOS_RuntimeData.openIntervals(ids);
      Set<Id> tatIds = new Set<Id>();
      for (LOS_Stage_TAT__c t : intervals.values())
        tatIds.add(t.Id);
      Map<Id, List<LOS_TAT_Pause__c>> existing = LOS_RuntimeData.pauses(tatIds);
      List<LOS_TAT_Pause__c> created = new List<LOS_TAT_Pause__c>();
      Datetime stamp = LOS_BusinessTimeService.nowValue();
      for (LOS_TATService.PauseRequest r : requests) {
        LOS_Credit_Application__c app = apps.get(r.applicationId);
        LOS_Stage_TAT__c tat = intervals.get(app.Id);
        requireContext(app, tat);
        if (tat.Id != r.expectedStageTATId)
          throw new LOS_TATException(
            'The stage interval changed. Refresh before pausing.'
          );
        LOS_ConfigurationService.getStage(app.LOS_Current_Stage__c);
        LOS_ConfigurationService.Config rule = LOS_ConfigurationService.getPauseRule(
          r.reasonCode,
          app.LOS_Application_Type__c,
          app.LOS_Current_Stage__c
        );
        if (rule.requiresComments && String.isBlank(r.comments))
          throw new LOS_ValidationException(
            'Comments are required for this pause reason.'
          );
        if (r.comments != null && r.comments.length() > 32768)
          throw new LOS_ValidationException(
            'Pause comments must be 32768 characters or fewer.'
          );
        for (LOS_TAT_Pause__c p : existing.get(tat.Id))
          if (p.LOS_Pause_End__c == null)
            throw new LOS_TATException(
              'This stage already has an active pause.'
            );
        LOS_BusinessTimeService.milliseconds(tat.LOS_Start_Date_Time__c, stamp);
        created.add(
          new LOS_TAT_Pause__c(
            LOS_Application__c = app.Id,
            LOS_Stage_TAT__c = tat.Id,
            LOS_Pause_Reason__c = rule.code,
            LOS_Pause_Start__c = stamp,
            LOS_Count_Toward_SLA__c = rule.countTowardSLA,
            LOS_Comments__c = r.comments,
            LOS_Open_Context_Key__c = String.valueOf(tat.Id)
          )
        );
      }
      persist(created, true);
      List<Id> result = new List<Id>();
      for (LOS_TAT_Pause__c p : created)
        result.add(p.Id);
      return result;
    } catch (Exception e) {
      fail(e, checkpoint);
      return null;
    } finally {
      Database.releaseSavepoint(checkpoint);
      finishRequest();
    }
  }
  public static void resumeTATs(List<LOS_TATService.ResumeRequest> requests) {
    beginRequest(requests == null ? null : requests.size());
    Savepoint checkpoint = Database.setSavepoint();
    try {
      Set<Id> ids = new Set<Id>();
      for (LOS_TATService.ResumeRequest r : requests)
        if (
          r == null ||
          r.applicationId == null ||
          r.expectedPauseId == null ||
          !ids.add(r.applicationId)
        )
          throw new LOS_ValidationException(
            'Provide distinct applications and the expected pause.'
          );
      Map<Id, LOS_Credit_Application__c> apps = new Map<Id, LOS_Credit_Application__c>(
        lockApplications(ids)
      );
      Map<Id, LOS_Stage_TAT__c> intervals = LOS_RuntimeData.openIntervals(ids);
      Set<Id> tatIds = new Set<Id>();
      for (LOS_Stage_TAT__c t : intervals.values())
        tatIds.add(t.Id);
      Map<Id, List<LOS_TAT_Pause__c>> pauses = LOS_RuntimeData.pauses(tatIds);
      List<LOS_TAT_Pause__c> changed = new List<LOS_TAT_Pause__c>();
      List<LOS_Stage_TAT__c> measured = new List<LOS_Stage_TAT__c>();
      Datetime stamp = LOS_BusinessTimeService.nowValue();
      for (LOS_TATService.ResumeRequest r : requests) {
        LOS_Credit_Application__c app = apps.get(r.applicationId);
        LOS_Stage_TAT__c tat = intervals.get(app.Id);
        requireContext(app, tat);
        LOS_TAT_Pause__c active;
        for (LOS_TAT_Pause__c p : pauses.get(tat.Id))
          if (p.LOS_Pause_End__c == null) {
            if (active != null)
              throw new LOS_TATException(
                'Multiple active pauses require administrator repair.'
              );
            active = p;
          }
        if (active == null || active.Id != r.expectedPauseId)
          throw new LOS_TATException(
            'This pause is no longer active. Refresh before retrying.'
          );
        active.LOS_Pause_End__c = stamp;
        active.LOS_Open_Context_Key__c = null;
        LOS_TATService.recalculate(tat, pauses.get(tat.Id), stamp);
        changed.add(active);
        measured.add(tat);
      }
      persist(changed, false);
      persist(measured, false);
    } catch (Exception e) {
      fail(e, checkpoint);
    } finally {
      Database.releaseSavepoint(checkpoint);
      finishRequest();
    }
  }
}
