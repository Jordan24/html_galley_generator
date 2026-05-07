/// Holds journal-specific settings that are persisted across sessions.
class JournalSettings {
  final String baseUrl;
  final String journalPath;

  const JournalSettings({
    this.baseUrl = 'https://transnationalasia.rice.edu',
    this.journalPath = 'ta',
  });

  JournalSettings copyWith({String? baseUrl, String? journalPath}) {
    return JournalSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      journalPath: journalPath ?? this.journalPath,
    );
  }
}
