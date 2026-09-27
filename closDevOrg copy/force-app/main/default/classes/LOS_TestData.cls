@IsTest
public class LOS_TestData {
  public static void setup() {
    Id profileId = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Minimum Access - Salesforce'
      LIMIT 1
    ]
    .Id;
    List<User> users = new List<User>();
    for (String alias : new List<String>{ 'losrun', 'losdeny' })
      users.add(
        new User(
          Alias = alias,
          LastName = 'LOS Runtime Test',
          Email = alias + '@example.invalid',
          Username = alias +
            String.valueOf(Crypto.getRandomInteger()) +
            System.now().getTime() +
            '@example.invalid',
          TimeZoneSidKey = 'GMT',
          LocaleSidKey = 'en_US',
          EmailEncodingKey = 'UTF-8',
          LanguageLocaleKey = 'en_US',
          ProfileId = profileId
        )
      );
    insert as system users;
    insert as system new PermissionSetAssignment(
      AssigneeId = users[0].Id,
      PermissionSetId = [
        SELECT Id
        FROM PermissionSet
        WHERE Name = 'LOS_Lending_User'
        LIMIT 1
      ]
      .Id
    );
    System.runAs(users[0]) {
      LOS_Organization_Unit__c unit = new LOS_Organization_Unit__c(
        Name = 'Test Unit',
        LOS_Code__c = 'TEST_UNIT',
        LOS_Unit_Type__c = 'TEST_TYPE',
        LOS_Active__c = true
      );
      insert as system unit;
      Account account = new Account(Name = 'Runtime Test Customer');
      insert as system account;
      insert as system new LOS_Relationship__c(
        Name = 'Test Relationship',
        LOS_Relationship_Number__c = 'TEST_REL',
        LOS_Account__c = account.Id,
        LOS_Primary_RM__c = users[0].Id,
        LOS_Primary_Organization_Unit__c = unit.Id,
        LOS_Active__c = true,
        LOS_Business_Unit_Snapshot__c = 'TEST_BU',
        LOS_Segment_Snapshot__c = 'TEST_SEGMENT',
        LOS_Branch_Snapshot__c = 'TEST_BRANCH'
      );
    }
  }
  public static SObject withRelationship(
    SObject row,
    String relationshipName,
    SObject target
  ) {
    Map<String, Object> values = (Map<String, Object>) JSON.deserializeUntyped(
      JSON.serialize(row)
    );
    values.put(
      relationshipName,
      JSON.deserializeUntyped(JSON.serialize(target))
    );
    return (SObject) JSON.deserialize(
      JSON.serialize(values),
      Type.forName(String.valueOf(row.getSObjectType()))
    );
  }
  public static User actor() {
    return [
      SELECT Id
      FROM User
      WHERE Alias = 'losrun' AND LastName = 'LOS Runtime Test'
      LIMIT 1
    ];
  }
  public static User denied() {
    return [
      SELECT Id
      FROM User
      WHERE Alias = 'losdeny' AND LastName = 'LOS Runtime Test'
      LIMIT 1
    ];
  }
  public static LOS_Relationship__c relationship() {
    return [
      SELECT Id, LOS_Active__c, LOS_Primary_Organization_Unit__c
      FROM LOS_Relationship__c
      WHERE LOS_Relationship_Number__c = 'TEST_REL'
      LIMIT 1
    ];
  }
  public static LOS_ApplicationDTO createApp() {
    return LOS_ApplicationService.createApplications(
      new List<LOS_ApplicationService.CreateRequest>{
        new LOS_ApplicationService.CreateRequest(relationship().Id, 'New')
      }
    )[0];
  }
  public static LOS_ApplicationDTO move(LOS_ApplicationDTO app, String code) {
    LOS_LifecycleService.TransitionRequest request = new LOS_LifecycleService.TransitionRequest(
      app.applicationId,
      code,
      app.version
    );
    request.reason = 'Test reason';
    return LOS_LifecycleService.transitionApplications(
      new List<LOS_LifecycleService.TransitionRequest>{ request }
    )[0];
  }
  public static LOS_ApplicationDTO atReview(Boolean credit) {
    LOS_ApplicationDTO app = move(
      move(createApp(), 'Draft_To_Underwriting'),
      'Underwriting_To_RM_TL_Review'
    );
    return credit ? move(app, 'RM_TL_Review_To_Credit_Review') : app;
  }
  public static LOS_Stage_TAT__c open(Id appId) {
    return [
      SELECT
        Id,
        LOS_Stage__c,
        LOS_Rework_Number__c,
        LOS_Start_Date_Time__c,
        LOS_End_Date_Time__c,
        LOS_Paused_Minutes__c,
        LOS_SLA_Target_Minutes__c,
        LOS_Calendar_Key__c,
        LOS_Gross_Minutes__c,
        LOS_SLA_Status__c
      FROM LOS_Stage_TAT__c
      WHERE LOS_Application__c = :appId AND LOS_End_Date_Time__c = NULL
      LIMIT 1
    ];
  }
  public static LOS_Stage_Transition__mdt transition(String code) {
    return [
      SELECT
        MasterLabel,
        LOS_Code__c,
        LOS_Active__c,
        LOS_Description__c,
        LOS_Application_Type__r.LOS_Code__c,
        LOS_From_Stage__r.LOS_Code__c,
        LOS_To_Stage__r.LOS_Code__c,
        LOS_Transition_Type__c,
        LOS_Action_Label__c,
        LOS_Requires_Reason__c,
        LOS_Requires_Validation__c,
        LOS_Validation_Policy_Code__c,
        LOS_Sequence__c
      FROM LOS_Stage_Transition__mdt
      WHERE LOS_Code__c = :code
      LIMIT 1
    ];
  }
  public static void overrideTransition(LOS_Stage_Transition__mdt row) {
    LOS_ConfigurationService.testData.put(
      'Stage_Transition',
      new List<SObject>{ row }
    );
    LOS_ConfigurationService.reset();
  }
  public static void pauseRule(Boolean counts) {
    LOS_ConfigurationService.testData.put(
      'TAT_Pause_Rule',
      new List<SObject>{
        new LOS_TAT_Pause_Rule__mdt(
          MasterLabel = 'Test Wait',
          LOS_Code__c = 'WAIT_TEST',
          LOS_Active__c = true,
          LOS_Count_Toward_SLA__c = counts,
          LOS_Requires_Comments__c = true
        )
      }
    );
    LOS_ConfigurationService.reset();
  }
  public static void sla(Decimal target, String calendarKey) {
    LOS_ConfigurationService.testData.put(
      'SLA_Rule',
      new List<SObject>{
        new LOS_SLA_Rule__mdt(
          MasterLabel = 'Test SLA',
          LOS_Code__c = 'TEST_SLA',
          LOS_Active__c = true,
          LOS_Target_Minutes__c = target,
          LOS_Priority__c = 1,
          LOS_Business_Hours_Key__c = calendarKey
        )
      }
    );
    LOS_ConfigurationService.reset();
  }
}
