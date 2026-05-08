class JournalSettings {
  final String journalBaseUrl;
  final String journalPath;
  final String journalName;
  final String journalAbbrev;
  final String journalIssn;
  final String journalDoiId;
  final String journalOrganizationUrl;
  final String supportingOrganization;
  final String publicationId;

  const JournalSettings({
    this.journalBaseUrl = 'https://transnationalasia.rice.edu',
    this.journalPath = 'ta',
    this.journalName = 'Transnational Asia',
    this.journalAbbrev = 'TA',
    this.journalIssn = '2474-476X',
    this.journalDoiId = '10.25615',
    this.journalOrganizationUrl = 'https://chaocenter.rice.edu/',
    this.supportingOrganization = 'Journal hosting supported by Fondren Library, Rice University.',
    this.publicationId = '',
  });

  JournalSettings copyWith({
    String? journalBaseUrl,
    String? journalPath,
    String? journalName,
    String? journalAbbrev,
    String? journalIssn,
    String? journalDoiId,
    String? journalOrganizationUrl,
    String? supportingOrganization,
    String? publicationId,
  }) {
    return JournalSettings(
      journalBaseUrl: journalBaseUrl ?? this.journalBaseUrl,
      journalPath: journalPath ?? this.journalPath,
      journalName: journalName ?? this.journalName,
      journalAbbrev: journalAbbrev ?? this.journalAbbrev,
      journalIssn: journalIssn ?? this.journalIssn,
      journalDoiId: journalDoiId ?? this.journalDoiId,
      journalOrganizationUrl: journalOrganizationUrl ?? this.journalOrganizationUrl,
      supportingOrganization: supportingOrganization ?? this.supportingOrganization,
      publicationId: publicationId ?? this.publicationId,
    );
  }
}
