/** Product-owned validator allowlist. Metadata supplies policy keys, never class names. */
public with sharing class LOS_ValidationRegistry {
  // Future product modules add explicit code -> new Validator() entries here.
  // No lending validators are shipped in Task 02.1.
  private static final Map<String, LOS_ValidationService.Hook> implementations = new Map<String, LOS_ValidationService.Hook>();
  private static Map<String, LOS_ValidationService.Hook> testHooks = new Map<String, LOS_ValidationService.Hook>();
  public static LOS_ValidationService.Hook resolve(String code) {
    LOS_ValidationService.Hook implementation = implementations.get(code);
    if (Test.isRunningTest() && testHooks.containsKey(code))
      implementation = testHooks.get(code);
    if (implementation == null)
      throw new LOS_ConfigurationException(
        'The configured validation policy is not registered.'
      );
    return implementation;
  }
  // Test-only injection cannot replace product-owned validators.
  @TestVisible
  private static void registerTestHook(
    String code,
    LOS_ValidationService.Hook implementation
  ) {
    if (
      !Test.isRunningTest() ||
      String.isBlank(code) ||
      implementation == null ||
      implementations.containsKey(code) ||
      testHooks.containsKey(code)
    )
      throw new LOS_ConfigurationException(
        'Validation hook registration is invalid.'
      );
    testHooks.put(code, implementation);
  }
}
