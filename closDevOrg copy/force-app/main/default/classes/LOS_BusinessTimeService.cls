/** All duration arithmetic lives here. No regional calendar assumptions. */
public with sharing class LOS_BusinessTimeService {
  public interface CalendarCalculator {
    Decimal businessMinutes(
      Datetime started,
      Datetime ended,
      String calendarKey
    );
  }
  public class GrossOnly implements CalendarCalculator {
    public Decimal businessMinutes(
      Datetime started,
      Datetime ended,
      String calendarKey
    ) {
      return null;
    }
  }
  @TestVisible
  private static CalendarCalculator calculator = new GrossOnly();
  @TestVisible
  private static Datetime fixedNow;
  public static Datetime nowValue() {
    return fixedNow == null ? System.now() : fixedNow;
  }
  public static Long milliseconds(Datetime started, Datetime ended) {
    if (started == null || ended == null || ended < started)
      throw new LOS_TATException('The time interval is invalid.');
    return ended.getTime() - started.getTime();
  }
  public static Decimal minutes(Long elapsed) {
    if (elapsed == null || elapsed < 0)
      throw new LOS_TATException('The elapsed duration is invalid.');
    return (Decimal.valueOf(String.valueOf(elapsed)) / 60000)
      .setScale(0, RoundingMode.DOWN);
  }
  public static Decimal grossMinutes(Datetime started, Datetime ended) {
    return minutes(milliseconds(started, ended));
  }
  public static Decimal businessMinutes(
    Datetime started,
    Datetime ended,
    String calendarKey
  ) {
    return calculator.businessMinutes(started, ended, calendarKey);
  }
}
