import 'package:app_taxi_invoice/src/util/app_build_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('combines version name and build number', () {
    const info = AppBuildInfo(versionName: '1.2.3', buildNumber: '45');

    expect(info.versionLabel, '1.2.3+45');
  });

  test('includes deploy metadata in settings subtitle', () {
    const info = AppBuildInfo(
      versionName: '1.2.3',
      buildNumber: '45',
      commitSha: 'abc1234',
      builtAt: '2026-05-22 10:30 UTC',
    );

    expect(
      info.settingsSubtitle,
      '1.2.3+45\nCommit abc1234 - 2026-05-22 10:30 UTC',
    );
  });
}
