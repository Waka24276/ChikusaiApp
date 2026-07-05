

/// Helper function to add a specified number of working days to a given date.
/// Weekends (Saturday and Sunday) are skipped.
DateTime addWorkingDays(DateTime startDate, int daysToAdd) {
  DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
  int addedDays = 0;

  while (addedDays < daysToAdd) {
    currentDate = currentDate.add(const Duration(days: 1));

    final bool isSpecificHoliday = 
        (currentDate.month == 7 && currentDate.day == 20) || 
        (currentDate.month == 8 && currentDate.day == 11);

    if (currentDate.weekday >= DateTime.monday && currentDate.weekday <= DateTime.friday && !isSpecificHoliday) {
      addedDays++;
    }
  }
  return currentDate;
}