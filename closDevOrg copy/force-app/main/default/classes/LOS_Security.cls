/** Public operations require runtime permission, object CRUD, field readability and record access. */
public with sharing class LOS_Security {
  public static void requireRuntime(Boolean creating) {
    if (!FeatureManagement.checkPermission('LOS_Use_Runtime'))
      throw new LOS_SecurityException(
        'You are not permitted to use the lending runtime.'
      );
    Schema.DescribeSObjectResult application = LOS_Credit_Application__c.SObjectType.getDescribe();
    if (
      !application.isAccessible() ||
      (!application.isUpdateable() || (creating && !application.isCreateable()))
    )
      throw new LOS_SecurityException(
        'You do not have the required application access.'
      );
  }
  public static void requireEdit(Set<Id> ids) {
    requireRuntime(false);
    if (ids.isEmpty() || ids.size() > 200)
      throw new LOS_ValidationException(
        'Provide between 1 and 200 distinct applications.'
      );
    Set<Id> allowed = new Set<Id>();
    for (UserRecordAccess access : [
      SELECT RecordId, HasEditAccess
      FROM UserRecordAccess
      WHERE UserId = :UserInfo.getUserId() AND RecordId IN :ids
      WITH SYSTEM_MODE
    ])
      if (access.HasEditAccess)
        allowed.add(access.RecordId);
    if (!allowed.containsAll(ids))
      throw new LOS_SecurityException(
        'An application is unavailable or you do not have edit access.'
      );
    // USER_MODE also checks restriction rules and all caller-visible application fields.
    if (readApplications(ids).size() != ids.size())
      throw new LOS_SecurityException('An application is unavailable.');
  }
  public static List<LOS_Credit_Application__c> readApplications(Set<Id> ids) {
    return [
      SELECT
        Id,
        Name,
        LOS_Application_Type__c,
        LOS_Current_Stage__c,
        LOS_Status__c,
        LOS_Current_Rework_Number__c,
        LOS_Runtime_Version__c,
        LOS_Active__c
      FROM LOS_Credit_Application__c
      WHERE Id IN :ids
      WITH USER_MODE
    ];
  }
  public static List<LOS_ApplicationDTO> responses(List<Id> ids) {
    Map<Id, LOS_Credit_Application__c> rows = new Map<Id, LOS_Credit_Application__c>(
      readApplications(new Set<Id>(ids))
    );
    List<LOS_ApplicationDTO> result = new List<LOS_ApplicationDTO>();
    for (Id key : ids) {
      if (!rows.containsKey(key))
        throw new LOS_SecurityException('An application is unavailable.');
      result.add(new LOS_ApplicationDTO(rows.get(key)));
    }
    return result;
  }
}
