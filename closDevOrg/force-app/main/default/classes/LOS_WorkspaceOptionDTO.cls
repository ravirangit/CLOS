/** Typed, read-only wire contract for the lending UI. */
public class LOS_WorkspaceOptionDTO {
  @AuraEnabled
  public String value { get; set; }
  @AuraEnabled
  public String label { get; set; }
  @AuraEnabled
  public Boolean baselineRequired { get; set; }
}
