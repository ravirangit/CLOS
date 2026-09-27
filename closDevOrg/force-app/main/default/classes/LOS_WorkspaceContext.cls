/** Typed, read-only wire contract for the lending UI. */
public class LOS_WorkspaceContext {
  @AuraEnabled
  public LOS_ApplicationDTO application { get; set; }
  @AuraEnabled
  public String relationshipName { get; set; }
  @AuraEnabled
  public Id relationshipId { get; set; }
  @AuraEnabled
  public String stageLabel { get; set; }
  @AuraEnabled
  public String applicationTypeLabel { get; set; }
  @AuraEnabled
  public Decimal reworkCount { get; set; }
  @AuraEnabled
  public String primaryRM { get; set; }
  @AuraEnabled
  public String currentOwnerUser { get; set; }
  @AuraEnabled
  public String currentQueueKey { get; set; }
  @AuraEnabled
  public String organizationUnit { get; set; }
  @AuraEnabled
  public String businessUnitSnapshot { get; set; }
  @AuraEnabled
  public String segmentSnapshot { get; set; }
  @AuraEnabled
  public String branchSnapshot { get; set; }
  @AuraEnabled
  public Boolean canTransition { get; set; }
  @AuraEnabled
  public Datetime loadedAt { get; set; }
  @AuraEnabled
  public List<String> personas { get; set; }
  @AuraEnabled
  public List<String> health { get; set; }
  @AuraEnabled
  public List<LOS_WorkspaceSectionDTO> navigationSections { get; set; }
  @AuraEnabled
  public List<LOS_WorkspaceActionDTO> actions { get; set; }
  @AuraEnabled
  public List<LOS_WorkspaceActionDTO> availableTransitions { get; set; }
  @AuraEnabled
  public List<LOS_WorkspaceHistoryDTO> lifecycleHistory { get; set; }
  @AuraEnabled
  public Boolean historyHasMore { get; set; }
  @AuraEnabled
  public LOS_WorkspaceTatDTO tat { get; set; }
}
