import 'package:shared_preferences/shared_preferences.dart';
import '../models/journal_settings.dart';

/// Handles persistence of [JournalSettings] via [SharedPreferences].
class SettingsRepository {
  static const _keyBaseUrl = 'journalBaseUrl';
  static const _keyJournalPath = 'journalPath';
  static const _keyJournalName = 'journalName';
  static const _keyJournalAbbrev = 'journalAbbrev';
  static const _keyJournalIssn = 'journalIssn';
  static const _keyJournalDoiId = 'journalDoiId';
  static const _keyJournalOrgUrl = 'journalOrganizationUrl';
  static const _keySupportingOrg = 'supportingOrganization';
  static const _keyPublicationId = 'publicationId';

  Future<JournalSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    const defaults = JournalSettings();
    return JournalSettings(
      journalBaseUrl: prefs.getString(_keyBaseUrl) ?? defaults.journalBaseUrl,
      journalPath: prefs.getString(_keyJournalPath) ?? defaults.journalPath,
      journalName: prefs.getString(_keyJournalName) ?? defaults.journalName,
      journalAbbrev: prefs.getString(_keyJournalAbbrev) ?? defaults.journalAbbrev,
      journalIssn: prefs.getString(_keyJournalIssn) ?? defaults.journalIssn,
      journalDoiId: prefs.getString(_keyJournalDoiId) ?? defaults.journalDoiId,
      journalOrganizationUrl: prefs.getString(_keyJournalOrgUrl) ?? defaults.journalOrganizationUrl,
      supportingOrganization: prefs.getString(_keySupportingOrg) ?? defaults.supportingOrganization,
      publicationId: prefs.getString(_keyPublicationId) ?? defaults.publicationId,
    );
  }

  Future<void> save(JournalSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, settings.journalBaseUrl);
    await prefs.setString(_keyJournalPath, settings.journalPath);
    await prefs.setString(_keyJournalName, settings.journalName);
    await prefs.setString(_keyJournalAbbrev, settings.journalAbbrev);
    await prefs.setString(_keyJournalIssn, settings.journalIssn);
    await prefs.setString(_keyJournalDoiId, settings.journalDoiId);
    await prefs.setString(_keyJournalOrgUrl, settings.journalOrganizationUrl);
    await prefs.setString(_keySupportingOrg, settings.supportingOrganization);
    await prefs.setString(_keyPublicationId, settings.publicationId);
  }
}
