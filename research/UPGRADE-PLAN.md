# UPGRADE-PLAN: NeedBase (need-based marketplace, Pakistan)

Produced by an upgrade-it style audit on 2026-07-22. Ground truth is the repo at commit `a0cd348` plus the changes listed under "Done this session". Every finding carries evidence (`file:line` at audit time). Rank order is (revenue / crash / rejection risk) × effort. **Per the upgrade-it contract: items in the backlog below need an explicit go from you before code is touched** — the only changes already made are the ones you explicitly ordered (Firebase project integration + app identity).

## Ground truth

- Flutter + Provider app; 23 screens, 5 providers, 7 services, 5 models, 8 widgets, 1 repository. Consistent Provider-based state management, good loading-button discipline (76 uses across 15 screens). The UI layer is in decent shape.
- Stack: Firebase (Auth, Firestore, RTDB, Storage, Messaging), Agora (calls), google_sign_in, flutter_local_notifications.
- Now wired to Firebase project **studyplanner1367** (was: the original author's `needbasedmarketplace` project, with a `google-services.json` registered to `com.esha.marketplace` — a package this app never had).

## Done this session (verified)

| Change | Evidence |
|---|---|
| Android identity renamed to `com.thevibes.needbase` (namespace + applicationId + MainActivity package; old `com.example.needbase` and `com.thevibes.needbasemarketplace` MainActivity files removed — the mismatch was a guaranteed `ClassNotFoundException` on launch) | `android/app/build.gradle.kts:9,25`, `android/app/src/main/kotlin/com/thevibes/needbase/MainActivity.kt` |
| Android app registered on studyplanner1367: `1:636560866742:android:0f263c75201551dfa0d517` | `firebase apps:android:sha:list` output; `android/app/google-services.json` |
| Web app registered: `1:636560866742:web:3a00f1878d069b5ea0d517` | flutterfire configure output |
| `lib/firebase_options.dart` regenerated for android+web → studyplanner1367; stale iOS block (old project, android appId, `com.esha.marketplace` bundle id) replaced with an explicit UnsupportedError until iOS is registered | `lib/firebase_options.dart` |
| Misplaced `android/app/src/google-services.json` (old project, wrong package) removed; correct file at `android/app/google-services.json` | glob |
| `.firebaserc` default project → studyplanner1367 | `.firebaserc` |
| Debug SHA-1 `74:1F:...:91:BB` registered on the Android app | `firebase apps:android:sha:list` |
| `flutter pub get` clean; debug APK build running as verification | this file's Verification section |

## Console steps only you can do (Firebase console → studyplanner1367)

1. **Authentication → Sign-in method: enable Google** (and set support email) — the OAuth client for `com.thevibes.needbase` is currently empty (`google-services.json` `oauth_client: []`), so Google Sign-In will fail with ApiException 10 until this is done. Also enable **Email/Password** if the auth screen offers it. After enabling Google, re-run `flutterfire configure` (or delete and re-fetch `google-services.json`) so the OAuth client lands in the app config.
2. **Decide on project sharing.** studyplanner1367 already hosts registrations for at least `com.emiratesit.ntirc` and others. Firestore/RTDB/Storage **rules, quotas, and data are shared project-wide**. A marketplace holding wallet balances sharing a project with unrelated apps is a real risk — deploying NeedBase's security rules would apply to (and could break) the other apps, and vice versa. Recommended: a dedicated Firebase project for NeedBase before launch. If you keep studyplanner1367, the rules in item 2 below must be written to coexist with whatever the other apps use.
3. Before release: add your **release keystore SHA-1/SHA-256** (item 4) the same way the debug SHA was added.

## Ranked backlog (needs your go, per item or as a batch)

1. **[CRITICAL / high effort] Payments are a client-side simulation — every rupee is on the honor system.** `payment_provider.dart:367-398` writes wallet balance straight to RTDB from the client; OTP is generated on-device and printed to the log (`:487-493` — `print('📱 OTP SENT: $otp')`), verified by comparing against the same client value (`:233`); bank/platform "APIs" are `_simulateBankAPICall`/`_simulatePlatformAPICall` (`:403,449`). The Cloud Function (`functions/index.js`) only sends FCM pushes. Fix: move OTP, verification, and all wallet mutations behind Cloud Functions with a real rail (JazzCash/EasyPaisa sandbox first); client only reads balances.
2. **[CRITICAL / medium] No security rules in the repo at all.** No `firestore.rules`, no `storage.rules`, and `firebase.json:6-8` references a `database.rules.json` that does not exist (deploys will fail). With client-written wallets (item 1), any authenticated user can set their own balance. Write locked-down rules for Firestore/RTDB/Storage, version them in the repo, deploy — coordinated with the shared-project decision above.
3. **[CRITICAL / low] Release builds signed with debug keys.** `build.gradle.kts:35-39` (`signingConfig = signingConfigs.getByName("debug")` + the template's TODO). Create an upload keystore, wire `signingConfigs.release` via `key.properties` (gitignored), back the keystore up — losing it permanently orphans the Play listing.
4. **[HIGH / low] targetSdk 34 is below Play's current requirement.** `build.gradle.kts:29` hardcodes 34; Play requires 35 for new apps/updates now. Switch to `flutter.targetSdkVersion` and retest permission flows (notifications, media, camera, mic).
5. **[HIGH / low-medium] Zero crash visibility.** No `firebase_crashlytics`, no `firebase_analytics`, no `runZonedGuarded`/`FlutterError.onError` anywhere (grep-verified). Add Crashlytics + Analytics, wrap `runApp`, route `FlutterError.onError` and `PlatformDispatcher.onError` to Crashlytics. Without this you launch blind.
6. **[HIGH / low] Error hygiene.** 8 fully-empty catch blocks (`fcm_service.dart`, `home_screen.dart`, `profile_screen.dart` ×6) and several swallow-and-reset catches in `payment_provider.dart` (`:77,111,293,317,359,394`); 4 raw `print()` calls including the OTP leak. Surface failures to the user, log the rest, delete the OTP print.
7. **[MEDIUM / low] Firebase init failure is silent.** `main.dart:32-42` catches init errors, `debugPrint`s, and continues into code that requires Firebase — ship a "can't connect" screen instead of a downstream crash.
8. **[MEDIUM / medium] No offline handling.** No connectivity detection anywhere (only a comment at `profile_screen.dart:69`); on spotty networks (your target market) streams stall behind silent catches. Add `connectivity_plus` + an offline banner + retry affordances on the main feeds.
9. **[MEDIUM / low] R8/shrinking off, no proguard rules.** `build.gradle.kts:34-40`. Enable minify+shrink for release with keep rules for Firebase/Agora; smaller APK matters on budget devices.
10. **[MEDIUM / low] Test suite is the broken counter template.** `test/widget_test.dart` references `MyApp`/counter which don't exist — `flutter test` fails to compile. Replace with a real smoke test (app boots, auth screen renders) so CI can gate anything at all.
11. **[LOW / low] Adaptive icon missing** (`mipmap-anydpi-v26`), so Android 8+ shows a legacy non-masked icon. Cosmetic but it's the first thing a Play reviewer sees.
12. **[HIGH / low] Push notifications: deploy staged, one command left.** Client side fully wired (`fcm_service.dart:57-83`, tokens at RTDB `fcm_tokens/{uid}`, `POST_NOTIFICATIONS` in manifest); sender function uses the modern `sendEachForMulticast` API (`functions/index.js:202`). Done 2026-07-23: project confirmed on Blaze (owner), runtime bumped `nodejs18` (decommissioned) → `nodejs20` in `firebase.json` + `functions/package.json`, `npm install` in `functions/` clean. Remaining: run `firebase deploy --only functions --project studyplanner1367` (blocked by tool permissions in-session — owner runs it or approves it). Follow-up before 2026-10-30: nodejs20 hits its own decommission then; bump to nodejs22 + firebase-functions v6 (change `require("firebase-functions")` to `require("firebase-functions/v1")`). Web push separately unconfigured (no `web/firebase-messaging-sw.js`, no VAPID key) — Android-only for now.
12b. **[Chat media — mostly RESOLVED by existing code.]** Chat media was already correctly built on Firebase Storage — `chat_service.dart:175-200` uploads voice/image/video/document to `chats/{needId}/{channelId}/…` via `putFile` with proper content types and stores only download URLs in RTDB. The default bucket on studyplanner1367 EXISTS (probe returned 403, not 404). Unverified: the bucket's security rules — if they don't allow authenticated writes under `chats/**`, uploads fail at runtime; rules aren't readable via CLI, check console. Ties into item 2 (rules in repo) and the shared-project decision.
13. **[iOS, when in scope] iOS is unregistered.** Xcode bundle id is still `com.example.needbase` (`project.pbxproj:371`), no `GoogleService-Info.plist`; `firebase_options.dart` now throws for iOS by design. When you want iOS: set the bundle id, then `flutterfire configure --platforms=ios`.

## Verification status

- `flutter pub get`: clean (28 deps changed after re-lock).
- `flutter build apk --debug`: running at plan-writing time; result reported in-session.
- Not yet verified (needs the console step): Google Sign-In end-to-end on studyplanner1367; Firestore/RTDB reads against the new project's (unknown) rules — expect permission behavior to differ from the old project until item 2 is done.
