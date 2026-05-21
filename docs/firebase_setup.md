# Firebase Setup

Use a dedicated Firebase project on the Spark plan. Enable Authentication with
the Email/Password provider, then create the three app users in Firebase
Authentication.

Use Realtime Database, not Cloud Storage. Create the database in locked mode.
After creating the users, copy each Firebase Auth UID and add this data in
Realtime Database:

```json
{
  "allowedUsers": {
    "FIRST_AUTH_UID": true,
    "SECOND_AUTH_UID": true,
    "THIRD_AUTH_UID": true
  }
}
```

Deploy or paste the rules from `firebase/database.rules.json`.

For local runs, copy `android_config.example.json` to `android_config.json` and
fill in the Firebase values. `android_config.json` is ignored by Git.

Run the app with the config file:

```sh
flutter run -d chrome --dart-define-from-file=android_config.json
```

In Android Studio, put this in the Flutter run configuration's
`Additional run args` field:

```text
--dart-define-from-file=android_config.json
```

For Android, iOS, macOS, or Windows builds, add the matching Firebase app in the
Firebase console and pass the matching app ID, for example
`FIREBASE_ANDROID_APP_ID` or `FIREBASE_IOS_APP_ID`. `FIREBASE_APP_ID` can be
used as a fallback for non-web builds.

## GitHub Pages secrets

For the GitHub Pages workflow, add these repository secrets in GitHub:

Settings > Secrets and variables > Actions > Repository secrets

```text
FIREBASE_API_KEY
FIREBASE_PROJECT_ID
FIREBASE_MESSAGING_SENDER_ID
FIREBASE_DATABASE_URL
FIREBASE_AUTH_DOMAIN
FIREBASE_WEB_APP_ID
```

The workflow fails early if one of these is missing, then passes them to
`flutter build web` as `--dart-define` values.
