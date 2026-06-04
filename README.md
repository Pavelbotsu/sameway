# Sameway (Flutter)

Mobile client for the Sameway ridesharing app. Targets Android primarily; iOS untested. Drivers set a destination route; passengers within the road corridor receive offers in real time over WebSocket and accept or decline. CO₂ savings are tracked per trip; both parties rate each other after completion.

---

## Stack

| Layer | Choice |
|---|---|
| SDK | Flutter 3.x, Dart |
| State management | [provider](https://pub.dev/packages/provider) `^6.1.2` (ChangeNotifier) |
| HTTP | [http](https://pub.dev/packages/http) `^1.2.2` wrapped in `ApiClient` with 120 s timeouts + `X-Idempotency-Key` |
| WebSocket | [web_socket_channel](https://pub.dev/packages/web_socket_channel) `^3.0.1` |
| Maps | [flutter_map](https://pub.dev/packages/flutter_map) `^8.3.0` + OpenStreetMap tiles |
| Location | [geolocator](https://pub.dev/packages/geolocator), [geocoding](https://pub.dev/packages/geocoding) |
| Push | [firebase_core](https://pub.dev/packages/firebase_core), [firebase_messaging](https://pub.dev/packages/firebase_messaging) |
| Persistence | [shared_preferences](https://pub.dev/packages/shared_preferences) (JWT, role, user_id, name, email) |
| Loading skeletons | [skeletonizer](https://pub.dev/packages/skeletonizer) `^2.1.3` |
| Unique IDs | [uuid](https://pub.dev/packages/uuid) `^4.5.1` |
| i18n | Hand-rolled `AppLocalizations` (English + Ukrainian) |

---

## Quick start

```bash
# Backend must be running first — see ../sameway_backend/README.md
cd ../sameway_backend && go run .

# Install Flutter dependencies
cd ../sameway
flutter pub get

# Run on a connected device or emulator
flutter run
```

### Pointing at the backend

`lib/core/api_client.dart` line 7:

```dart
const kApiBase = 'https://ibuprofen-dolly-prison.ngrok-free.dev';
```

Change this based on environment:
- **Android emulator → host**: `http://10.0.2.2:8080`
- **Real device on same network**: `http://<your-host-ip>:8080`
- **Production**: your deployed URL

The WebSocket base URL in `lib/core/websocket_client.dart` derives from this (replaces `https://` with `wss://`).

---

## Folder layout

```
lib/
├── main.dart                          ← MultiProvider, MaterialApp, FCM init,
│                                       Firebase init, ScaffoldMessengerKey wiring
├── core/
│   ├── api_client.dart                ← http client with 120s timeouts + UUID
│   │                                   idempotency keys + ApiException
│   ├── token_storage.dart             ← SharedPreferences-backed JWT/role/user_id
│   ├── websocket_client.dart          ← WebSocketChannel + broadcast stream
│   ├── app_colors.dart                ← Brand identity constants (kept as
│   │                                   `static const` so const widgets compile)
│   ├── app_theme.dart                 ← M3 ColorScheme.fromSeed(teal) + brand
│   │                                   overrides + global elevatedButton min size
│   ├── app_localizations.dart         ← All user-facing strings, en + uk
│   ├── language_provider.dart         ← ChangeNotifier for locale toggle
│   ├── map_style_provider.dart        ← ChangeNotifier for map tile style
│   ├── fcm_service.dart               ← Firebase init + foreground onMessage
│   │                                   listener that pipes pushes to a
│   │                                   floating SnackBar via global key
│   ├── forms/
│   │   └── app_form.dart              ← Thin Form + GlobalKey wrapper with
│   │                                   AppFormController helpers
│   ├── validators/
│   │   ├── email_validator.dart       ← RFC 5322-lite regex
│   │   ├── password_validator.dart    ← validate + confirm
│   │   ├── required_validator.dart    ← localized "Required"
│   │   ├── text_sanitizer.dart        ← strips control + zero-width unicode
│   │   └── validators.dart            ← barrel re-export
│   └── widgets/
│       ├── glass_card.dart            ← BackdropFilter frosted container
│       ├── empty_state.dart           ← Reusable EmptyState
│       ├── rating_sheet.dart          ← 5-star modal, POST /ratings
│       ├── car_edit_sheet.dart        ← Car info form (uses AppForm)
│       ├── role_switch_sheet.dart     ← Shared role-switch quick sheet
│       └── m3_expressive/
│           ├── split_button.dart      ← Custom M3 Expressive split button
│           ├── wave_progress_indicator.dart  ← M3 Expressive wave bar
│           └── m3_expressive.dart     ← Barrel re-export
├── features/
│   ├── auth/
│   │   ├── auth_repository.dart       ← register(), login(), switchRole()
│   │   ├── auth_provider.dart         ← ChangeNotifier with AuthStatus enum
│   │   └── auth_screen.dart           ← FilledButton primary, AnimatedSwitcher
│   │                                   on obscure toggle, validators wired
│   ├── account/
│   │   └── account_security_screen.dart  ← Full-screen email/name/password
│   │                                       editor with AppForm + validators
│   ├── onboarding/
│   │   ├── splash_screen.dart         ← Logo with AnimatedSwitcher icon morph
│   │   ├── onboarding_screen.dart     ← 3 pages, FilledButton.tonal/FilledButton
│   │   └── role_selection_screen.dart ← Animated role cards
│   ├── driver/
│   │   ├── driver_repository.dart     ← /driver/* HTTP calls
│   │   ├── driver_provider.dart       ← ChangeNotifier with WS listener,
│   │   │                               PassengerMatchInfo cache, accept-name
│   │   │                               populator, completeRide(distanceKm)
│   │   ├── driver_home_screen.dart    ← Map, top bar, account sheet, nav bar
│   │   │                               (BottomPanel extracted; ~1,890 LOC down
│   │   │                               from 2,400)
│   │   └── widgets/
│   │       └── driver_bottom_panel.dart  ← Idle / Active / Guest state-case
│   │                                      widgets, AnimatedSwitcher, SplitButton
│   │                                      + WaveProgressIndicator integration
│   ├── passenger/
│   │   ├── passenger_repository.dart
│   │   ├── passenger_provider.dart    ← state machine (looking/offered/
│   │   │                               accepted/declined), pendingOffer with
│   │   │                               driverName/car/rating fields,
│   │   │                               acceptedCarSummary
│   │   └── passenger_home_screen.dart ← Map, DraggableScrollableController
│   │                                   auto-expand on offer, _OfferCard
│   │                                   pulsing Accept, _AcceptedCard
│   │                                   check_circle bloom + ring ping
│   ├── chat/
│   │   └── chat_screen.dart           ← Real-time WS chat, Skeletonizer
│   │                                   placeholder bubbles
│   ├── trips/
│   │   ├── trip_history_screen.dart   ← GET /auth/trips + Skeletonizer
│   │   ├── trip_planner_sheet.dart    ← Driver: create planned_trips (AppForm)
│   │   └── trip_search_sheet.dart     ← Passenger: search + Skeletonizer
│   └── promotions/
│       └── promotions_screen.dart     ← GET /promotions
```

---

## Architecture

### State management

Every feature has a `Provider` (ChangeNotifier) + `Repository` pair:

- **Repository** — pure API calls, no state, throws `ApiException`.
- **Provider** — holds state, calls repository, calls `notifyListeners()`, manages its WS subscription.
- **Screen** — `context.watch<P>()` for reactive rebuilds, `context.read<P>()` for one-shot actions.

`DriverProvider` and `PassengerProvider` each own a `WebSocketClient` instance. Two separate WS connections — driver and passenger don't share a channel.

### Network layer

`ApiClient` ([lib/core/api_client.dart](lib/core/api_client.dart)) wraps `package:http` with:

- 120 s timeout on every verb (`TimeoutException` → `ApiException('timeout')`)
- `X-Idempotency-Key: <uuidv4>` header on every `POST` / `PUT` / `DELETE` to guard against double-tap and retransmits
- `Authorization: Bearer <jwt>` injected when `auth: true`
- Bodies JSON-encoded; responses parsed; non-2xx → `ApiException(message)`

### Form architecture (Stage C)

Each logical form surface (auth, change-password, name editor, car edit, trip planner) uses one `AppForm` ([lib/core/forms/app_form.dart](lib/core/forms/app_form.dart)) with its own `GlobalKey<FormState>`. Validators are pure-function classes in `lib/core/validators/`:

```dart
TextFormField(
  controller: _email,
  validator: (v) => EmailValidator.validate(v, l),
  autovalidateMode: AutovalidateMode.onUserInteraction,
)
```

`TextSanitizer.sanitize` strips ASCII control chars and common zero-width unicode codepoints before submitting. `TextSanitizer.sanitizeIdentifier` additionally collapses internal whitespace (for car plates etc.).

### Loading states (Stage E)

All loading skeletons use [`skeletonizer`](https://pub.dev/packages/skeletonizer): same widget tree both states, dimensions guaranteed identical. Each model that gets skeletonized has a `.skeleton()` factory:

```dart
Skeletonizer(
  enabled: _loading,
  child: ListView.builder(
    itemCount: _loading ? 6 : _trips.length,
    itemBuilder: (_, i) => _TripCard(
      trip: _loading ? _TripItem.skeleton() : _trips[i],
      userId: _userId ?? '',
    ),
  ),
)
```

### Custom M3 Expressive widgets

`lib/core/widgets/m3_expressive/`:

- **`SplitButton`** — primary action + chevron dropdown, M3 Expressive split button anatomy. Used on the driver idle panel: primary "Set Route" + dropdown for "Plan a Trip" / "Find Planned Trips".
- **`WaveProgressIndicator`** — animated wave-form linear progress, both determinate (with notch gap and amplitude damping near 1.0) and indeterminate (traveling sine wave). Used below the SplitButton during route geocoding.

### i18n

`lib/core/app_localizations.dart` — single class with `_isUk` flag, getter per string. English + Ukrainian fully covered for auth, onboarding, both home screens, offer/accepted/looking cards, account screen, chat, trip history, trip planner/search, promotions, rating sheet, car edit sheet, all dialogs, all SnackBars, common buttons.

Switch language via top-right glass card → translate icon. Persisted in `SharedPreferences` via `LanguageProvider`.

### Animation tokens

- **State-case transitions** in `_PassengerHomeScreen` status switch and `DriverBottomPanel` use `Duration(milliseconds: 280)` + `Curves.easeOutCubic` — consistent motion across screens.
- **Bloom-in** on `_AcceptedCard` check-circle: 720 ms total, scale 0.3→1.0 with `easeOutBack` (overshoot), tiny -0.08→0 rotation, expanding success ring ping.
- **Offer auto-snap** moves the DraggableScrollableSheet from 0.28 → 0.55 snap in 280 ms when a `ride_request` arrives.

---

## User flow

```
App launch
  └─ SplashScreen (2.5 s logo morph)
       ├─ JWT in storage → DriverHomeScreen | PassengerHomeScreen
       └─ no JWT → OnboardingScreen (3 swipe-able pages)
                       └─ RoleSelectionScreen (driver / passenger cards)
                              └─ AuthScreen(role)
                                   └─ success → DriverHomeScreen | PassengerHomeScreen
```

---

## WebSocket events handled

| Event | Provider | Effect |
|---|---|---|
| `ride_request` | `PassengerProvider` | `pendingOffer = RideOffer(...)`, `state = offered`. Auto-expands the bottom sheet (D7), Accept button pulses (D2). |
| `ride_response` | `DriverProvider` | Caches `PassengerMatchInfo` per request_id. On `status='accepted'`: populates `acceptedPassengerName` + rating. |
| `passenger_request` | `DriverProvider` | Caches `PassengerMatchInfo`. |
| `ride_done` | `PassengerProvider` | `state = looking`, `pendingRatingRequestId/DriverId` set so the screen shows a `RatingSheet`. |
| `ride_cancelled` | both | Per-side state reset. `cancelled_by` may be `"driver" \| "passenger" \| "passenger_matched_elsewhere" \| "timeout"`. |
| `chat_message` | both | `unreadMessages++`. |

---

## Key UI surfaces

| Surface | Key features |
|---|---|
| Splash | Logo with `AnimatedSwitcher` icon morph, 600 ms easeOutCubic |
| Onboarding | 3-page PageView, `FilledButton.tonal` for Continue + `FilledButton` for Get Started |
| Role selection | Animated gradient + glow cards, ScaleTransition on tap |
| Auth | `Form` + `GlobalKey<FormState>`, validators from `lib/core/validators/`, `AnimatedSwitcher` on the obscure-password toggle, `FilledButton` submit |
| Driver home | Map, top glass bar (badge + language + account), `DriverBottomPanel` with three state-case widgets (idle / guest / active), `SplitButton` + `WaveProgressIndicator` on idle, `_RequestTile` action chips (40 dp tap targets) |
| Passenger home | Map, top glass bar, `DraggableScrollableSheet` with state-machine cards (`_LookingCard`, `_OfferCard` pulsing, `_AcceptedCard` with check-circle bloom + ring ping, `_DeclinedCard`), nearby-drivers floating empty state |
| Account & Security | Full-screen email read-only + display-name editor (`AppForm`) + `_ChangePasswordSection` (`AppForm` with `PasswordValidator.confirm`), `AnimatedSize` on the server-error slot |
| Chat | `_MessageBubble` list, Skeletonizer placeholders, message composer |
| Trip History | `_TripCard` list, Skeletonizer 6 placeholder rows |
| Trip Planner / Search (sheets) | Origin/destination autocomplete via Nominatim, `Skeletonizer` 3 placeholder rows, sanitized names on submit |
| Rating sheet | 5-star tap, optional comment, `POST /ratings` (idempotent) |
| Car edit sheet | `AppForm` with sanitized values; plate uses `sanitizeIdentifier` (collapses whitespace) |
| Role switch sheet | Quick swap with localized labels; persists new JWT via `TokenStorage.save` |

---

## Theme

`lib/core/app_theme.dart`:

- `useMaterial3: true`
- `ColorScheme.fromSeed(seedColor: AppColors.teal, brightness: Brightness.dark)`
- Brand teal as `colorScheme.primary`, brand purple as `colorScheme.secondary`
- `surface`, `error`, `onSurface` overridden to keep the curated AppColors look
- `elevatedButtonTheme.minimumSize = Size(64, 48)` — M3 spec minimum, **not** `Size(double.infinity, 56)` which previously caused a crash when an `ElevatedButton` was placed inside a `Row` without `Expanded`

Brand identity constants in `lib/core/app_colors.dart` remain `static const Color` so every `const Icon(color: AppColors.X)` literal across the app compiles as `const`.

WCAG audit — every brand text/background pairing exceeds 4.5:1 (AA for normal text); buttons exceed 3:1 (UI elements). One marginal: `Colors.black` on `AppColors.primary` (4.2:1) — used in a few legacy explicit overrides, will switch to `cs.onPrimary` in future polish.

---

## Android-specific

- `android/app/src/main/AndroidManifest.xml`:
  - `android:enableOnBackInvokedCallback="true"` on `<application>` — enables Android 13+ predictive back animation
  - Permissions: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `INTERNET`
- No `WillPopScope` / `PopScope(canPop: false)` blockers — system back works everywhere
- No FAB or AppBar action buttons — all primary CTAs anchored in the bottom thumb-zone (`DraggableScrollableSheet`, `_DriverNavBar` / `_PassengerNavBar`, modal sheets, `AlertDialog.actions`)

---

## Build status

`flutter analyze` clean. `flutter pub get` resolves cleanly.

## Run

```bash
flutter run
```
