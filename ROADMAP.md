# Taskly Upgrade Roadmap

Taskly is a Flutter **web** task and project manager backed by Firebase Auth and Firestore. It was last touched around early 2021 (Flutter 2 beta, Dart 2.7, no null safety). The local toolchain is now **Flutter 3.47.5 (stable)**, so the project won't compile as-is.

## Decisions

| Decision | Choice | Consequence |
|---|---|---|
| Database | **Start fresh** | New Firebase project and a new Firestore schema. No data migration. |
| Approach | **Rewrite one feature at a time** | No null-safety migration of old code. Each feature is rebuilt with the new architecture and UI in one pass. |
| State management | Riverpod (`flutter_riverpod` 3.x) | |
| Routing | `go_router` | Real URLs, deep links, browser back button |
| UI | Material 3, seeded from the existing brand purple `#54458D` | |

## Phases

| Phase | Theme | Outcome |
|---|---|---|
| 0 | Preparation | Original preserved, new Firebase project ready |
| 1 | New foundation | Empty app shell that builds and deploys on current Flutter, Dart 3 and Firebase |
| 2 | Data model | New Firestore schema, security rules, emulator |
| 3 | Feature rewrites | Every existing feature rebuilt, one at a time |
| 4 | New features | Features people expect from a task app today |
| 5 | Quality and release | Tests, CI/CD, hosting, monitoring |

---

## Phase 0: Preparation (½ day)

- [x] Tag the current commit `v1-internship` so the original code stays easy to reach, and work on an `upgrade` branch.
- [ ] Create a **new Firebase project** and enable Email/Password auth and Firestore. *(Project `taskly-9ef7d` created and configured for Android, iOS, macOS, Windows and web; confirm Email/Password and Firestore are enabled in the console.)*
- [ ] Leave the old `taskly-dc4e2` project alone until v2 is live, then delete it. Its web API key is committed in `web/index.html`, and the Firestore rules that shared tasks rely on are probably wide open.
- [ ] ~~Take screenshots of the old app from the live GH Pages deploy~~ GitHub Pages is no longer enabled on the repo, so there is no live v1 to screenshot. Skip, or check out `v1-internship` with an old Flutter SDK (e.g. via `fvm`).

---

## Phase 1: New foundation (1–2 days)

The old code isn't null-safe, so it can't compile next to new code. Move it out of the way and build a clean skeleton.

### 1.1 Park the old code
- [x] Move the old `lib/` to `legacy/lib/` and exclude it in `analysis_options.yaml` (`analyzer: exclude: [legacy/**]`). It stays readable as a reference while you port features.
- [ ] Delete each legacy file once its feature is rewritten. Delete `legacy/` completely at the end of Phase 3.
- [x] Delete the old `test/widget_test.dart`. It's the default counter test and fails.

### 1.2 Regenerate the project scaffolding
- [x] Back up `web/icons`, `favicon.png` and `manifest.json`. Delete `web/` and `.metadata`, then run `flutter create --platforms=web --org <your.org> .`. This gives you the modern `flutter_bootstrap.js` loader and removes the old Firebase `<script>` tags and inline config. Restore the icons afterwards.
- [x] Add `android`, `ios`, `macos` and `windows` (bundle ID `com.jaival.taskly`). Windows desktop builds need Windows **Developer Mode** turned on for plugin symlinks.

### 1.3 Dependencies
Rewrite `pubspec.yaml` from scratch with `sdk: ^3.x` (match the installed Dart) and current packages:

| Package | Old | Latest (Sep 2026) |
|---|---|---|
| firebase_core | ^1.0.1 | 4.15.0 |
| firebase_auth | ^1.0.1 | 6.7.0 |
| cloud_firestore | ^1.0.1 | 6.10.0 |
| google_fonts | ^2.0.0 | 8.2.1 |
| flutter_riverpod | – | 3.4.3 |
| go_router | – | 18.0.1 |
| provider, flutter_spinkit, cupertino_icons | | drop |

- [x] Add `flutter_lints` (or the stricter `very_good_analysis`) in `analysis_options.yaml`.

### 1.4 Firebase
- [x] Install the FlutterFire CLI and run `flutterfire configure` against the **new** project. This generates `lib/firebase_options.dart`.
- [x] In `main()`: `WidgetsFlutterBinding.ensureInitialized(); await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);`
- [ ] Restrict the new web API key to your domains in Google Cloud Console and turn on **App Check**.

### 1.5 App skeleton
```
lib/
  app/            # app.dart, router.dart, theme/
  core/           # shared widgets, utils, extensions
  features/
    auth/         # data/, domain/, presentation/
    projects/
    tasks/
    sharing/
    profile/
    landing/
  firebase_options.dart
  main.dart
```
- [x] Material 3 theme: `ColorScheme.fromSeed(seedColor: Color(0xFF54458D))`, Montserrat via `google_fonts` defined once in `TextTheme`, light and dark variants.
- [x] Spacing and radius tokens (e.g. `AppSpacing.md`) and a `ThemeExtension` for priority colours so they work in dark mode.
- [x] `go_router` with `usePathUrlStrategy()` (no `#` in URLs) and an auth redirect, replacing the old `Wrapper`.
- [x] A responsive app shell with placeholder pages:
  - **≥1200px:** permanent `NavigationDrawer` sidebar
  - **600–1200px:** `NavigationRail`
  - **<600px:** bottom `NavigationBar`
