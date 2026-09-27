/** Typed, read-only wire contract for the lending UI. */
public class LOS_WorkspaceSectionDTO {
  @AuraEnabled
  public String code { get; set; }
  @AuraEnabled
  public String label { get; set; }
  @AuraEnabled
  public String componentKey { get; set; }
  @AuraEnabled
  public Decimal sequence { get; set; }
}
