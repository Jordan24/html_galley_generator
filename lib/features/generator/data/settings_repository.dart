import 'package:shared_preferences/shared_preferences.dart';
import '../models/journal_settings.dart';

/// Handles persistence of [JournalSettings] via [SharedPreferences].
class SettingsRepository {
  static const _keyBaseUrl = 'baseUrl';
  static const _keyJournalPath = 'journalPath';

  Future<JournalSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return JournalSettings(
      baseUrl:
          prefs.getString(_keyBaseUrl) ?? 'https://transnationalasia.rice.edu',
      journalPath: prefs.getString(_keyJournalPath) ?? 'ta',
    );
  }

  Future<void> save(JournalSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, settings.baseUrl);
    await prefs.setString(_keyJournalPath, settings.journalPath);
  }
}
