/** Typed, read-only wire contract for the lending UI. */
public class LOS_WorkspaceApplicationDTO {
  @AuraEnabled
  public Id id { get; set; }
  @AuraEnabled
  public String applicationNumber { get; set; }
  @AuraEnabled
  public String relationship { get; set; }
  @AuraEnabled
  public String applicationType { get; set; }
  @AuraEnabled
  public String stage { get; set; }
  @AuraEnabled
  public String status { get; set; }
  @AuraEnabled
  public String assignee { get; set; }
  @AuraEnabled
  public String organizationUnit { get; set; }
  @AuraEnabled
  public Decimal reworkNumber { get; set; }
  @AuraEnabled
  public Datetime modifiedAt { get; set; }
}