- [x] Shared widgets that every feature will use: `EmptyState`, `ErrorState`, skeleton loaders, confirmation dialog, and an adaptive "form in a dialog on desktop, bottom sheet on mobile" helper.

### 1.6 CI (`.github/workflows/main.yml`)
- [x] `actions/checkout@v2` → current major. `subosito/flutter-action@v1` → current major, with `channel: stable` and a pinned `flutter-version`.
- [x] Run `flutter analyze` and `flutter test` **before** deploy.
- [x] Replace the unmaintained `erickzanardo/flutter-gh-pages@v3` with `flutter build web --base-href /taskly-flutter/` plus the official `actions/deploy-pages`, or move to Firebase Hosting now (see Phase 5).

**Exit criteria:** `flutter analyze` is clean, `flutter run -d chrome` shows the empty shell with working navigation, and CI deploys it.

---

## Phase 2: Data model (1 day)

The old schema (`Projects/{uid}/userProjects`, `Tasks/{uid}/userTasks`, and a separate `SharedProjects` collection matched on free-text usernames) made sharing insecure. The new one is built around membership:

```
users/{uid}                      displayName, email, photoUrl, createdAt
projects/{projectId}             ownerId, memberIds[], roles{uid: role}, name, description,
                                 priority, status, createdAt, updatedAt
projects/{projectId}/tasks/{id}  title, description, priority, status, assigneeId,
                                 dueDate, order, createdAt, updatedAt
tasks/{taskId}                   personal tasks: ownerId, plus the same fields as project tasks
invites/{inviteId}               projectId, email, role, invitedBy, status, createdAt
```

- [ ] `enum Priority { immediate, high, medium, low }` and `enum TaskStatus { notStarted, inProgress, complete }` with `label` and `color` getters. These replace `DropDownData.dart` and the priority-colour `if/else` that was copy-pasted into 4+ files.
- [ ] Immutable models with `fromFirestore`/`toFirestore`, used through Firestore `withConverter<T>()` so queries return typed objects. Use `freezed` + `json_serializable`, or plain Dart 3 classes if you'd rather avoid code generation.
- [ ] Store IDs, never usernames, for ownership and assignment.
- [ ] Write `firestore.rules` and commit it. A user can read a project if `request.auth.uid in resource.data.memberIds`, and only the owner or editors can write. Deploy with the Firebase CLI.
- [ ] Add `firestore.indexes.json` for the composite queries you add later (filters plus sorting).
- [ ] Set up the **Firebase Emulator Suite** (Auth + Firestore) for local development and tests, so nothing touches production data.

---

## Phase 3: Feature rewrites (1–2 weeks)

Rewrite in this order. Each feature is built end to end: repository → Riverpod providers → screens → tests. Delete its legacy files when it's done.

### 3.1 Auth
Legacy: `Services/Auth.dart`, `Screens/Login.dart`, `Screens/SignUp.dart`, `Widgets/Login`, `Widgets/SignUp`, `Widgets/LeftSideLoginSignUp`, `Widgets/RightSideLoginSignUp`

