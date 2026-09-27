public virtual class LOS_Exception extends Exception {
  public static AuraHandledException forClient(Exception problem) {
    String message = problem instanceof LOS_Exception
      ? problem.getMessage()
      : 'The request could not be completed. Refresh and try again.';
    AuraHandledException result = new AuraHandledException(message);
    result.setMessage(message);
    return result;
  }
}
