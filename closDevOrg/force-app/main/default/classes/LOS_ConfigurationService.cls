/** Sole metadata repository. Immutable wrappers and lazy transaction-scoped caches. */
public with sharing class LOS_ConfigurationService {
  public class Config {
    public Boolean active { get; private set; }
    public String applicationType { get; private set; }
    public Boolean approvalStage { get; private set; }
    public String authorizationPolicy { get; private set; }
    public Boolean baselineRequired { get; private set; }
    public Boolean bookingStage { get; private set; }
    public String calendarKey { get; private set; }
    public String code { get; private set; }
    public String componentKey { get; private set; }
    public Boolean countTowardSLA { get; private set; }
    public String defaultApplicationStatus { get; private set; }
    public String description { get; private set; }
    public Boolean documentationStage { get; private set; }
    public Date effectiveFrom { get; private set; }
    public Date effectiveTo { get; private set; }
    public String fromStage { get; private set; }
    public String handlerKey { get; private set; }
    public String initialStage { get; private set; }
    public String label { get; private set; }
    public String persona { get; private set; }
    public Decimal priority { get; private set; }
    public Boolean requiresComments { get; private set; }
    public Boolean requiresConfirmation { get; private set; }
    public Boolean requiresReason { get; private set; }
    public Boolean requiresValidation { get; private set; }
    public String section { get; private set; }
    public Decimal sequence { get; private set; }
    public String stage { get; private set; }
    public Decimal targetMinutes { get; private set; }
    public Boolean tatEnabled { get; private set; }
    public Boolean terminal { get; private set; }
    public String toStage { get; private set; }
    public String transition { get; private set; }
    public String transitionType { get; private set; }
    public String unitType { get; private set; }
    public String validationPolicy { get; private set; }
    public String visibilityPolicy { get; private set; }
    public Decimal warningMinutes { get; private set; }
    private Config() {
    }
  }
  private static Map<String, List<Config>> cache = new Map<String, List<Config>>();
  @TestVisible
  private static Map<String, List<SObject>> testData = new Map<String, List<SObject>>();
  @TestVisible
  private static void reset() {
    cache.clear();
  }
  private static List<Config> read(String kind) {
    if (!cache.containsKey(kind)) {
      List<SObject> rows;
      if (testData.containsKey(kind))
        rows = testData.get(kind);
      else if (kind == 'Application_Type')
        rows = [
          SELECT
            MasterLabel,
            LOS_Code__c,
            LOS_Active__c,
            LOS_Description__c,
            LOS_Sequence__c,
            LOS_Baseline_Required__c,
            LOS_Initial_Stage__c,
            LOS_Initial_Stage__r.LOS_Code__c
          FROM LOS_Application_Type__mdt
          WITH SYSTEM_MODE
          ORDER BY DeveloperName
        ];
      else if (kind == 'Stage')
        rows = [
          SELECT
            MasterLabel,
            LOS_Code__c,
            LOS_Active__c,
            LOS_Description__c,
            LOS_Sequence__c,
            LOS_Display_Label__c,
            LOS_Terminal_Stage__c,
            LOS_TAT_Enabled__c,
            LOS_Approval_Stage__c,
            LOS_Documentation_Stage__c,
            LOS_Booking_Stage__c,
            LOS_Default_Application_Status__c
          FROM LOS_Stage__mdt
          WITH SYSTEM_MODE
          ORDER BY DeveloperName
        ];
      else if (kind == 'Stage_Transition')
        rows = [
          SELECT
            MasterLabel,
            LOS_Code__c,
            LOS_Active__c,
            LOS_Description__c,
            LOS_From_Stage__c,
            LOS_To_Stage__c,
            LOS_Application_Type__c,
            LOS_Transition_Type__c,
            LOS_Action_Label__c,
            LOS_Requires_Reason__c,
            LOS_Requires_Validation__c,
            LOS_Validation_Policy_Code__c,
            LOS_Sequence__c,
            LOS_From_Stage__r.LOS_Code__c,
            LOS_To_Stage__r.LOS_Code__c,
            LOS_Application_Type__r.LOS_Code__c
          FROM LOS_Stage_Transition__mdt
          WITH SYSTEM_MODE
          ORDER BY DeveloperName
        ];
      else if (kind == 'Persona')
        rows = [
          SELECT
            MasterLabel,
            LOS_Code__c,
            LOS_Active__c,
            LOS_Description__c,
            LOS_Display_Label__c
          FROM LOS_Persona__mdt
          WITH SYSTEM_MODE
          ORDER BY DeveloperName
        ];
      else if (kind == 'Workspace_Section')
        rows = [
          SELECT
            MasterLabel,
            LOS_Code__c,
            LOS_Active__c,
            LOS_Description__c,
            LOS_Application_Type__c,
            LOS_Stage__c,
            LOS_Persona__c,
            LOS_Display_Label__c,
            LOS_Component_Key__c,
            LOS_Visibility_Policy_Code__c,
            LOS_Sequence__c,
            LOS_Application_Type__r.LOS_Code__c,
            LOS_Stage__r.LOS_Code__c,
            LOS_Persona__r.LOS_Code__c
          FROM LOS_Workspace_Section__mdt
          WITH SYSTEM_MODE
          ORDER BY DeveloperName
        ];
      else if (kind == 'Workspace_Action')
        rows = [
          SELECT
            MasterLabel,
            LOS_Code__c,
            LOS_Active__c,
            LOS_Description__c,
            LOS_Application_Type__c,
            LOS_Stage__c,
            LOS_Persona__c,
            LOS_Section__c,
            LOS_Transition__c,
            LOS_Display_Label__c,
            LOS_Handler_Key__c,
            LOS_Authorization_Policy_Code__c,
            LOS_Sequence__c,
            LOS_Requires_Confirmation__c,
            LOS_Application_Type__r.LOS_Code__c,
            LOS_Stage__r.LOS_Code__c,
            LOS_Persona__r.LOS_Code__c,
            LOS_Section__r.LOS_Code__c,
            LOS_Transition__r.LOS_Code__c
          FROM LOS_Workspace_Action__mdt
          WITH SYSTEM_MODE
          ORDER BY DeveloperName
        ];
      else if (kind == 'SLA_Rule')
        rows = [
          SELECT
            MasterLabel,
            LOS_Code__c,
            LOS_Active__c,
            LOS_Description__c,
            LOS_Application_Type__c,
            LOS_Stage__c,
            LOS_Persona__c,
            LOS_Org_Unit_Type__c,
            LOS_Target_Minutes__c,
            LOS_Warning_Minutes__c,
            LOS_Priority__c,
            LOS_Business_Hours_Key__c,
            LOS_Effective_From__c,
            LOS_Effective_To__c,
            LOS_Application_Type__r.LOS_Code__c,
            LOS_Stage__r.LOS_Code__c,
            LOS_Persona__r.LOS_Code__c,
            LOS_Org_Unit_Type__r.LOS_Code__c
          FROM LOS_SLA_Rule__mdt
          WITH SYSTEM_MODE
          ORDER BY DeveloperName
        ];
      else if (kind == 'TAT_Pause_Rule')
        rows = [
          SELECT
            MasterLabel,
            LOS_Code__c,
            LOS_Active__c,
            LOS_Description__c,
            LOS_Application_Type__c,
            LOS_Stage__c,
            LOS_Display_Label__c,
            LOS_Count_Toward_SLA__c,
            LOS_Requires_Comments__c,
            LOS_Sequence__c,
            LOS_Application_Type__r.LOS_Code__c,
            LOS_Stage__r.LOS_Code__c
          FROM LOS_TAT_Pause_Rule__mdt
          WITH SYSTEM_MODE
          ORDER BY DeveloperName
        ];
      else if (kind == 'Org_Unit_Type')
        rows = [
          SELECT
            MasterLabel,
            LOS_Code__c,
            LOS_Active__c,
            LOS_Description__c,
            LOS_Display_Label__c,
            LOS_Sequence__c
          FROM LOS_Org_Unit_Type__mdt
          WITH SYSTEM_MODE
          ORDER BY DeveloperName
        ];
      else
        throw new LOS_ConfigurationException('Unknown configuration category.');
      List<Config> values = new List<Config>();
      Set<String> keys = new Set<String>();
      for (SObject row : rows) {
        if (row.get('LOS_Active__c') != true)
          continue;
        Config c = new Config();
        c.label = (String) row.get('MasterLabel');
        if (kind == 'Application_Type') {
          c.code = (String) row.get('LOS_Code__c');
          c.active = (Boolean) row.get('LOS_Active__c');
          c.description = (String) row.get('LOS_Description__c');
          c.sequence = (Decimal) row.get('LOS_Sequence__c');
          c.baselineRequired = (Boolean) row.get('LOS_Baseline_Required__c');
          c.initialStage = row.getSObject('LOS_Initial_Stage__r') == null
            ? null
            : (String) row.getSObject('LOS_Initial_Stage__r')
                .get('LOS_Code__c');
        }
        if (kind == 'Stage') {
          c.code = (String) row.get('LOS_Code__c');
          c.active = (Boolean) row.get('LOS_Active__c');
          c.description = (String) row.get('LOS_Description__c');
          c.sequence = (Decimal) row.get('LOS_Sequence__c');
          c.label = (String) row.get('LOS_Display_Label__c');
          c.terminal = (Boolean) row.get('LOS_Terminal_Stage__c');
          c.tatEnabled = (Boolean) row.get('LOS_TAT_Enabled__c');
          c.approvalStage = (Boolean) row.get('LOS_Approval_Stage__c');
          c.documentationStage = (Boolean) row.get(
            'LOS_Documentation_Stage__c'
          );
          c.bookingStage = (Boolean) row.get('LOS_Booking_Stage__c');
          c.defaultApplicationStatus = (String) row.get(
            'LOS_Default_Application_Status__c'
          );
        }
        if (kind == 'Stage_Transition') {
          c.code = (String) row.get('LOS_Code__c');
          c.active = (Boolean) row.get('LOS_Active__c');
          c.description = (String) row.get('LOS_Description__c');
          c.fromStage = row.getSObject('LOS_From_Stage__r') == null
            ? null
            : (String) row.getSObject('LOS_From_Stage__r').get('LOS_Code__c');
          c.toStage = row.getSObject('LOS_To_Stage__r') == null
            ? null
            : (String) row.getSObject('LOS_To_Stage__r').get('LOS_Code__c');
          c.applicationType = row.getSObject('LOS_Application_Type__r') == null
            ? null
            : (String) row.getSObject('LOS_Application_Type__r')
                .get('LOS_Code__c');
          c.transitionType = (String) row.get('LOS_Transition_Type__c');
          c.label = (String) row.get('LOS_Action_Label__c');
          c.requiresReason = (Boolean) row.get('LOS_Requires_Reason__c');
          c.requiresValidation = (Boolean) row.get(
            'LOS_Requires_Validation__c'
          );
          c.validationPolicy = (String) row.get(
            'LOS_Validation_Policy_Code__c'
          );
          c.sequence = (Decimal) row.get('LOS_Sequence__c');
        }
        if (kind == 'Persona') {
          c.code = (String) row.get('LOS_Code__c');
          c.active = (Boolean) row.get('LOS_Active__c');
          c.description = (String) row.get('LOS_Description__c');
          c.label = (String) row.get('LOS_Display_Label__c');
        }
        if (kind == 'Workspace_Section') {
          c.code = (String) row.get('LOS_Code__c');
          c.active = (Boolean) row.get('LOS_Active__c');
          c.description = (String) row.get('LOS_Description__c');
          c.applicationType = row.getSObject('LOS_Application_Type__r') == null
            ? null
            : (String) row.getSObject('LOS_Application_Type__r')
                .get('LOS_Code__c');
          c.stage = row.getSObject('LOS_Stage__r') == null
            ? null
            : (String) row.getSObject('LOS_Stage__r').get('LOS_Code__c');
          c.persona = row.getSObject('LOS_Persona__r') == null
            ? null
            : (String) row.getSObject('LOS_Persona__r').get('LOS_Code__c');
          c.label = (String) row.get('LOS_Display_Label__c');
          c.componentKey = (String) row.get('LOS_Component_Key__c');
          c.visibilityPolicy = (String) row.get(
            'LOS_Visibility_Policy_Code__c'
          );
          c.sequence = (Decimal) row.get('LOS_Sequence__c');
        }
        if (kind == 'Workspace_Action') {
          c.code = (String) row.get('LOS_Code__c');
          c.active = (Boolean) row.get('LOS_Active__c');
          c.description = (String) row.get('LOS_Description__c');
          c.applicationType = row.getSObject('LOS_Application_Type__r') == null
            ? null
            : (String) row.getSObject('LOS_Application_Type__r')
                .get('LOS_Code__c');
          c.stage = row.getSObject('LOS_Stage__r') == null
            ? null
            : (String) row.getSObject('LOS_Stage__r').get('LOS_Code__c');
          c.persona = row.getSObject('LOS_Persona__r') == null
            ? null
            : (String) row.getSObject('LOS_Persona__r').get('LOS_Code__c');
          c.section = row.getSObject('LOS_Section__r') == null
            ? null
            : (String) row.getSObject('LOS_Section__r').get('LOS_Code__c');
          c.transition = row.getSObject('LOS_Transition__r') == null
            ? null
            : (String) row.getSObject('LOS_Transition__r').get('LOS_Code__c');
          c.label = (String) row.get('LOS_Display_Label__c');
          c.handlerKey = (String) row.get('LOS_Handler_Key__c');
          c.authorizationPolicy = (String) row.get(
            'LOS_Authorization_Policy_Code__c'
          );
          c.sequence = (Decimal) row.get('LOS_Sequence__c');
          c.requiresConfirmation = (Boolean) row.get(
            'LOS_Requires_Confirmation__c'
          );
        }
        if (kind == 'SLA_Rule') {
          c.code = (String) row.get('LOS_Code__c');
          c.active = (Boolean) row.get('LOS_Active__c');
          c.description = (String) row.get('LOS_Description__c');
          c.applicationType = row.getSObject('LOS_Application_Type__r') == null
            ? null
            : (String) row.getSObject('LOS_Application_Type__r')
                .get('LOS_Code__c');
          c.stage = row.getSObject('LOS_Stage__r') == null
            ? null
            : (String) row.getSObject('LOS_Stage__r').get('LOS_Code__c');
          c.persona = row.getSObject('LOS_Persona__r') == null
            ? null
            : (String) row.getSObject('LOS_Persona__r').get('LOS_Code__c');
          c.unitType = row.getSObject('LOS_Org_Unit_Type__r') == null
            ? null
            : (String) row.getSObject('LOS_Org_Unit_Type__r')
                .get('LOS_Code__c');
          c.targetMinutes = (Decimal) row.get('LOS_Target_Minutes__c');
          c.warningMinutes = (Decimal) row.get('LOS_Warning_Minutes__c');
          c.priority = (Decimal) row.get('LOS_Priority__c');
          c.calendarKey = (String) row.get('LOS_Business_Hours_Key__c');
          c.effectiveFrom = (Date) row.get('LOS_Effective_From__c');
          c.effectiveTo = (Date) row.get('LOS_Effective_To__c');
        }
        if (kind == 'TAT_Pause_Rule') {
          c.code = (String) row.get('LOS_Code__c');
          c.active = (Boolean) row.get('LOS_Active__c');
          c.description = (String) row.get('LOS_Description__c');
          c.applicationType = row.getSObject('LOS_Application_Type__r') == null
            ? null
            : (String) row.getSObject('LOS_Application_Type__r')
                .get('LOS_Code__c');
          c.stage = row.getSObject('LOS_Stage__r') == null
            ? null
            : (String) row.getSObject('LOS_Stage__r').get('LOS_Code__c');
          c.label = (String) row.get('LOS_Display_Label__c');
          c.countTowardSLA = (Boolean) row.get('LOS_Count_Toward_SLA__c');
          c.requiresComments = (Boolean) row.get('LOS_Requires_Comments__c');
          c.sequence = (Decimal) row.get('LOS_Sequence__c');
        }
        if (kind == 'Org_Unit_Type') {
          c.code = (String) row.get('LOS_Code__c');
          c.active = (Boolean) row.get('LOS_Active__c');
          c.description = (String) row.get('LOS_Description__c');
          c.label = (String) row.get('LOS_Display_Label__c');
          c.sequence = (Decimal) row.get('LOS_Sequence__c');
        }
        if (String.isBlank(c.code))
          throw new LOS_ConfigurationException(
            'An active configuration record has no code.'
          );
        String key = c.code;
        if (kind == 'Stage_Transition')
          key += '|' + c.applicationType;
        if (kind == 'TAT_Pause_Rule')
          key += '|' + c.applicationType + '|' + c.stage;
        if (!keys.add(key))
          throw new LOS_ConfigurationException(
            'Duplicate active configuration code: ' + c.code
          );
        values.add(c);
      }
      cache.put(kind, values);
    }
    return new List<Config>(cache.get(kind));
  }
  public static List<Config> getApplicationTypes() {
    return read('Application_Type');
  }
  public static List<Config> getStages() {
    return read('Stage');
  }
  public static List<Config> getPersonas() {
    return read('Persona');
  }
  public static List<Config> getWorkspaceSections() {
    return read('Workspace_Section');
  }
  public static List<Config> getWorkspaceActions() {
    return read('Workspace_Action');
  }
  public static List<Config> getSLARules() {
    return read('SLA_Rule');
  }
  public static List<Config> getPauseRules() {
    return read('TAT_Pause_Rule');
  }
  public static List<Config> getOrgUnitTypes() {
    return read('Org_Unit_Type');
  }
  private static Config find(List<Config> values, String code) {
    for (Config c : values)
      if (c.code == code)
        return c;
    throw new LOS_ConfigurationException(
      'The requested configuration code is unavailable.'
    );
  }
  public static Config getApplicationType(String code) {
    return find(getApplicationTypes(), code);
  }
  public static Config getStage(String code) {
    Config stage = find(getStages(), code);
    String status = stage.defaultApplicationStatus;
    if (
      String.isBlank(status) ||
      status.length() > 255 ||
      status != status.trim()
    )
      throw new LOS_ConfigurationException(
        'The stage default application status is missing or invalid.'
      );
    return stage;
  }
  public static Config getInitialStage(String typeCode) {
    Config t = getApplicationType(typeCode);
    if (String.isBlank(t.initialStage))
      throw new LOS_ConfigurationException(
        'An initial stage must be configured for this application type.'
      );
    Config stage = getStage(t.initialStage);
    if (stage.terminal)
      throw new LOS_ConfigurationException(
        'An initial stage cannot be terminal.'
      );
    return stage;
  }
  public static Config getTransition(String code, String typeCode) {
    getApplicationType(typeCode);
    Config globalRule;
    Config specific;
    for (Config c : read('Stage_Transition'))
      if (c.code == code) {
        if (c.applicationType == typeCode)
          specific = c;
        else if (String.isBlank(c.applicationType))
          globalRule = c;
      }
    Config result = specific == null ? globalRule : specific;
    if (result == null)
      throw new LOS_ConfigurationException('This transition is unavailable.');
    getStage(result.fromStage);
    getStage(result.toStage);
    if (
      !new Set<String>{ 'Forward', 'Rework', 'Approval' }
        .contains(result.transitionType)
    )
      throw new LOS_ConfigurationException(
        'The configured transition type is unsupported.'
      );
    return result;
  }
  public static List<Config> getTransitions(String stageCode, String typeCode) {
    Config stage = getStage(stageCode);
    List<Config> result = new List<Config>();
    if (stage.terminal)
      return result;
    Set<String> seen = new Set<String>();
    for (Config c : read('Stage_Transition')) {
      if (
        c.fromStage != stageCode ||
        (c.applicationType != null &&
        c.applicationType != typeCode)
      )
        continue;
      if (!seen.add(c.code))
        continue;
      Config resolved = getTransition(c.code, typeCode);
      if (resolved.fromStage == stageCode)
        result.add(resolved);
    }
    return result;
  }
  private static Boolean matches(String configured, String actual) {
    return String.isBlank(configured) || configured == actual;
  }
  public static Config getPauseRule(
    String code,
    String typeCode,
    String stageCode
  ) {
    Config result;
    Integer best = -1;
    Boolean tied = false;
    for (Config c : getPauseRules())
      if (
        c.code == code &&
        matches(c.applicationType, typeCode) &&
        matches(c.stage, stageCode)
      ) {
        Integer rank =
          (String.isBlank(c.applicationType) ? 0 : 1) +
          (String.isBlank(c.stage) ? 0 : 1);
        if (rank == best)
          tied = true;
        if (rank > best) {
          result = c;
          best = rank;
          tied = false;
        }
      }
    if (tied)
      throw new LOS_ConfigurationException('Pause policy is ambiguous.');
    if (result == null)
      throw new LOS_ConfigurationException('This pause reason is unavailable.');
    return result;
  }
  public static Config selectSLA(
    String typeCode,
    String stageCode,
    String unitType,
    Set<String> personas,
    Date onDate
  ) {
    Config result;
    Boolean tied = false;
    for (Config c : getSLARules()) {
      if (
        !matches(c.applicationType, typeCode) ||
        !matches(c.stage, stageCode) ||
        !matches(c.unitType, unitType)
      )
        continue;
      if (!String.isBlank(c.persona) && !personas.contains(c.persona))
        continue;
      if (
        (c.effectiveFrom != null && c.effectiveFrom > onDate) ||
        (c.effectiveTo != null &&
        c.effectiveTo < onDate)
      )
        continue;
      if (
        c.targetMinutes == null ||
        c.targetMinutes < 0 ||
        c.priority == null ||
        (c.warningMinutes != null &&
        (c.warningMinutes < 0 ||
        c.warningMinutes > c.targetMinutes)) ||
        (c.effectiveFrom != null &&
        c.effectiveTo != null &&
        c.effectiveFrom > c.effectiveTo)
      )
        throw new LOS_ConfigurationException(
          'An applicable SLA rule is invalid.'
        );
      if (result != null && result.priority == c.priority)
        tied = true;
      if (result == null || c.priority > result.priority) {
        result = c;
        tied = false;
      }
    }
    if (tied)
      throw new LOS_ConfigurationException('SLA priority is ambiguous.');
    return result;
  }
}
