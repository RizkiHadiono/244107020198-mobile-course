/// Pure formatting and parsing functions without Flutter dependencies.
/// This allows pure unit testing without widget tester or platform channels.
library;

String formatDate(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = _monthName(dateTime.month);
  final year = dateTime.year.toString();
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$day $month $year, $hour:$minute';
}

String formatDateShort(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = _monthName(dateTime.month);
  final year = dateTime.year.toString();
  return '$day $month $year';
}

int? parseIdFromPath(String path) {
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return null;
  return int.tryParse(segments.last);
}

String sanitizeInput(String input) {
  return input.trim();
}

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  if (month < 1 || month > 12) return '';
  return months[month - 1];
}
