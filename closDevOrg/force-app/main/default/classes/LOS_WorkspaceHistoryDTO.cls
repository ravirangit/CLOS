/** Typed, read-only wire contract for the lending UI. */
public class LOS_WorkspaceHistoryDTO {
  @AuraEnabled
  public Id id { get; set; }
  @AuraEnabled
  public Datetime occurredAt { get; set; }
  @AuraEnabled
  public String fromStage { get; set; }
  @AuraEnabled
  public String toStage { get; set; }
  @AuraEnabled
  public String transitionType { get; set; }
  @AuraEnabled
  public String performedBy { get; set; }
  @AuraEnabled
  public Decimal reworkNumber { get; set; }
  @AuraEnabled
  public String reason { get; set; }
  @AuraEnabled
  public String comments { get; set; }
}
