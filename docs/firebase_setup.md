# Firebase Setup

Use a dedicated Firebase project on the Spark plan. Enable Authentication with
the Email/Password and Google providers, then create or approve the three app
users in Firebase Authentication.

For Google sign-in on GitHub Pages, open Authentication > Settings >
Authorized domains and add the GitHub Pages host, for example
`d3xt3r2909.github.io`. For local Chrome runs, add `localhost` if it is not
already listed.

Use Realtime Database, not Cloud Storage. Create the database in locked mode.
After creating the users, copy each Firebase Auth UID and add this data in
Realtime Database:

```json
{
  "allowedUsers": {
    "FIRST_AUTH_UID": {
      "email": "admin@example.com",
      "role": "admin"
    },
    "SECOND_AUTH_UID": {
      "email": "user1@example.com",
      "role": "user"
    },
    "THIRD_AUTH_UID": {
      "email": "user2@example.com",
      "role": "user"
    }
  }
}
```

Deploy or paste the rules from `firebase/database.rules.json`.

`role: "admin"` shows the administrator tools in app settings. Use it for
only one trusted user. Admin can rotate the shared database password and reset
all stored invoice data. Existing `UID: true` entries still work as normal
users, but they do not get administrator tools.

## Database password

After the first Firebase sign-in, the app asks the first user to set a shared
database password. Existing plain JSON is encrypted at that point. Give the same
password privately to the other approved users.

The `Zapamti šifru na ovom uređaju` option stores a derived unlock key only on
that browser/device. Do not put the database password in GitHub secrets,
`android_config.json`, or source code.

If the database password is forgotten and no remembered device can still unlock
the app, the encrypted invoice JSON cannot be recovered.

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
