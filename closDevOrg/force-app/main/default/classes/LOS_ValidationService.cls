/** Trusted Apex modules may register allowlisted hooks. No dynamic class names from metadata. */
public with sharing class LOS_ValidationService {
  public class Result {
    public String severity { get; private set; }
    public String code { get; private set; }
    public String message { get; private set; }
    public Boolean blocking { get; private set; }
    public Result(
      String severity,
      String code,
      String message,
      Boolean blocking
    ) {
      this.severity = severity;
      this.code = code;
      this.message = message;
      this.blocking = blocking;
    }
  }
  public class Context {
    public LOS_Credit_Application__c application;
    public LOS_ConfigurationService.Config transition;
    public String reason;
    public String comments;
  }
  public interface Hook {
    List<Result> validate(Context context);
  }
  @TestVisible
  private static Map<String, Hook> hooks = new Map<String, Hook>();
  public static void registerHook(String code, Hook implementation) {
    if (
      String.isBlank(code) ||
      implementation == null ||
      hooks.containsKey(code)
    )
      throw new LOS_ConfigurationException(
        'Validation hook registration is invalid.'
      );
    hooks.put(code, implementation);
  }
  public static List<Result> validate(Context context) {
    List<Result> results = new List<Result>();
    if (
      context.application.LOS_Relationship__c == null ||
      context.application.LOS_Organization_Unit__c == null
    )
      results.add(
        new Result(
          'Error',
          'CONTEXT_REQUIRED',
          'Application relationship and organization context are required.',
          true
        )
      );
    if (context.transition.requiresReason && String.isBlank(context.reason))
      results.add(
        new Result(
          'Error',
          'REASON_REQUIRED',
          'Enter a reason for this transition.',
          true
        )
      );
    if (
      (context.reason != null && context.reason.length() > 32768) ||
      (context.comments != null &&
      context.comments.length() > 32768)
    )
      results.add(
        new Result(
          'Error',
          'TEXT_TOO_LONG',
          'Reason and comments must each be 32768 characters or fewer.',
          true
        )
      );
    if (
      context.transition.requiresValidation &&
      !String.isBlank(context.transition.validationPolicy)
    ) {
      Hook implementation = hooks.get(context.transition.validationPolicy);
      if (implementation == null)
        throw new LOS_ConfigurationException(
          'The configured validation policy is not registered.'
        );
      // Hooks receive a copy; changing the validation context cannot change the pending application.
      Integer beforeDml = Limits.getDmlStatements();
      Integer beforeCallouts = Limits.getCallouts();
      List<Result> customResults = implementation.validate(context);
      if (
        Limits.getDmlStatements() != beforeDml ||
        Limits.getCallouts() != beforeCallouts
      )
        throw new LOS_ConfigurationException(
          'Validation hooks must not perform DML or callouts.'
        );
      if (customResults == null)
        throw new LOS_ConfigurationException(
          'The validation policy returned no result.'
        );
      results.addAll(customResults);
    }
    return results;
  }
  public static void requireValid(Context context) {
    List<Result> results = validate(context);
    for (Result r : results) {
      if (r == null)
        throw new LOS_ConfigurationException(
          'The validation policy returned an invalid result.'
        );
      if (r.blocking) {
        LOS_ValidationException failure = new LOS_ValidationException(
          r.message
        );
        failure.results = results;
        throw failure;
      }
    }
  }
}
