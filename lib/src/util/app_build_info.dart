final class AppBuildInfo {
  const AppBuildInfo({
    required this.versionName,
    required this.buildNumber,
    this.commitSha = '',
    this.builtAt = '',
  });

  static const current = AppBuildInfo(
    versionName: String.fromEnvironment(
      'APP_VERSION_NAME',
      defaultValue: '1.0.0',
    ),
    buildNumber: String.fromEnvironment('APP_BUILD_NUMBER', defaultValue: '1'),
    commitSha: String.fromEnvironment('APP_COMMIT_SHA'),
    builtAt: String.fromEnvironment('APP_BUILT_AT'),
  );

  final String versionName;
  final String buildNumber;
  final String commitSha;
  final String builtAt;

  String get versionLabel {
    final cleanVersion = versionName.trim();
    final cleanBuild = buildNumber.trim();
    if (cleanVersion.isEmpty && cleanBuild.isEmpty) {
      return 'Nepoznata verzija';
    }
    if (cleanVersion.isEmpty) {
      return 'Build $cleanBuild';
    }
    if (cleanBuild.isEmpty) {
      return cleanVersion;
    }
    return '$cleanVersion+$cleanBuild';
  }

  String get settingsSubtitle {
    final details = <String>[
      if (commitSha.trim().isNotEmpty) 'Commit ${commitSha.trim()}',
      if (builtAt.trim().isNotEmpty) builtAt.trim(),
    ];
    if (details.isEmpty) {
      return versionLabel;
    }
    return '$versionLabel\n${details.join(' - ')}';
  }
}
