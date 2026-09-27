/** Read-only response. Version must be returned with the next lifecycle request. */
public class LOS_ApplicationDTO {
  @AuraEnabled
  public Id applicationId { get; private set; }
  @AuraEnabled
  public String applicationNumber { get; private set; }
  @AuraEnabled
  public String applicationTypeCode { get; private set; }
  @AuraEnabled
  public String stageCode { get; private set; }
  @AuraEnabled
  public String status { get; private set; }
  @AuraEnabled
  public Decimal reworkNumber { get; private set; }
  @AuraEnabled
  public Decimal version { get; private set; }
  public LOS_ApplicationDTO(LOS_Credit_Application__c row) {
    applicationId = row.Id;
    applicationNumber = row.Name;
    applicationTypeCode = row.LOS_Application_Type__c;
    stageCode = row.LOS_Current_Stage__c;
    status = row.LOS_Status__c;
    reworkNumber = row.LOS_Current_Rework_Number__c;
    version = row.LOS_Runtime_Version__c;
  }
}
