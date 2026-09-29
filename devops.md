# Taskly: How It's Built and Why

This guide explains the technologies in Taskly v2, how the code is organised, why it's written the way it is, and how it gets from your machine to users. Read it top to bottom once; after that, use it as a reference.

For *what* is planned next, see [ROADMAP.md](ROADMAP.md). This document is about *how* and *why*.

**Contents**

1. [The big picture](#1-the-big-picture)
2. [The tech stack](#2-the-tech-stack)
3. [What happens when the app starts](#3-what-happens-when-the-app-starts)
4. [Folder structure](#4-folder-structure)
5. [Core concepts, explained with our code](#5-core-concepts-explained-with-our-code)
6. [Testing](#6-testing)
7. [Configuration, secrets and security](#7-configuration-secrets-and-security)
8. [CI/CD: from commit to production](#8-cicd-from-commit-to-production)
9. [Building for each platform](#9-building-for-each-platform)
10. [Recipe: adding a new feature](#10-recipe-adding-a-new-feature)
11. [Firestore primer (read before Phase 2)](#11-firestore-primer-read-before-phase-2)
12. [Debugging and troubleshooting](#12-debugging-and-troubleshooting)
13. [Command cheat sheet](#13-command-cheat-sheet)
14. [Glossary](#14-glossary)
15. [Where to learn more](#15-where-to-learn-more)

---

## 1. The big picture

Taskly is a single Flutter codebase that runs on the web, Android, iOS, macOS and Windows. It has no server of its own. Instead it talks directly to Firebase, Google's backend-as-a-service, for sign-in and data storage.

```
                      ┌──────────────────────────────┐
                      │         Firebase (Google)     │
                      │  ┌────────────┐ ┌──────────┐ │
                      │  │    Auth    │ │ Firestore│ │
                      │  │ (accounts) │ │  (data)  │ │
                      │  └─────▲──────┘ └────▲─────┘ │
                      └────────┼─────────────┼───────┘
                               │  HTTPS / WebSocket
         ┌─────────────────────┴─────────────┴─────────────────────┐
         │                  Taskly Flutter app                      │
         │   one Dart codebase → web, Android, iOS, macOS, Windows  │
         └──────────────────────────▲──────────────────────────────┘
                                    │ served as static files (web)
┌──────────────┐  push  ┌───────────┴──────────┐  deploy  ┌──────────────┐
│ Your machine ├───────►│ GitHub + Actions (CI)├─────────►│ GitHub Pages │
└──────────────┘        └──────────────────────┘          └──────────────┘
```

Three consequences of this design:

- **There's no backend code to write or host.** Firebase handles accounts, storage, real-time sync and scaling.
- **Security lives in Firestore security rules, not in the app.** Anyone can open the browser dev tools and call Firebase directly with your project's config. The rules (Phase 2) decide what each signed-in user may read and write. See [section 7](#7-configuration-secrets-and-security).
- **The web version is just static files** (HTML, JS, fonts), so any static host can serve it. We use GitHub Pages.

---

## 2. The tech stack

| Technology | What it is | Why we use it | Alternatives |
|---|---|---|---|
| **Flutter 3.47** | Google's UI toolkit. You describe the UI as a tree of *widgets*; Flutter draws every pixel itself. | One codebase for web, mobile and desktop. You already knew it from v1. | React Native, native Swift/Kotlin |
| **Dart 3.13** | The language Flutter uses. | Sound null safety, records, patterns, sealed classes. v1 was Dart 2.7, which had none of these. | – |
| **Firebase Auth** | Hosted user accounts (email/password, Google sign-in…). | Secure, free at our scale, no server needed. | Supabase Auth, Auth0 |
| **Cloud Firestore** | Hosted NoSQL document database with real-time updates. | Live sync between users for free, offline cache, security rules. | Supabase (Postgres), a custom API |
| **FlutterFire CLI** | Command-line tool that registers your app with Firebase and writes the config file. | Replaces the hand-pasted `<script>` config v1 had in `index.html`. | Manual setup |
| **Riverpod 3** | State management and dependency injection. | Compile-safe, easy to test, handles loading and error states for you. It's the successor to `provider`, which v1 used. | Provider, Bloc, GetX |
| **go_router 18** | URL-based navigation, maintained by the Flutter team. | Real URLs on web (`/projects`), browser back button, deep links, auth redirects in one place. | Navigator 1.0 (v1), auto_route |
| **Material 3** | Google's current design system, built into Flutter. | Modern look, dark mode and accessibility for free. | Cupertino, custom design |
| **google_fonts** | Loads Google Fonts at runtime. | Keeps Montserrat from v1 without bundling font files. | Bundled font assets |
| **flutter_lints** | Recommended static analysis rules. | Catches bugs and style issues before they run. | very_good_analysis |
| **GitHub Actions** | CI/CD: runs scripts on GitHub's machines when you push. | Free for public repos, lives next to the code. | GitLab CI, Codemagic |
| **GitHub Pages** | Free static website hosting. | Zero cost, same place as the repo. | Firebase Hosting (Phase 5), Netlify |

### Dart 3 features you'll see in the code

Look out for these, because they weren't in the v1 code:

```dart
// Null safety: `?` means "may be null". The compiler forces you to handle it.
final String? email;                         // lib/features/auth/domain/app_user.dart

// Records: lightweight anonymous data types, no class needed.
typedef _Destination = ({IconData icon, IconData selectedIcon, String label});   // app_shell.dart

// Patterns: "if email is not null, bind it to `email`".
if (user?.email case final email?) Text(email)                                   // app_shell.dart

// `abstract final class`: a namespace for constants that can't be instantiated or extended.
abstract final class Routes { static const home = '/home'; }                    // router.dart
```

---

## 3. What happens when the app starts

Everything begins in [`lib/main.dart`](lib/main.dart). Here's each line and why it's there:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
```
Flutter's engine must be ready before any plugin (like Firebase) talks to native code. You only need this when `main` does async work before `runApp`.

```dart
  usePathUrlStrategy();
```
By default Flutter web URLs look like `example.com/#/projects`. This switches to clean URLs like `example.com/projects`. The trade-off is that the web host must serve `index.html` for *any* path. [Section 8](#8-cicd-from-commit-to-production) shows how we do that on GitHub Pages.

```dart
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```
Connects to *our* Firebase project. `DefaultFirebaseOptions.currentPlatform` (from the generated `lib/firebase_options.dart`) picks the right config for web, Android, iOS and so on.

```dart
  await FirebaseAuth.instance.authStateChanges().first;
```
When you reload the page, Firebase restores your saved session asynchronously. Without this line, the router would briefly think you're signed out and flash the login page. Waiting for the first auth event means the very first screen is the right one.

```dart
  runApp(const ProviderScope(child: TasklyApp()));
}
```
`ProviderScope` is where Riverpod stores all provider state. Every widget below it can read providers. `TasklyApp` ([`lib/app/app.dart`](lib/app/app.dart)) then builds `MaterialApp.router` with our theme and router.

Put together:

```
main()
 ├─ Firebase.initializeApp            → connected to Firebase
 ├─ wait for the saved session        → know if the user is signed in
 └─ ProviderScope
     └─ TasklyApp
         └─ MaterialApp.router
             ├─ theme: appThemeProvider    (lib/app/theme/app_theme.dart)
             └─ routerConfig: routerProvider (lib/app/router.dart)
                 ├─ redirect → public pages or the signed-in shell
                 └─ AppShell (nav bar / rail / drawer)
                     └─ HomePage | ProjectsPage | TasksPage | SharedPage
```

---

## 4. Folder structure

```
taskly-flutter/
├── lib/                      ← all app code
│   ├── main.dart             ← entry point (section 3)
│   ├── firebase_options.dart ← GENERATED by FlutterFire CLI. Don't hand-edit.
│   ├── app/                  ← app-wide wiring: the "skeleton" that holds features together
│   │   ├── app.dart          ← MaterialApp.router
│   │   ├── router.dart       ← all routes + auth redirect
│   │   ├── app_shell.dart    ← responsive navigation around signed-in pages
│   │   ├── not_found_page.dart
│   │   └── theme/            ← colours, fonts, spacing tokens
│   ├── core/                 ← reusable building blocks with no feature knowledge
│   │   └── widgets/          ← EmptyState, ErrorState, Skeleton, dialogs
│   └── features/             ← one folder per product feature
│       ├── auth/
│       │   ├── domain/       ← plain Dart models (AppUser)
│       │   ├── data/         ← talks to Firebase (AuthRepository)
│       │   └── presentation/ ← screens and widgets (LoginPage, SignUpPage)
│       ├── home/  landing/  profile/  projects/  sharing/  tasks/
│       │   └── presentation/ ← placeholder pages for now
├── test/                     ← mirrors lib/ (test/app ↔ lib/app, etc.)
│   └── helpers/              ← fakes and pumpApp(), shared by all tests
├── legacy/lib/               ← the v1 code, read-only reference, excluded from analysis
├── web/  android/  ios/  macos/  windows/   ← platform "host" projects
├── assets/images/            ← images bundled into the app
├── .github/workflows/main.yml ← CI/CD pipeline
├── pubspec.yaml              ← dependencies and app metadata
├── pubspec.lock              ← exact resolved versions (committed)
├── analysis_options.yaml     ← lint rules
├── firebase.json             ← FlutterFire's record of which Firebase apps map to which platform
├── ROADMAP.md                ← the plan
└── devops.md                 ← this file
```

### Why "feature-first"?

v1 was organised **by layer**: `Model/`, `Screens/`, `Services/`, `Widgets/`. To work on "tasks" you had to touch files in four folders, and `Services/Database.dart` grew to 353 lines because *everything* went there.

v2 is organised **by feature**. Everything about projects lives in `features/projects/`. That gives you:

- **Locality.** A change to one feature touches one folder.
- **Rewritable.** This is exactly why the "rewrite one feature at a time" plan works.
- **Deletable.** Removing a feature means removing a folder.

### Why `domain / data / presentation` inside a feature?

This is the standard layered architecture from the Flutter team's own guidance. The layers have one rule: **dependencies point inward**.

```
presentation  ──►  data  ──►  domain
 (widgets)       (Firebase)   (plain Dart)
```

| Layer | Contains | May import | Example |
|---|---|---|---|
| `domain/` | Models and business rules | Nothing app-specific. No Firebase, and ideally no Flutter widgets. | `AppUser`, and later `Project`, `Task`, `Priority` |
| `data/` | Repositories that talk to Firebase and convert its data into domain models | `domain/`, Firebase packages | `AuthRepository` |
| `presentation/` | Pages, widgets, and later Riverpod notifiers for UI state | `domain/`, `data/` (via providers), `core/`, `app/theme` | `LoginPage` |

**Why bother?** Look at `AppUser` in [`lib/features/auth/domain/app_user.dart`](lib/features/auth/domain/app_user.dart). The rest of the app never sees Firebase's `User` class, only our own `AppUser`. So:

- **Tests don't need Firebase.** `FakeAuthRepository` hands out `AppUser`s directly.
- **Swapping Firebase for something else later** only touches `data/`.
- **Firebase API changes** (like the three major versions v1 skipped) are contained in one place.

### `app/` vs `core/` vs `features/`

- `features/` knows about the product ("projects", "tasks").
- `core/` knows nothing about the product. `EmptyState` could be copied into any app.
- `app/` is the glue that knows about *all* features (the router imports every page), so nothing in `features/` should import from `app/` except the theme and `Routes` constants.

### Why is `legacy/` there?

The v1 code isn't null-safe, so it can't compile alongside Dart 3 code. Moving it to `legacy/lib/` and adding `legacy/**` to `analyzer.exclude` in `analysis_options.yaml` keeps it readable as a reference without breaking the build. Each file gets deleted once its feature is rewritten, and the whole folder goes at the end of Phase 3.

### The platform folders

`web/`, `android/`, `ios/`, `macos/`, `windows/` are small native "host" projects generated by `flutter create`. They start the Flutter engine and hold platform settings (app icons, permissions, bundle IDs). You rarely edit them. The ones you're most likely to touch:

| File | Why you'd touch it |
|---|---|
| `web/index.html`, `web/manifest.json` | Page title, description, PWA colours and icons |
| `android/app/build.gradle.kts` | Android app ID (`com.jaival.taskly`), SDK versions |
| `android/app/google-services.json` | Android Firebase config, generated by FlutterFire |
| `ios/Runner/Info.plist` | iOS permissions (camera, notifications…) |

---

## 5. Core concepts, explained with our code

### 5.1 Widgets and immutability

In Flutter, a widget is a **description** of part of the UI, not the UI itself. Flutter rebuilds widgets often (on every state change), then works out the minimal set of screen changes.

That's why you'll see `const` everywhere:

```dart
const EmptyState(icon: Icons.folder_outlined, title: 'No projects yet', ...)
```

A `const` widget is created once at compile time and reused on every rebuild, which is free performance. It's also why models are `@immutable` with `final` fields: immutable data can't change underneath you, so there are no "who modified this?" bugs. v1 models had mutable fields like `String taskName;`.

`AppUser` also overrides `==` and `hashCode`. Riverpod and Flutter compare old and new values to decide whether to rebuild, and without these, two identical users would count as "different".

### 5.2 Riverpod: state and dependency injection

A **provider** is a globally declared, lazily created, cached value. Widgets ask for it, and Riverpod builds it on first use and tracks who depends on what.

From [`lib/features/auth/data/auth_repository.dart`](lib/features/auth/data/auth_repository.dart):

```dart
// A plain object, created once.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(FirebaseAuth.instance),
);

// A live stream, exposed as AsyncValue (loading / data / error).
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);
```

Providers can depend on other providers (`ref.watch(authRepositoryProvider)`). That builds a **dependency graph** Riverpod manages for you: no singletons, no passing objects through constructors.

**`ref.watch` vs `ref.read`.** This is the most important Riverpod rule. From `_AccountMenu` in [`lib/app/app_shell.dart`](lib/app/app_shell.dart):

```dart
final user = ref.watch(authStateProvider).value;            // in build(): rebuild when it changes
...
onPressed: () => ref.read(authRepositoryProvider).signOut(), // in a callback: just get it once
```

| | Use in | Effect |
|---|---|---|
| `ref.watch` | `build()` methods, provider bodies | Subscribes, so the widget rebuilds when the value changes |
| `ref.read` | Button handlers and other callbacks | One-off read, no subscription |

Using `watch` in a callback, or `read` in `build`, is a classic bug.

**`AsyncValue`.** A `StreamProvider` or `FutureProvider` gives you an `AsyncValue<T>` that is exactly one of loading, data or error. That replaces v1's pattern of `initialData: null` followed by `if (data == null) return Loading();`, which couldn't tell "loading" from "failed" from "empty". From Phase 3 on you'll write:

```dart
return switch (ref.watch(projectsProvider)) {
  AsyncData(:final value) when value.isEmpty => const EmptyState(...),
  AsyncData(:final value) => ProjectGrid(value),
  AsyncError() => ErrorState(onRetry: () => ref.invalidate(projectsProvider)),
  _ => const ProjectGridSkeleton(),
};
```

**Overrides make testing easy.** Because everything comes from providers, tests can replace any piece. `test/helpers/pump_app.dart` swaps real Firebase auth for a fake:

```dart
ProviderContainer(overrides: [
  authRepositoryProvider.overrideWithValue(fakeAuth),
]);
```

The whole app then runs against the fake, with no Firebase and no network.

### 5.3 Routing with go_router

All navigation is defined in one place: [`lib/app/router.dart`](lib/app/router.dart).

**Declarative routes.** Each URL maps to a page:

```dart
GoRoute(path: Routes.login, builder: (context, state) => const LoginPage()),
```

Route paths live in the `Routes` class, so a typo becomes a compile error instead of a broken link.

**`go` vs `push`:**
- `context.go('/projects')` means "make the URL this", replacing the history to match. Use it for top-level navigation.
- `context.push('/profile')` adds a page on top, so Back returns to where you were. The account menu uses `push` for Profile.

**The auth redirect.** Instead of v1's `Wrapper` widget, the router checks every navigation:

```
             signed out                         signed in
public page  (/, /login, /signup) → allow       → go to ?from= target, or /home
app page     (/home, /projects…)  → /login?from=<where you were going>   → allow
```

The logic is a **pure function**, `authRedirect()`: no widgets, no Firebase, just inputs → output. That makes it trivially unit-testable (see `test/app/router_test.dart`), which is why it's pulled out and marked `@visibleForTesting`.

**Security detail: open redirects.** The `?from=` parameter comes from the URL, so anyone can craft a link. `_isSafeReturnPath` only accepts in-app paths starting with a single `/`. Without it, `taskly.app/login?from=https://evil.com` would bounce users to a phishing site right after they sign in. This is a real, common vulnerability class.

**Re-running the redirect when auth changes.** go_router only re-checks `redirect` when a `Listenable` it's watching fires. `_StreamListenable` turns the auth stream into one, so signing out anywhere immediately redirects to login.

**`StatefulShellRoute.indexedStack`.** The four main tabs (Home, Projects, Tasks, Shared) are *branches* of a shell. Each branch keeps its own navigation stack alive in an `IndexedStack`, so if you scroll down Projects, switch to Tasks and come back, your scroll position is still there. `AppShell` wraps all of them with the navigation UI.

### 5.4 Responsive layout

[`lib/app/app_shell.dart`](lib/app/app_shell.dart) picks the navigation style from the window width, using the Material 3 "window size classes" in `Breakpoints` (`lib/app/theme/app_spacing.dart`):

| Width | Layout | Widget |
|---|---|---|
| < 600 | Phone | `NavigationBar` at the bottom |
| 600 – 1199 | Tablet / small window | `NavigationRail` on the side |
| ≥ 1200 | Desktop | `NavigationDrawer`, always visible |

It uses `MediaQuery.sizeOf(context)` rather than `MediaQuery.of(context).size`. `sizeOf` only rebuilds the widget when the *size* changes, not when anything else in `MediaQuery` changes (like the keyboard opening). It's a small but real performance habit.

v1 used `MediaQuery.of(context).size.width / 5` for panel widths, so nothing reflowed on small screens.

### 5.5 Theming and design tokens

Rule: **widgets never hard-code colours, font sizes or spacing.** v1 had `Color.fromRGBO(252, 239, 249, 1)` and `fontSize: 35.0` in dozens of places, which made dark mode impossible and any restyle a hunt through every file.

Instead, values come from one of three places:

1. **`ColorScheme.fromSeed(seedColor: brandSeedColor)`** in [`app_theme.dart`](lib/app/theme/app_theme.dart). Material 3 generates a full, accessible palette (primary, surface, error, and their "on" colours) for light *and* dark mode from one brand colour. Read it with `Theme.of(context).colorScheme.primary`.
2. **Design tokens** in [`app_spacing.dart`](lib/app/theme/app_spacing.dart): `AppSpacing.md` instead of `16`, and `AppRadius.mdAll` instead of `BorderRadius.circular(12)`. Changing spacing app-wide becomes a one-line edit.
3. **`ThemeExtension`** for colours Material doesn't know about, like `PriorityColors` in [`priority_colors.dart`](lib/app/theme/priority_colors.dart). It has light and dark variants, and `lerp` lets Flutter animate smoothly between them when the theme switches.

`AppTheme` takes a `textThemeBuilder` parameter instead of calling Google Fonts directly. Google Fonts downloads fonts over the network, which tests can't do, so tests pass a builder that keeps the default font. This is **dependency injection**: pass in what might change instead of hard-wiring it.

### 5.6 Accessibility built in

- `Skeleton` checks `MediaQuery.disableAnimationsOf(context)` and stops pulsing if the user turned on "reduce motion" in their OS.
- `IconButton(tooltip: 'Account')`: tooltips double as screen-reader labels, and tests find widgets by them (`find.byTooltip('Account')`).
- `showAdaptiveSheet` pads the bottom sheet by `MediaQuery.viewInsetsOf(context).bottom` so the on-screen keyboard never covers form fields.

### 5.7 Putting it together: what happens when you sign out

This traces one user action through every piece above.

1. You tap **Sign out** in the account menu. `_AccountMenu` calls `ref.read(authRepositoryProvider).signOut()`. It's `read`, not `watch`, because this is a callback.
2. `AuthRepository.signOut()` calls Firebase, which clears the saved session.
3. Firebase's `authStateChanges()` stream emits `null`. Two things are listening to it:
   - `_StreamListenable` in `router.dart` calls `notifyListeners()`, which makes go_router re-run `redirect`.
   - `authStateProvider` updates, so any widget that `watch`es it rebuilds.
4. `authRedirect(signedIn: false, uri: /projects)` returns `/login?from=/projects`, and go_router navigates there. The shell and its tabs are disposed.
5. When you sign in again, the stream emits the user, `redirect` runs again, and `authRedirect` sends you back to `/projects` using `from`.

Notice that no page contains "if signed out, go to login" code. Pages don't know auth exists; the router handles it in one place. v1 needed a `Wrapper` widget for this.

**Why the router doesn't `watch` `authStateProvider`.** It would feel natural to write `ref.watch(authStateProvider)` inside `routerProvider`. But then every sign-in or sign-out would re-run the provider, building a brand-new `GoRouter` and throwing away the navigation stack and every tab's state. Instead the router is created once, and auth changes reach it through `refreshListenable`. The general rule: a provider that creates a long-lived object (a router, a controller, a connection) should only `watch` things that really require a new object.

---

## 6. Testing

Run everything with `flutter test`. The suite currently has 27 tests and runs in a few seconds.

### The testing pyramid

```
        ▲  fewer, slower, more realistic
       ╱ ╲      integration tests  (Phase 5: real app + Firebase emulator)
      ╱   ╲
     ╱─────╲    widget tests       (render widgets, tap, check the screen)
    ╱       ╲
   ╱─────────╲  unit tests         (pure Dart functions, milliseconds each)
  ▼  many, fast, focused
```

| File | Kind | What it proves |
|---|---|---|
| `test/features/auth/app_user_test.dart` | Unit | Avatar initials logic |
| `test/app/router_test.dart` → `authRedirect` group | Unit | Every redirect rule, including the open-redirect guard |
| `test/app/router_test.dart` → `navigation` group | Widget | Deep links, sign-in continues to the target, sign-out, 404 |
| `test/app/app_shell_test.dart` | Widget | Right nav widget at each width, tabs switch, profile back button |
| `test/core/dialogs_test.dart` | Widget | Sheet vs dialog by width, confirm returns true/false |

### Fakes, not mocks

`test/helpers/fake_auth_repository.dart` is a small working in-memory implementation of `AuthRepository`. You can call `fake.emit(testUser)` to simulate signing in. A fake behaves like the real thing, so tests read like real usage. Mocks (as in `mockito`) instead script individual calls ("when X is called, return Y"), which is more brittle. Use fakes by default.

### How `pumpApp` works

`test/helpers/pump_app.dart` is used by almost every widget test:

1. Sets the test window size, so you can test phone vs desktop layouts.
2. Creates a `ProviderContainer` with the fake auth and a test-friendly theme.
3. Pumps the real `TasklyApp`, the same widget users get.
4. Navigates to the requested URL and waits for animations to settle (`pumpAndSettle`).

Because it pumps the *real* app with only the edges faked, these tests catch real wiring bugs, not just bugs in isolated widgets.

### Rule of thumb

Every bug you fix gets a test that would have caught it. The v1 bugs listed in the roadmap (like the sharing bug and the endless delete listener) are the kind of thing Phase 3's repository tests should pin down.

---

## 7. Configuration, secrets and security

### The Firebase config files

| File | Generated by | Used by | Commit it? |
|---|---|---|---|
| `lib/firebase_options.dart` | `flutterfire configure` | `Firebase.initializeApp` on every platform | Yes |
| `firebase.json` | `flutterfire configure` (later also `firebase deploy`) | The CLIs, to remember which Firebase app belongs to which platform | Yes |
| `android/app/google-services.json` | `flutterfire configure` | The Google Services Gradle plugin, applied in `android/app/build.gradle.kts` | Yes |

To regenerate after adding a platform or changing IDs:

```powershell
flutterfire configure --project=taskly-9ef7d --platforms=android,ios,macos,windows,web
```

### "Isn't the API key in `firebase_options.dart` a secret?"

No. A Firebase API key only **identifies** your project, much like a username. Every web visitor downloads it anyway; it's in the JavaScript. Firebase's own docs say it's safe to commit.

What *actually* protects your data:

1. **Firestore security rules (Phase 2).** Server-side rules like "you can read a project only if your uid is in its `memberIds`". Without good rules, anyone with the key can read everything. This was v1's real weakness.
2. **API key restrictions.** In Google Cloud Console, limit the web key to your domains so it can't be used from other websites.
3. **App Check.** Makes Firebase verify that requests come from your genuine app, not a script.

Things that **are** secret and must never be committed: service account JSON files, third-party API keys (for example an LLM key for the Phase 4 AI feature), and signing keystores for Android and iOS releases. Those go in GitHub Actions *secrets* or Cloud Functions config, never in the repo.

### Line endings

`.gitattributes` has `* text=auto`, so Git stores files with LF line endings and converts them to CRLF on checkout on Windows. The `LF will be replaced by CRLF` warnings you see on `git add` are expected and harmless.

---

## 8. CI/CD: from commit to production

**CI (Continuous Integration)** automatically checks every change. **CD (Continuous Deployment)** automatically ships changes that pass. Both are defined in [`.github/workflows/main.yml`](.github/workflows/main.yml).

```
 push to a PR branch                         push / merge to main
        │                                            │
        ▼                                            ▼
 ┌──────────────── job: check ─────────────────────────────┐
 │ checkout → install Flutter 3.47.5 (cached)               │
 │ → flutter pub get                                        │
 │ → dart format --set-exit-if-changed   (style)            │
 │ → flutter analyze                     (lints, types)     │
 │ → flutter test                        (behaviour)        │
 └──────────────────────────┬──────────────────────────────┘
                            │ only if check passed AND branch is main
                            ▼
 ┌──────────────── job: deploy ────────────────────────────┐
 │ flutter build web --base-href /taskly-flutter/           │
 │ → copy index.html to 404.html                            │
 │ → upload artifact → deploy to GitHub Pages               │
 └─────────────────────────────────────────────────────────┘
```

### Why each piece is there

- **`on: pull_request`:** checks run *before* code is merged, so broken code never reaches `main`.
- **`flutter-version: 3.47.5` (pinned):** CI uses exactly your local version. Otherwise a new Flutter release could break the build without you changing anything. Bump it deliberately, matching `flutter --version` locally.
- **`cache: true`:** reuses the Flutter SDK download between runs, which saves about a minute per run.
- **`concurrency` + `cancel-in-progress`:** if you push twice quickly, the first run is cancelled instead of wasting minutes.
- **`permissions: contents: read`** at the top, with `pages: write` only on the deploy job: the *principle of least privilege*. A compromised step in `check` can't publish anything.
- **`needs: check`:** deploy only runs if every check passed.
- **`dart format --set-exit-if-changed`:** fails if any file isn't formatted. Run `dart format lib test` before pushing.

### GitHub Pages specifics

- **`--base-href /taskly-flutter/`:** the site is served at `jaival.github.io/taskly-flutter/`, not at the domain root. The base href tells the browser where to load `main.dart.js`, fonts and assets from. `web/index.html` contains the `$FLUTTER_BASE_HREF` placeholder that this flag fills in.
- **`404.html` trick:** with clean URLs, refreshing `…/taskly-flutter/projects` asks the server for a file called `projects`, which doesn't exist. GitHub Pages then serves `404.html`, and since that's a copy of `index.html`, the app boots and go_router shows `/projects`. Real hosts like Firebase Hosting do this properly with a "rewrite all paths to index.html" rule, which is one reason Phase 5 moves there.
- **One-time setup:** repo Settings → Pages → Source: **GitHub Actions**.

**Windows tip:** Git Bash rewrites arguments that look like paths, so `--base-href /taskly-flutter/` becomes `C:/Program Files/Git/taskly-flutter/`. Run that command in PowerShell, or prefix it with `MSYS_NO_PATHCONV=1` in Git Bash.

### Branching workflow

```
main ─────●────────────────●──────────►   always deployable, auto-deployed
           \              /
upgrade     ●──●──●──●──●    ← work here, open a PR, CI checks it, merge
```

- `v1-internship` is a **tag**, a permanent bookmark on the original code. `git checkout v1-internship` shows it at any time.
- Keep commits small and focused. One feature rewrite = one PR is a good size.

---

## 9. Building for each platform

| Platform | Run in development | Release build | Needs |
|---|---|---|---|
| Web | `flutter run -d chrome` | `flutter build web` (add `--wasm` for WebAssembly, which is faster) | Chrome |
| Android | `flutter run -d <device>` | `flutter build appbundle` | Android Studio + SDK, emulator or phone |
| iOS | `flutter run -d <iPhone>` | `flutter build ipa` | **A Mac** with Xcode |
| macOS | `flutter run -d macos` | `flutter build macos` | **A Mac** with Xcode |
| Windows | `flutter run -d windows` | `flutter build windows` | Visual Studio "Desktop development with C++" + Windows **Developer Mode** |

`flutter devices` lists what's available, and `flutter doctor` tells you what's missing.

Hot reload: while `flutter run` is running, press `r` to reload code changes in under a second while keeping app state, and `R` for a full restart.

---

## 10. Recipe: adding a new feature

This is the pattern every Phase 3 rewrite follows. Using "projects" as the example:

1. **Domain model:** `features/projects/domain/project.dart`. An immutable class with `final` fields, `==`/`hashCode`, and enums instead of strings (`Priority.high`, not `"High"`).
2. **Repository:** `features/projects/data/project_repository.dart`. The *only* file that imports `cloud_firestore` for projects. It converts Firestore documents into `Project`s and back, and exposes methods like `watchProjects()`, `create()`, `update()` and `delete()`.
3. **Providers:** next to the repository. For example `projectRepositoryProvider`, and `projectsProvider` as a `StreamProvider<List<Project>>`.
4. **Presentation:** `features/projects/presentation/`. The page `ref.watch`es the providers and `switch`es on `AsyncValue` for loading, error, empty and data states. It uses `core/widgets` and theme tokens, never raw colours.
5. **Route:** add the path to `Routes` and a `GoRoute` in `router.dart`. Nested paths like `/projects/:id` go under the projects branch.
6. **Tests:** repository tests with `fake_cloud_firestore`, and widget tests with `pumpApp` plus an overridden repository provider.
7. **Delete the legacy files** this feature replaces (they're listed per feature in the roadmap).
8. **Run the checks** (`dart format`, `flutter analyze`, `flutter test`), then open a PR.

---

## 11. Firestore primer (read before Phase 2)

Firestore works very differently from the SQL databases most courses teach. v1's sharing bugs came from treating it like one, so these ideas are worth understanding before we design the schema.

### Documents and collections

- A **document** is a small JSON-like map of fields (strings, numbers, booleans, timestamps, arrays, maps), up to 1 MiB.
- A **collection** is a set of documents. Documents can hold **subcollections**, so paths alternate: `projects/{projectId}/tasks/{taskId}`.
- There's no fixed schema. Two documents in the same collection can have different fields, so our Dart models are what keep the shape consistent.

### Design for your queries, not your entities

Firestore has **no joins**. A query reads from one collection (or one collection group) and filters on fields in those documents. So you design the data around the screens you need to render, and duplicate small bits of data when that saves a lookup (*denormalisation*).

Example from the Phase 2 schema in the roadmap: every project stores `memberIds: [uid, uid, …]`. "Show me my projects", whether owned or shared, is then a single query:

```dart
projects.where('memberIds', arrayContains: uid)
```

v1 kept shared projects in a separate `SharedProjects` collection matched on free-text usernames. That needed extra reads, broke when a name changed, and couldn't be secured by rules.

### Security rules

Rules run on Google's servers for every read and write, and nothing in the app can bypass them. They live in `firestore.rules` (added in Phase 2):

```
match /projects/{projectId} {
  allow read: if request.auth != null
              && request.auth.uid in resource.data.memberIds;
}
```

Two things surprise almost everyone:

- **Rules are not filters.** `projects.get()` (all projects) is *rejected*, even if you're allowed to read some of them. Firestore refuses any query that *could* return a document you can't read. Your query must include the same condition as the rule, which is exactly what the `arrayContains: uid` query above does.
- **Rules can read other documents** with `get()` and `exists()`, for example "you may edit a task if you're a member of its parent project". Each lookup counts as a billed read, so keep them few.

### Subcollections are not deleted with their parent

Deleting `projects/abc` does **not** delete `projects/abc/tasks/*`. The orphaned tasks stay, invisible but still stored. The repository's `delete()` must remove the tasks first (in batches), or a Cloud Function can clean up later.

### Real-time listeners

`.snapshots()` returns a `Stream` that emits every time the result changes, on any device. A `StreamProvider` turns it into an `AsyncValue`, and Riverpod cancels the subscription when nobody's watching any more. v1 attached listeners by hand and never cancelled them (the roadmap's "endless delete listener" bug).

Firestore also keeps a local cache, so the app can show data offline and queue writes until it reconnects.

### Timestamps

Use `FieldValue.serverTimestamp()` for `createdAt` and `updatedAt`, not `DateTime.now()`. Device clocks are often wrong, and a rule can check that the client didn't fake the value.

### Indexes

Single-field queries work automatically. A query that filters on one field and sorts by another needs a **composite index**. The first time you run one, Firestore throws an error containing a link that creates the index. We'll also record them in `firestore.indexes.json` so they're deployed from the repo.

### Cost

Firestore bills per document **read, write and delete**, not per query or per megabyte. A listener is charged for each document that changes. The free tier (50,000 reads, 20,000 writes and 20,000 deletes per day) is plenty for Taskly, but a screen that loads 500 documents to show 10 adds up fast. Paginate and limit queries.

### The Emulator Suite

The Firebase CLI can run Auth and Firestore locally (`firebase emulators:start`), with a web UI to inspect data. Phase 2 points the app at it in debug builds:

```dart
FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
```

That means you can wipe and re-seed data freely, test security rules, and never touch real users' data during development.

---

## 12. Debugging and troubleshooting

### Tools

- **Flutter DevTools.** `flutter run` prints a DevTools link, and VS Code and Android Studio can open it from the debug toolbar. The **Widget Inspector** shows the widget tree and why something is sized the way it is. **Performance** shows janky frames, and **Network** shows HTTP traffic.
- **Hot reload vs hot restart.** Hot reload (`r`) keeps app state but doesn't re-run `main()` or re-initialise top-level variables, which includes our provider declarations. If a change "doesn't show up", try hot restart (`R`).
- **Logging.** Use `debugPrint` or `dart:developer`'s `log`, not `print` (the linter flags `print`). Riverpod's `ProviderObserver` can log every provider change if you need to see state flow.

### Problems you're likely to hit

| Symptom | Cause | Fix |
|---|---|---|
| `Building with plugins requires symlink support` | Windows blocks the symlinks Flutter makes for plugins | Turn on Developer Mode: `start ms-settings:developers` |
| `--base-href` turns into `C:/Program Files/Git/…` | Git Bash rewrites path-like arguments | Use PowerShell, or `MSYS_NO_PATHCONV=1` in Git Bash |
| `UnsupportedError: DefaultFirebaseOptions have not been configured for …` | That platform isn't in `firebase_options.dart` (we skip Linux) | Run `flutterfire configure` including that platform |
| Blank white page on GitHub Pages, 404s for `main.dart.js` | Wrong `--base-href` | It must match the repo name, with slashes on both sides |
| `[cloud_firestore/permission-denied]` | A security rule rejected the request, often a query without the matching `where` | Check the rules, and check the query includes the rule's condition |
| `The query requires an index` | Composite query without an index | Follow the link in the error, then add it to `firestore.indexes.json` |
| CI fails at the format step | Code wasn't formatted | `dart format lib test`, then commit |
| A widget test times out in `pumpAndSettle` | Something animates forever (`Skeleton`, a spinner), so it never "settles" | Use `tester.pump(const Duration(...))` instead |
| Odd build errors after upgrading packages or Flutter | Stale build cache | `flutter clean && flutter pub get` |

---

## 13. Command cheat sheet

```bash
# Everyday
flutter run -d chrome                 # run the web app with hot reload
flutter test                          # run all tests
flutter test test/app/router_test.dart  # run one file
dart format lib test                  # format code (CI fails if you skip this)
flutter analyze                       # lints and type errors

# Run exactly what CI runs
dart format --output=none --set-exit-if-changed lib test && flutter analyze && flutter test

# Dependencies
flutter pub get                       # install what's in pubspec.lock
flutter pub add <package>             # add a dependency
flutter pub add --dev <package>       # add a dev/test-only dependency
flutter pub outdated                  # see what can be upgraded
flutter pub upgrade                   # upgrade within pubspec.yaml constraints

# Builds
flutter build web --release
flutter build appbundle               # Android (Play Store)

# Troubleshooting
flutter doctor -v                     # what's installed or missing
flutter clean && flutter pub get      # "have you tried turning it off and on again"

# Firebase
flutterfire configure                 # (re)generate lib/firebase_options.dart
firebase login:list                   # which Google account the CLI uses
```

`pubspec.yaml` says what you *want* (`go_router: ^18.0.1` means "18.0.1 or newer, but below 19"). `pubspec.lock` records exactly what you *got*. Apps commit the lock file so every machine and CI builds with identical versions.

---

## 14. Glossary

| Term | Meaning |
|---|---|
| **Widget** | An immutable description of part of the UI. Flutter rebuilds them cheaply and often. |
| **`const`** | Created at compile time and shared, so rebuilds reuse it for free. |
| **Null safety** | Types don't allow `null` unless marked with `?`. The compiler catches null errors. |
| **Provider (Riverpod)** | A declared, cached, lazily created value that widgets and other providers can depend on. |
| **`AsyncValue`** | Loading, data or error: the result of async work, as one value. |
| **Repository** | A class that hides where data comes from (Firebase) behind simple methods returning domain models. |
| **Domain model** | A plain Dart class describing a business concept (`AppUser`, `Project`), with no framework code. |
| **Dependency injection** | Passing dependencies in (via providers or constructors) instead of creating them inside, so they can be swapped, for example in tests. |
| **Fake** | A simple working test implementation of a dependency (like `FakeAuthRepository`). |
| **Redirect / guard** | Router logic that sends users elsewhere based on state (like sign-in). |
| **Deep link** | A URL straight to an inner page, such as `/projects/123`. |
| **Shell route** | A route that wraps child pages in shared UI (our navigation bar, rail or drawer). |
| **Breakpoint** | A window width at which the layout changes. |
| **Design token** | A named design value (`AppSpacing.md`) used instead of a raw number. |
| **Open redirect** | A vulnerability where a URL parameter sends users to an attacker's site. |
| **CI / CD** | Continuous Integration (auto-check every change) / Continuous Deployment (auto-ship passing changes). |
| **Workflow / job / step** | GitHub Actions terms: a workflow file contains jobs (separate machines), and jobs contain steps (commands). |
| **Artifact** | A file bundle produced by one CI step and consumed by another (our built website). |
| **Base href** | The URL path the web app is served under (`/taskly-flutter/`). |
| **SPA** | Single-page application. One `index.html`, with the app handling every URL itself. |
| **Security rules** | Firestore's server-side access control. The real security boundary for our data. |
| **Document / collection / subcollection** | Firestore's storage units: a map of fields, a set of documents, and a collection nested under a document. |
| **Denormalisation** | Deliberately duplicating data (like `memberIds` on a project) so a screen needs one query instead of several. |
| **Composite index** | A Firestore index over several fields, needed for queries that filter and sort on different fields. |
| **Emulator Suite** | Local copies of Firebase services for development and tests. |
| **Hot reload / hot restart** | Swap in code changes keeping app state (`r`), or restart the app from `main()` (`R`). |
| **App Check** | A Firebase feature that verifies requests come from your genuine app. |
| **Tag** | A permanent named pointer to a commit (`v1-internship`). |

---

## 15. Where to learn more

Official sources, in roughly the order you'll need them:

- **Dart language tour:** https://dart.dev/language (null safety, records, patterns)
- **Flutter docs:** https://docs.flutter.dev. Start with "Layouts" and "Adaptive and responsive design".
- **Flutter app architecture guide:** https://docs.flutter.dev/app-architecture. This is where the `domain/data/presentation` layering comes from.
- **Riverpod:** https://riverpod.dev. Read "Essentials" first.
- **go_router:** https://pub.dev/packages/go_router. Look at the examples tab, especially `StatefulShellRoute` and redirection.
- **Material 3:** https://m3.material.io (design) and the "Material 3" section of the Flutter docs.
- **Firebase for Flutter:** https://firebase.google.com/docs/flutter/setup
- **Firestore data modelling and security rules:** https://firebase.google.com/docs/firestore/manage-data/structure-data and https://firebase.google.com/docs/firestore/security/get-started. Essential reading before Phase 2.
- **Flutter testing:** https://docs.flutter.dev/testing/overview
- **GitHub Actions:** https://docs.github.com/actions

**Suggested learning path:** Dart null safety and records → Flutter layouts → Riverpod essentials → go_router redirects → Firestore data modelling and security rules → widget testing. Then read the code files in the order of [section 3](#3-what-happens-when-the-app-starts): `main.dart` → `app.dart` → `router.dart` → `app_shell.dart` → a page → its test.
