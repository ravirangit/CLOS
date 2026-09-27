/** Supported creation facade. Only relationship, configured type and optional baseline are inputs. */
public with sharing class LOS_ApplicationService {
  public class CreateRequest {
    public Id relationshipId;
    public String applicationTypeCode;
    public Id baselineApplicationId;
    public CreateRequest(Id relationshipId, String applicationTypeCode) {
      this.relationshipId = relationshipId;
      this.applicationTypeCode = applicationTypeCode;
    }
  }
  @AuraEnabled
  public static LOS_ApplicationDTO createApplication(
    Id relationshipId,
    String applicationTypeCode,
    Id baselineApplicationId
  ) {
    try {
      CreateRequest request = new CreateRequest(
        relationshipId,
        applicationTypeCode
      );
      request.baselineApplicationId = baselineApplicationId;
      return createApplications(new List<CreateRequest>{ request })[0];
    } catch (Exception e) {
      throw LOS_Exception.forClient(e);
    }
  }
  public static List<LOS_ApplicationDTO> createApplications(
    List<CreateRequest> requests
  ) {
    return LOS_RuntimeService.createApplications(requests);
  }
}
