// Optional synthetic development fixture. Never included in the product package.
// Run as the authorized development administrator; does not create a credit application.
List<LOS_Organization_Unit__c> units = [SELECT Id FROM LOS_Organization_Unit__c WHERE LOS_Code__c = 'LOS_UI_DEMO' WITH USER_MODE LIMIT 1];
if (units.isEmpty()) {
    LOS_Organization_Unit__c unit = new LOS_Organization_Unit__c(Name='LOS Workspace Demo Unit',LOS_Code__c='LOS_UI_DEMO',LOS_Unit_Type__c='REFERENCE_TEST',LOS_Active__c=true);
    insert as user unit;
    units.add(unit);
}
List<Account> accounts = [SELECT Id FROM Account WHERE Name='LOS Workspace Demo Customer' WITH USER_MODE LIMIT 1];
if (accounts.isEmpty()) {
    Account account = new Account(Name='LOS Workspace Demo Customer');
    insert as user account;
    accounts.add(account);
}
List<LOS_Relationship__c> relationships = [SELECT Id FROM LOS_Relationship__c WHERE LOS_Relationship_Number__c='LOS_UI_DEMO' WITH USER_MODE LIMIT 1];
if (relationships.isEmpty()) {
    LOS_Relationship__c relationship = new LOS_Relationship__c(Name='LOS Workspace Demo',LOS_Relationship_Number__c='LOS_UI_DEMO',LOS_Account__c=accounts[0].Id,LOS_Primary_Organization_Unit__c=units[0].Id,LOS_Primary_RM__c=UserInfo.getUserId(),LOS_Active__c=true);
    insert as user relationship;
    relationships.add(relationship);
}
System.debug('LOS workspace demo relationship: '+relationships[0].Id);
