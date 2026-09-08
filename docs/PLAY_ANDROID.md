# Burns Android Play setup

Paid, ad-free Google Play identity for Grapegames. Matches the Peregrine /
Pigeon publisher and CI pattern, without AdMob.

| Build | Package | Artifact |
| --- | --- | --- |
| Play release | `com.grapegames.burns` | `build/android/Burns.aab` |
| Local / sideload debug | `com.grapegames.burns.debug` | `build/android/Burns-debug.apk` |

There are no ads, IAP, or analytics SDKs in the app.

## GitHub secrets (required for deploy)

On `PatGuettler/burns` → Settings → Secrets and variables → Actions → **Secrets**,
copy the same four values already used on `PatGuettler/peregrine`:

| Secret | Purpose |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Release keystore file as base64 |
| `KEY_ALIAS` | Keystore alias (e.g. `grapegames`) |
| `KEYSTORE_PASSWORD` | Keystore password (ASCII only) |
| `SERVICE_ACCOUNT_JSON` | Play API service account JSON |

Deploy workflow: [`.github/workflows/deploy-android.yml`](../.github/workflows/deploy-android.yml)

- Triggers on push to `main`/`master` and **workflow_dispatch**
- Signs an AAB as `com.grapegames.burns` and uploads it to Play **internal**
  track. It does not publish GitHub Actions artifacts.
- Pull requests run [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)
  (headless tests only) and do not export Android builds.

Export preset: `Android Play`. CI stamps `versionCode` / `versionName` from
`github.run_number` (`1.<run>`).

Play AABs enable R8 shrinking and keep native libraries uncompressed for 16 KB
page-size devices. Godot 4.7.1 pins Android Gradle Plugin 8.6.1; do not bump
that to AGP 9 independently, it breaks the export template.

## Play Console checklist

Create the app **before** the first CI upload. The upload action cannot create
the store listing.

- [ ] Play Console → Create app → name **Burns**, default language, **App or
      game** = Game, **Free or paid** = **Paid** (this cannot be changed from
      free to paid later)
- [ ] Package name when asked, or first-upload identity: `com.grapegames.burns`
- [ ] Grant service account
      `github-actions@advance-anvil-449102-v7.iam.gserviceaccount.com` access
      to this app (same account as Peregrine / Pigeon)
- [ ] **Contains ads** = No
- [ ] Privacy policy: `https://patguettler.github.io/privacy-policy.html`
- [ ] Data deletion URL: `https://patguettler.github.io/privacy-policy.html#data-deletion`
- [ ] Website: `https://patguettler.github.io`
- [ ] Set the one-time price (Play Console → Monetize → App pricing)
- [ ] Content rating, Data safety, store listing, and screenshots
- [ ] Internal testing testers list + opt-in
- [ ] After first CI upload: install from the internal testing link

Data safety for this build: no ads, no advertising ID, no analytics SDK.
Internet is used only for optional private online rooms. Player display names
and room codes exist only for that session on the room server you host. Offline
saves stay on device.

Skip Play Integrity unless you adopt it deliberately. Skip `app-ads.txt` and
AdMob; this product is paid and ad-free.

## Local export

CI and local release builds use `scripts/ci/godot-export-android.sh`, which
unzips Godot's `android_source.zip` into `android/build/` (headless Godot does
not install the template on its own). The tracked marker `android/.build_version`
must match `GODOT_VERSION` (currently `4.7.1.stable`).

```bash
SKIP_DEBUG_APK=1 ./scripts/ci/godot-export-android.sh
```

A debug-signed APK for emulators still uses the **Android** preset:

```bash
godot --headless --path . --export-debug Android
```
