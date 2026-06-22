class LogEntry {
  final String id;
  final String time;
  final String english;
  final String tagalog;
  final String severity; // 'high' | 'medium'
  final int words;

  LogEntry({
    required this.id,
    required this.time,
    required this.english,
    required this.tagalog,
    required this.severity,
    required this.words,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'time': time,
      'english': english,
      'tagalog': tagalog,
      'severity': severity,
      'words': words,
    };
  }
}
