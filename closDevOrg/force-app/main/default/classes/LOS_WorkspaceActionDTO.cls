/** Typed, read-only wire contract for the lending UI. */
public class LOS_WorkspaceActionDTO {
  @AuraEnabled
  public String code { get; set; }
  @AuraEnabled
  public String label { get; set; }
  @AuraEnabled
  public String handlerKey { get; set; }
  @AuraEnabled
  public String sectionCode { get; set; }
  @AuraEnabled
  public String transitionCode { get; set; }
  @AuraEnabled
  public String transitionType { get; set; }
  @AuraEnabled
  public Boolean requiresReason { get; set; }
  @AuraEnabled
  public Boolean requiresValidation { get; set; }
  @AuraEnabled
  public Boolean requiresConfirmation { get; set; }
  @AuraEnabled
  public Decimal expectedVersion { get; set; }
  @AuraEnabled
  public Decimal sequence { get; set; }
}
