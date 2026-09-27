/** Internal read repository for service-owned children. Parent authorization occurs in LOS_RuntimeService.
 * Deliberately without sharing: lookup children do not inherit the authorized application's shares.
 * No Aura/REST/Invocable entry points and no DML capability are exposed here.
 */
public without sharing class LOS_RuntimeData {
  public static Map<Id, LOS_Stage_TAT__c> openIntervals(
    Set<Id> applicationIds
  ) {
    LOS_Security.requireEdit(applicationIds);
    Map<Id, LOS_Stage_TAT__c> result = new Map<Id, LOS_Stage_TAT__c>();
    for (LOS_Stage_TAT__c row : [
      SELECT
        Id,
        LOS_Application__c,
        LOS_Stage__c,
        LOS_Rework_Number__c,
        LOS_Start_Date_Time__c,
        LOS_End_Date_Time__c,
        LOS_Started_By__c,
        LOS_Completed_By__c,
        LOS_SLA_Target_Minutes__c,
        LOS_Calendar_Key__c,
        LOS_Open_Context_Key__c,
        LOS_Gross_Minutes__c,
        LOS_Business_Minutes__c,
        LOS_Paused_Minutes__c,
        LOS_SLA_Status__c
      FROM LOS_Stage_TAT__c
      WHERE
        LOS_Application__c IN :applicationIds
        AND LOS_End_Date_Time__c = NULL
      WITH SYSTEM_MODE
    ]) {
      if (result.containsKey(row.LOS_Application__c))
        throw new LOS_TATException(
          'Multiple open stage intervals require administrator repair.'
        );
      result.put(row.LOS_Application__c, row);
    }
    return result;
  }
  public static Map<Id, List<LOS_TAT_Pause__c>> pauses(Set<Id> tatIds) {
    Map<Id, List<LOS_TAT_Pause__c>> result = new Map<Id, List<LOS_TAT_Pause__c>>();
    if (tatIds.isEmpty())
      return result;
    Set<Id> applicationIds = new Set<Id>();
    List<LOS_Stage_TAT__c> parents = [
      SELECT Id, LOS_Application__c
      FROM LOS_Stage_TAT__c
      WHERE Id IN :tatIds
      WITH SYSTEM_MODE
    ];
    if (parents.size() != tatIds.size())
      throw new LOS_SecurityException('A stage interval is unavailable.');
    for (LOS_Stage_TAT__c parent : parents)
      applicationIds.add(parent.LOS_Application__c);
    LOS_Security.requireEdit(applicationIds);
    for (Id key : tatIds)
      result.put(key, new List<LOS_TAT_Pause__c>());
    for (LOS_TAT_Pause__c row : [
      SELECT
        Id,
        LOS_Stage_TAT__c,
        LOS_Application__c,
        LOS_Pause_Reason__c,
        LOS_Pause_Start__c,
        LOS_Pause_End__c,
        LOS_Count_Toward_SLA__c,
        LOS_Comments__c,
        LOS_Open_Context_Key__c
      FROM LOS_TAT_Pause__c
      WHERE LOS_Stage_TAT__c IN :tatIds
      WITH SYSTEM_MODE
      ORDER BY LOS_Pause_Start__c
    ])
      result.get(row.LOS_Stage_TAT__c).add(row);
    return result;
  }
  public class Scope {
    public String unitType;
    public Set<String> personas = new Set<String>();
  }
  public static Map<Id, Scope> scopes(
    List<LOS_Credit_Application__c> apps,
    Date onDate
  ) {
    Set<Id> unitIds = new Set<Id>();
    Set<Id> appIds = new Set<Id>();
    for (LOS_Credit_Application__c a : apps)
      appIds.add(a.Id);
    LOS_Security.requireEdit(appIds);
    apps = [
      SELECT Id, LOS_Organization_Unit__c
      FROM LOS_Credit_Application__c
      WHERE Id IN :appIds
      WITH SYSTEM_MODE
    ];
    for (LOS_Credit_Application__c a : apps)
      unitIds.add(a.LOS_Organization_Unit__c);
    Map<Id, LOS_Organization_Unit__c> units = new Map<Id, LOS_Organization_Unit__c>(
      [
        SELECT Id, LOS_Unit_Type__c
        FROM LOS_Organization_Unit__c
        WHERE Id IN :unitIds
        WITH SYSTEM_MODE
      ]
    );
    Map<Id, Set<String>> unitRoles = new Map<Id, Set<String>>();
    for (LOS_User_Org_Assignment__c m : [
      SELECT LOS_Organization_Unit__c, LOS_Persona_Code__c
      FROM LOS_User_Org_Assignment__c
      WHERE
        LOS_Organization_Unit__c IN :unitIds
        AND LOS_User__c = :UserInfo.getUserId()
        AND LOS_Active__c = TRUE
        AND (LOS_Effective_From__c = NULL
        OR LOS_Effective_From__c <= :onDate)
        AND (LOS_Effective_To__c = NULL
        OR LOS_Effective_To__c >= :onDate)
      WITH SYSTEM_MODE
    ]) {
      if (!unitRoles.containsKey(m.LOS_Organization_Unit__c))
        unitRoles.put(m.LOS_Organization_Unit__c, new Set<String>());
      unitRoles.get(m.LOS_Organization_Unit__c).add(m.LOS_Persona_Code__c);
    }
    Map<Id, Scope> result = new Map<Id, Scope>();
    for (LOS_Credit_Application__c a : apps) {
      Scope value = new Scope();
      value.unitType = units.containsKey(a.LOS_Organization_Unit__c)
        ? units.get(a.LOS_Organization_Unit__c).LOS_Unit_Type__c
        : null;
      if (unitRoles.containsKey(a.LOS_Organization_Unit__c))
        value.personas.addAll(unitRoles.get(a.LOS_Organization_Unit__c));
      result.put(a.Id, value);
    }
    for (LOS_Application_Team__c m : [
      SELECT LOS_Credit_Application__c, LOS_Persona_Code__c
      FROM LOS_Application_Team__c
      WHERE
        LOS_Credit_Application__c IN :appIds
        AND LOS_User__c = :UserInfo.getUserId()
        AND LOS_Active__c = TRUE
        AND (LOS_Effective_From__c = NULL
        OR LOS_Effective_From__c <= :onDate)
        AND (LOS_Effective_To__c = NULL
        OR LOS_Effective_To__c >= :onDate)
      WITH SYSTEM_MODE
    ])
      result.get(m.LOS_Credit_Application__c)
        .personas.add(m.LOS_Persona_Code__c);
    Set<String> activePersonas = new Set<String>();
    for (
      LOS_ConfigurationService.Config c : LOS_ConfigurationService.getPersonas()
    )
      activePersonas.add(c.code);
    for (Scope value : result.values())
      value.personas.retainAll(activePersonas);
    return result;
  }
}
