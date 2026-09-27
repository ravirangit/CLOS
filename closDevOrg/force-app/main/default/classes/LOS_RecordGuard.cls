/** Bulk trigger guard. There is no public bypass switch and no profile-based exemption. */
public with sharing class LOS_RecordGuard {
  public static void enforce(
    List<SObject> rows,
    Boolean isInsert,
    Boolean isDelete,
    Boolean immutable
  ) {
    for (SObject row : rows) {
      if (
        isDelete ||
        (immutable && !isInsert) ||
        !LOS_RuntimeService.consumeAuthorization(row, isInsert)
      )
        row.addError(
          'Use the controlled LOS runtime service. Direct changes to this record are not permitted.'
        );
    }
  }
}
