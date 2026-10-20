# Building for Android and Google Play

Salt & Sail is portrait-only, Godot 4, Compatibility (OpenGL ES 3) renderer.
The project was built and verified on **Godot 4.3**. Google Play currently
requires new apps to target a recent Android API level, and the export
templates for 4.3 target API 34. **Before submitting to Play, open the project
in the latest stable Godot 4.x and export from that**, so the template's target
SDK meets Play's requirement (see Play Console, "Target API level"). Re-run the
steps below after upgrading.

## One-time setup

1. Install Godot (latest 4.x stable) and its **export templates**
   (Editor > Manage Export Templates).
2. Install **JDK 17**, and the **Android SDK** (command-line tools, platform-tools,
   build-tools, the platform for the target API, and the NDK version Godot asks for).
3. Editor > Editor Settings > Export > Android: set the Java SDK path and Android SDK path.
4. Open the project, then **Project > Install Android Build Template**. This
   creates `android/` (ignored by git). Gradle builds are required for the
   `.aab` that Play wants.
5. Create a release keystore **once** and back it up somewhere safe. Losing it
   means you cannot update the app (unless you use Play App Signing, which
   you should):

   ```
   keytool -genkeypair -v -keystore saltandsail-release.keystore \
     -alias saltandsail -keyalg RSA -keysize 2048 -validity 10000
   ```

6. Tell Godot about it without committing secrets, using environment variables:

   ```
   export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/to/saltandsail-release.keystore
   export GODOT_ANDROID_KEYSTORE_RELEASE_USER=saltandsail
   export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...
   ```

## Building

```
godot --headless --path . --export-release "Android (Play Store AAB)" build/salt-and-sail.aab
```

The preset in `export_presets.cfg` is already set up for: arm64-v8a only, AAB
output, portrait, immersive mode, the `VIBRATE` permission only (no network,
no storage, no ads, no analytics), and the launcher icons in `assets/icons`.

Before each Play upload, bump `version/code` (an integer that must always
increase) and `version/name` in the export preset, and `config/version` in
`project.godot`.

## Things to decide before the first upload

- **Package name**: the preset uses `com.camberr4.saltandsail`. It is permanent
  once published. Change `package/unique_name` now if you want a different one.
- **Title**: check the Play Store for name clashes first (open question in PROGRESS.md).
- **Store listing**: draft text is in `store/LISTING.md`; screenshots are in `store/`.
- **Privacy**: the game collects nothing and has no network access. Play still
  asks for a privacy policy URL; a one-paragraph page saying exactly that is enough.
- **Content rating**: answer the IARC questionnaire (cartoon pirate theme, no
  gambling, no user-generated content).
- **Monetisation**: not in this milestone. The one-time unlock needs the Google
  Play Billing plugin; plan it with the free-voyage counter (`Game.stats.voyages_started`).
- **Test on real devices** (low-end and high-end) in an internal testing track
  before production. Use the Graphics setting (Low/Medium/High) and the
  Battery saver (30 fps) toggle to cover weak GPUs.
