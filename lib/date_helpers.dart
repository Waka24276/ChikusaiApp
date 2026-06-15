import 'package:flutter/material.dart'; // For Duration

/// Helper function to add a specified number of working days to a given date.
/// Weekends (Saturday and Sunday) are skipped.
///
/// Note: This function does not account for public holidays.
DateTime addWorkingDays(DateTime startDate, int daysToAdd) {
  DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day); // Start from the beginning of the day
  int addedDays = 0;

  while (addedDays < daysToAdd) {
    currentDate = currentDate.add(const Duration(days: 1));

    // 祝日の定義 (7月20日, 8月11日)
    final bool isSpecificHoliday = 
        (currentDate.month == 7 && currentDate.day == 20) || 
        (currentDate.month == 8 && currentDate.day == 11);

    // 土日、または指定の祝日でない場合にカウント
    if (currentDate.weekday >= DateTime.monday && currentDate.weekday <= DateTime.friday && !isSpecificHoliday) {
      addedDays++;
    }
  }
  return currentDate;
}