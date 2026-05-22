# Taxi Invoice

Standalone Flutter app for generating taxi invoice PDFs.

## GitHub Pages

The web app is deployed with GitHub Actions from `main`.

Live URL:

```text
https://d3xt3r2909.github.io/taxi_invoice/
```

The workflow builds Flutter web with the repository base path:

```sh
flutter build web --release --base-href "/taxi_invoice/"
```

During deploy, the workflow passes app build metadata into Flutter. The visible
version in Settings is `pubspec.yaml` version name plus the increasing GitHub
Actions run number, for example `1.0.0+123`.

On the first deploy, make sure repository Settings > Pages uses GitHub Actions
as the publishing source.