- [ ] `AuthRepository` and an auth-state provider that drives the router redirect.
- [ ] A single centred login/sign-up card that works on mobile, with `Form` validation.
- [ ] Show real error messages by mapping `FirebaseAuthException.code` ("wrong password", "email already in use"). The old code returned `null` and printed the error.
- [ ] Create the `users/{uid}` document on sign-up.
- [ ] Password reset (cheap to add while you're here).

### 3.2 Profile
Legacy: `Screens/Profile.dart`, `Widgets/Profile`, `Model/UserData.dart`

- [ ] View and edit display name.
- [ ] Sign out moves from the app bar into the shell (avatar menu).

### 3.3 Projects
Legacy: `Screens/Projects.dart`, `Widgets/Project/*`, `Shared/CustomProjectTile.dart`, `Model/ProjectModel.dart`

- [ ] Responsive project grid (`SliverGrid` with `maxCrossAxisExtent`) instead of fixed 200px horizontal lists.
- [ ] Create/edit in the adaptive dialog or sheet, with one primary action instead of Create/Update/Delete buttons shown at once.
- [ ] Delete from an overflow menu, with a confirmation and an "Undo" snackbar. Delete the project's tasks with a one-time `get()` + `WriteBatch`. The old code used a live listener that never stopped and kept deleting tasks created later with the same project ID.
- [ ] Project detail page at `/projects/:id` listing its tasks.

### 3.4 Tasks
Legacy: `Screens/Tasks.dart`, `Widgets/Tasks/*`, `Shared/CustomTile.dart`, `Shared/CustomNoTask.dart`, `Model/TaskModel.dart`

- [ ] Personal tasks and project tasks share the same `TaskCard`, `PriorityChip` and `StatusChip` widgets.
- [ ] Mark complete with a checkbox and a subtle animation.
- [ ] Form controllers created in `initState` and disposed. The old forms set controller text inside `build()`, which wiped what you typed whenever a dropdown changed.
- [ ] Validation: required title, and no `"null"` strings saved from empty dropdowns.

### 3.5 Home dashboard
Legacy: `Screens/Home.dart`, `Widgets/Home/*`

- [ ] Overview of recent projects and tasks, and counts (open, in progress, done).
- [ ] Works on every screen size. The old home screen was a fixed desktop `Row` sized as `width / 5`.

### 3.6 Sharing
Legacy: `Screens/SharedTask.dart`, `Widgets/SharedTask/*`, `Model/SharedTaskModel.dart`

- [ ] Invite by **email** to a project, with roles (owner, editor, viewer). Accept or decline from an invites page.
- [ ] Assign tasks to project members from a dropdown instead of free text.
- [ ] "Shared with me" is simply projects where your uid is in `memberIds`, so no separate collection or nested `FutureBuilder`s are needed.

### 3.7 Landing page and misc
Legacy: `Screens/LandingPage.dart`, `Widgets/LandingPage/*`, `Widgets/NavBar/*`, `Screens/ContactUs.dart`, `Screens/Error.dart`

- [ ] Modern hero, feature section and screenshots.
- [ ] A 404 page via `go_router`'s `errorBuilder`.
- [ ] Fix the navbar: the old "Sign In" button opened Sign Up.
- [ ] Per-route page `<title>`, meta description, and updated PWA manifest colours and icons.

### Applies to every feature
- [ ] No hard-coded colours or font sizes; everything comes from the theme.
- [ ] Loading (skeleton), empty and error states on every list.
- [ ] Accessibility: semantic labels, sufficient contrast (the old white-on-pastel text failed), keyboard navigation and focus order, text that scales.
- [ ] Unit tests for the repository (`fake_cloud_firestore`, `firebase_auth_mocks`) and widget tests for its forms and cards.

**Exit criteria:** `legacy/` is deleted and every original feature works in the new app.

---

## Phase 4: New features

Tier A is what makes this feel like a real product. The rest is optional.

### Tier A: core productivity
- [ ] **Due dates** with a date picker, an "Overdue / Today / Upcoming" grouping, and relative labels ("in 2 days").
- [ ] **Search, filter and sort** by priority, status, project and due date.
- [ ] **Kanban board view** per project (Not Started / In Progress / Complete) with drag and drop, alongside the list view.
- [ ] **Subtasks / checklists** inside a task, with a progress bar on project cards.
- [ ] **Dashboard stats:** overdue count, done this week, and a small completion chart.
- [ ] **Keyboard shortcuts** on desktop web (`N` for new task, `/` for search, `Esc` to close) via `Shortcuts`/`Actions`.

### Tier B: accounts and collaboration
- [ ] **Google sign-in**, email verification, change password, delete account.
- [ ] **Comments and an activity log** on tasks ("Alex moved this to In Progress").
- [ ] **Avatar upload** via Firebase Storage.

### Tier C: platform
- [ ] **Offline support.** Firestore persistence is on by default for mobile and can be enabled for web. Add an "offline" banner.
- [ ] **Installable PWA** with an update prompt.
- [ ] **Android/iOS builds.** The responsive UI from Phase 3 already works on phones.
- [ ] **Notifications:** due-date reminders via Firebase Cloud Messaging and a scheduled Cloud Function.

### Tier D: stretch
- [ ] **Calendar view** of tasks by due date.
- [ ] **Recurring tasks** (daily, weekly).
- [ ] **Labels/tags** with colours.
- [ ] **AI assist:** "break this task into subtasks" or natural-language quick add ("Finish report by Friday high priority"), via a Cloud Function calling an LLM API. Keep API keys server-side.
- [ ] **Export** to CSV or iCal.

---

## Phase 5: Quality and release (ongoing, formalise at the end)

- [ ] **Integration tests:** a small `integration_test` suite against the emulator for sign up → create project → add task → complete task.
- [ ] **CI:** analyze, test, and `flutter build web --wasm` on every PR. Deploy only from `main`.
- [ ] **Hosting:** move from GH Pages to **Firebase Hosting**, with PR preview channels and the same project as auth and data. Keep GH Pages only if you want the public URL unchanged.
- [ ] **Monitoring:** Firebase Analytics, plus Crashlytics if you ship mobile.
- [ ] **README:** screenshots, a feature list, a tech-stack section, and setup steps (`flutterfire configure`, emulators, run). Useful if this goes in a portfolio.
- [ ] Delete the old `taskly-dc4e2` Firebase project.

---

## Milestones

1. **M1: "Fresh foundation."** Phases 0–2. Empty shell, new Firebase project, schema and rules, CI deploying.
2. **M2: "Can log in."** 3.1 Auth and 3.2 Profile.
3. **M3: "Feature parity."** 3.3–3.7. `legacy/` deleted.
4. **M4: "Real product."** Phase 4 Tier A, then Tier B.
5. **M5: "Shipped."** Phase 5.
