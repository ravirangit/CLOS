/** Typed, read-only wire contract for the lending UI. */
public class LOS_WorkspaceTatDTO {
  @AuraEnabled
  public Id id { get; set; }
  @AuraEnabled
  public String stageCode { get; set; }
  @AuraEnabled
  public Datetime startedAt { get; set; }
  @AuraEnabled
  public Decimal grossMinutes { get; set; }
  @AuraEnabled
  public Decimal businessMinutes { get; set; }
  @AuraEnabled
  public Decimal targetMinutes { get; set; }
  @AuraEnabled
  public Decimal pausedMinutes { get; set; }
  @AuraEnabled
  public Boolean hasVisiblePause { get; set; }
  @AuraEnabled
  public String availability { get; set; }
}
