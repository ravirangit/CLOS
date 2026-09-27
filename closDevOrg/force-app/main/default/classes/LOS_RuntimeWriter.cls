/** Narrow system DML boundary for parent-authorized, service-owned records.
 * This class cannot grant write authorization. Record guards consume the coordinator's private
 * one-use capabilities. Calling this writer directly fails the guards, even for administrators.
 */
public without sharing class LOS_RuntimeWriter {
  public static void write(List<SObject> rows, Boolean creating) {
    Set<Schema.SObjectType> supported = new Set<Schema.SObjectType>{
      LOS_Credit_Application__c.SObjectType,
      LOS_Lifecycle_History__c.SObjectType,
      LOS_Stage_TAT__c.SObjectType,
      LOS_TAT_Pause__c.SObjectType
    };
    for (SObject row : rows)
      if (!supported.contains(row.getSObjectType()))
        throw new LOS_SecurityException(
          'This record type is not managed by the runtime.'
        );
    if (creating)
      Database.insert(rows, true, AccessLevel.SYSTEM_MODE);
    else
      Database.update(rows, true, AccessLevel.SYSTEM_MODE);
  }
}
