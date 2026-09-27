/** Only supported stage-changing facade. Destination is never accepted as input. */
public with sharing class LOS_LifecycleService {
  public class TransitionRequest {
    public Id applicationId;
    public String transitionCode;
    public Decimal expectedVersion;
    public String reason;
    public String comments;
    public TransitionRequest(
      Id applicationId,
      String transitionCode,
      Decimal expectedVersion
    ) {
      this.applicationId = applicationId;
      this.transitionCode = transitionCode;
      this.expectedVersion = expectedVersion;
    }
  }
  @AuraEnabled
  public static List<LOS_TransitionDTO> getAvailableTransitions(
    Id applicationId
  ) {
    try {
      LOS_Security.requireEdit(new Set<Id>{ applicationId });
      LOS_Credit_Application__c app = LOS_Security.readApplications(
        new Set<Id>{ applicationId }
      )[0];
      List<LOS_TransitionDTO> result = new List<LOS_TransitionDTO>();
      if (app.LOS_Active__c)
        for (
          LOS_ConfigurationService.Config c : LOS_ConfigurationService.getTransitions(
            app.LOS_Current_Stage__c,
            app.LOS_Application_Type__c
          )
        )
          result.add(new LOS_TransitionDTO(c, app.LOS_Runtime_Version__c));
      return result;
    } catch (Exception e) {
      throw LOS_Exception.forClient(e);
    }
  }
  @AuraEnabled
  public static LOS_ApplicationDTO transitionApplication(
    Id applicationId,
    String transitionCode,
    Decimal expectedVersion,
    String reason,
    String comments
  ) {
    try {
      TransitionRequest request = new TransitionRequest(
        applicationId,
        transitionCode,
        expectedVersion
      );
      request.reason = reason;
      request.comments = comments;
      return transitionApplications(new List<TransitionRequest>{ request })[0];
    } catch (Exception e) {
      throw LOS_Exception.forClient(e);
    }
  }
  public static List<LOS_ApplicationDTO> transitionApplications(
    List<TransitionRequest> requests
  ) {
    return LOS_RuntimeService.transitionApplications(requests);
  }
}
