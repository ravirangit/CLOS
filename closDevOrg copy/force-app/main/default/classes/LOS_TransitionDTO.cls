public class LOS_TransitionDTO {
  @AuraEnabled
  public String code { get; private set; }
  @AuraEnabled
  public String label { get; private set; }
  @AuraEnabled
  public String destinationStageCode { get; private set; }
  @AuraEnabled
  public Boolean requiresReason { get; private set; }
  @AuraEnabled
  public Decimal expectedVersion { get; private set; }
  public LOS_TransitionDTO(
    LOS_ConfigurationService.Config config,
    Decimal version
  ) {
    code = config.code;
    label = config.label;
    destinationStageCode = config.toStage;
    requiresReason = config.requiresReason;
    expectedVersion = version;
  }
}
