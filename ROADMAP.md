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
- [x] Delete each legacy file once its feature is rewritten. Delete `legacy/` completely at the end of Phase 3.
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
projects/{projectId}/tasks/{id}  ownerId, title, description, priority, status, assigneeId,
                                 dueDate, order, createdAt, updatedAt
projects/…/tasks/{id}/activity/{id}   comments and changes: kind, authorId, authorName, value,
                                 createdAt (added in Phase 4)
tasks/{taskId}                   personal tasks: ownerId, plus the same fields as project tasks
invites/{projectId}_{email}      projectId, projectName, email, role, invitedBy, status, createdAt
```

- [x] `enum Priority { immediate, high, medium, low }` and `enum TaskStatus { notStarted, inProgress, complete }` with `label` getters and safe `fromName` parsing (`lib/core/domain/`). Colours come from the theme: `PriorityColors.of(priority)` and `colorScheme.statusColor(status)`. These replace `DropDownData.dart` and the priority-colour `if/else` that was copy-pasted into 4+ files.
- [x] Immutable models (`Project`, `Task`, `Invite`, `UserProfile`) as plain Dart 3 classes, no code generation. Firestore converters live in each feature's `data/` folder and are used through `withConverter<T>()`, so queries return typed objects.
- [x] Store IDs, never usernames, for ownership and assignment.
- [x] Write `firestore.rules`: members read, owner/editors write, viewers update only the status of tasks assigned to them, invite-based joining that needs a verified email, server timestamps enforced. 42 tests in `rules_test/`, run in CI.
- [x] Add `firestore.indexes.json` for the first composite queries (my projects by `updatedAt`, personal tasks by `order`). Add more as queries are written.
- [x] Set up the **Firebase Emulator Suite** (Auth + Firestore). Run the app against it with `--dart-define=USE_FIREBASE_EMULATORS=true`.
- [ ] **You:** deploy the rules and indexes to `taskly-9ef7d` with `firebase deploy --only firestore` (needs `firebase login`). Until then the real database has whatever rules it was created with.

Notes for Phase 3:
- Accepting an invite is one batch: set the invite to `accepted` **and** add yourself to the project's `memberIds` and `roles`. The rules reject the project write unless the same batch accepts the invite.
- Sign-up must send a verification email, because invites only work for verified addresses.
- Deleting a project must delete its `tasks` subcollection first; Firestore doesn't cascade.
- A "tasks assigned to me across all projects" view needs a collection-group query plus a matching rule. That's deliberately left out until the Home rewrite needs it.

---

## Phase 3: Feature rewrites (1–2 weeks)

Rewrite in this order. Each feature is built end to end: repository → Riverpod providers → screens → tests. Delete its legacy files when it's done.

### 3.1 Auth
Legacy: `Services/Auth.dart`, `Screens/Login.dart`, `Screens/SignUp.dart`, `Widgets/Login`, `Widgets/SignUp`, `Widgets/LeftSideLoginSignUp`, `Widgets/RightSideLoginSignUp`

- [x] `AuthRepository` and an auth-state provider that drives the router redirect. It uses `userChanges()`, so the app also notices display-name changes and email verification.
- [x] A single centred login/sign-up card that works on mobile, with `Form` validation, autofill hints for password managers, and a show/hide password toggle.
- [x] Show real error messages by mapping `FirebaseAuthException.code` ("wrong password", "email already in use"). The old code returned `null` and printed the error.
- [x] Create the `users/{uid}` document on sign-up.
- [x] Password reset (cheap to add while you're here). The reply is the same whether or not the account exists.
- [x] Send a verification email on sign-up, with a banner in the shell to resend it or re-check.
- [x] Landing *pushes* the auth pages, so Back returns to it (on Android, Back used to close the app).

### 3.2 Profile
Legacy: `Screens/Profile.dart`, `Widgets/Profile`, `Model/UserData.dart`

- [x] View and edit display name. Saves to both the `users/{uid}` profile (what teammates see) and the auth account (what the avatar shows).
- [x] Sign out moves from the app bar into the shell (avatar menu), and is also on the profile page.
- [x] Shows the email and whether it's verified, and "Change password" emails a reset link.
- [x] Missing profiles repair themselves: logging in creates one if sign-up couldn't, and saving a name creates it too.

### 3.3 Projects
Legacy: `Screens/Projects.dart`, `Widgets/Project/*`, `Shared/CustomProjectTile.dart`, `Model/ProjectModel.dart`

- [x] Responsive project grid (`SliverGrid` with `maxCrossAxisExtent`) instead of fixed 200px horizontal lists.
- [x] Create/edit in the adaptive dialog or sheet, with one primary action instead of Create/Update/Delete buttons shown at once.
- [x] Delete from an overflow menu, with a confirmation and an "Undo" snackbar. Delete the project's tasks with a one-time `get()` + `WriteBatch`. The old code used a live listener that never stopped and kept deleting tasks created later with the same project ID.
  - The project is hidden at once but only deleted when the snackbar closes without Undo, since the rules (rightly) don't allow re-creating a project with its members.
- [x] Project detail page at `/projects/:id` listing its tasks. Unknown IDs and projects you're not in both show "Project not found".
- [x] The menu adapts to the role: owners can edit and delete, editors can edit. Other members can leave (added in 3.6).

### 3.4 Tasks
Legacy: `Screens/Tasks.dart`, `Widgets/Tasks/*`, `Shared/CustomTile.dart`, `Shared/CustomNoTask.dart`, `Model/TaskModel.dart`

- [x] Personal tasks and project tasks share the same `TaskCard`, `PriorityChip` and `StatusChip` widgets. Personal tasks are on `/tasks`; a project's tasks are on its page (`ProjectTaskList`).
- [x] Mark complete with a checkbox and a subtle animation (the title fades and is struck through; no motion with "reduce motion" on). Completed tasks stay in place; sorting and filtering come in Phase 4.
- [x] Form controllers created once with the form and disposed. The old forms set controller text inside `build()`, which wiped what you typed whenever a dropdown changed.
- [x] Validation: required title, and no `"null"` strings saved from empty dropdowns (the shared `PriorityField`/`StatusField` always have a value).
- [x] Delete with Undo and no confirmation (tasks are small). The undo mechanism moved to `core/widgets/undo_delete.dart` and projects use it too.
- [x] Roles: viewers see no add, edit or delete, and can only tick off tasks assigned to them. Editing writes with `update()`, and ticking changes only `status`, which is all the rules let a viewer change.
- Found while testing on a device: a delete retried after a lost acknowledgement was denied (the document was already gone), so the app rolled back and showed a ghost. The rules now allow deleting a document that doesn't exist (45 rules tests).

### 3.5 Home dashboard
Legacy: `Screens/Home.dart`, `Widgets/Home/*`

- [x] Overview of recent projects and tasks, and counts (open, in progress, done). Each count opens its list, "Up next" shows the first five open personal tasks (tick them off right there), and "Recent projects" the four changed most recently. A new account gets a welcome with "Create a project" and "Add a task" instead of rows of zeros.
- [x] Works on every screen size. The old home screen was a fixed desktop `Row` sized as `width / 5`. Counts are two by two on phones and four in a row from 600px; the two lists sit side by side from 900px.

### 3.6 Sharing
Legacy: `Screens/SharedTask.dart`, `Widgets/SharedTask/*`, `Model/SharedTaskModel.dart`

- [x] Invite by **email** to a project, with roles (owner, editor, viewer). Accept or decline from an invites page.
  - The owner invites from the project page's Members section, sees pending and declined invites there, and can cancel them. Re-inviting replaces the old invite.
  - Invites appear on the Shared page once the invitee has verified that email, with a count badge on the Shared tab. Accepting joins the project in one batch with the invite and opens it.
  - The owner can change roles and remove members; anyone else can leave. Deleting a project withdraws its invites.
- [x] Assign tasks to project members from a dropdown instead of free text. Cards show the assignee's name, read from their `users/{uid}` profile.
  - The rules now only check that a *new* assignee is a member, so tasks of someone who left can still be edited and ticked off (50 rules tests). The form shows them as unassigned.
- [x] "Shared with me" is simply projects where your uid is in `memberIds` and you're not the owner, so no separate collection or nested `FutureBuilder`s are needed.
- Found while testing on a device: after one account signed out, per-project providers kept a listener the rules had killed, so the next account saw "Project not found" for a project it had just joined. Those providers are now `autoDispose` and restart when the user or their membership changes (devops.md 5.2).
- "Assigned to me" across all projects needs a collection-group query and index; it's in Phase 4 with filtering.

### 3.7 Landing page and misc
Legacy: `Screens/LandingPage.dart`, `Widgets/LandingPage/*`, `Widgets/NavBar/*`, `Screens/ContactUs.dart`, `Screens/Error.dart`

- [x] Modern hero, feature section and screenshots. The hero and a "whole project" section each show a real screenshot beside the text (above it on phones), six feature cards in one to three columns, and a closing "Create your free account". The old stock illustrations (`1.jpg`, `2.jpg`, licence unknown) are gone.
- [x] A 404 page via `go_router`'s `errorBuilder` (added with the router in 1.5).
- [x] Fix the navbar: the old "Sign In" button opened Sign Up. "Log in" opens login; "Sign up" sits beside it from tablet width, and "Get started" does the same on phones.
- [x] Per-route page `<title>`, meta description, and updated PWA manifest colours and icons.
  - `PageTitle` names the browser tab after the visible page ("Launch · Taskly"), including a project's name, and puts it back after Back or a tab switch.
  - A new app icon (a check on the brand colour) for every platform, generated by `flutter_launcher_icons` from `assets/icon/` (drawn by `tool/make_icons.py`), with an adaptive and themed icon on Android.
  - `index.html` has a real description and Open Graph tags for link previews.
- "Contact us" was an empty placeholder page in v1 and wasn't brought back.

### Applies to every feature
- [x] No hard-coded colours or font sizes; everything comes from the theme. The only colour literals are the brand seed and the priority palette, both in `app/theme/`.
- [x] Loading (skeleton), empty and error states on every list.
- [x] Accessibility: semantic labels, sufficient contrast (the old white-on-pastel text failed), keyboard navigation and focus order, text that scales.
  - `test/app/accessibility_test.dart` runs Flutter's contrast, tap-target and label guidelines on every main page in light and dark mode, checks nothing overflows with text at 200%, and logs in and ticks off a task with only the keyboard.
  - Text at 200% found three overflows, now fixed: the landing app bar, the status label, and the fixed-height project cards (their height now grows with the text).
- [x] Unit tests for the repository (`fake_cloud_firestore`, `firebase_auth_mocks`) and widget tests for its forms and cards. 200 Dart tests and 50 rules tests.

**Exit criteria:** `legacy/` is deleted and every original feature works in the new app. ✅ Met: `legacy/` is gone, and every v1 feature (auth, profile, projects, tasks, home, sharing, landing) has been rewritten and checked on an Android emulator against the Firebase emulators.

---

## Phase 4: New features

Tier A is what makes this feel like a real product. The rest is optional.

### Tier A: core productivity
- [x] **Due dates** with a date picker, an "Overdue / Today / Upcoming" grouping, and relative labels ("in 2 days").
  - An optional "Due date" field in the task form opens the date picker, with a button to clear it. A due date is a calendar day, stored as midnight UTC so it's the same day in every time zone (devops.md 11).
  - Cards say "Today", "Tomorrow", "In 3 days", "2 days ago" or the date, in red with a different icon when overdue. Done tasks are never overdue.
  - The Tasks page groups personal tasks into Overdue, Today, Upcoming (soonest first), No due date and Done. Without any due dates it stays a plain list. Home's "Up next" is the most urgent first.
  - Project pages show the labels but keep their list order; the board view groups them by status instead.
- [x] **Search, filter and sort** by priority, status, project and due date.
  - The Tasks page now lists project tasks assigned to you beside your personal tasks (the "Assigned to me" view left over from 3.6), each labelled with its project. Viewers can tick theirs off there but not edit them. One query per project, not a collection-group query, so the rules stay simple (devops.md 11, with a new index to deploy).
  - A search box (title and description), and menus to filter by priority, status, due (overdue, today, upcoming, none) and project (or personal). "Showing 2 of 8 tasks · Clear filters" appears while anything is filtered.
  - Sort by due date (grouped, as before), priority, newest or title. The choice survives switching tabs, and resets on sign-out.
  - Home's counts and "Up next" include assigned tasks too, and each count opens the Tasks page filtered to that status.
- [x] **Kanban board view** per project (Not Started / In Progress / Complete) with drag and drop, alongside the list view.
  - A List/Board toggle on the project page; the choice applies to every project until the app closes. Columns sit side by side when they fit and scroll sideways on a phone.
  - Drag a card to another column to change its status: press and hold first on touch screens (so swiping still scrolls), a plain drag with a mouse. Each card's menu has "Move to …" and Delete, which also works from a keyboard or screen reader.
  - Viewers can move only the tasks assigned to them, as the rules allow. Moving changes the status only; reordering within a column isn't supported yet.
  - Known gap: on a phone you can't drag into a column that's scrolled out of view (no auto-scroll while dragging). The card menu covers it.
- [x] **Subtasks / checklists** inside a task, with a progress bar on project cards.
  - A "Checklist" section in the task form: add items (Enter adds the next one), tick, rename and remove them. Blank items are dropped on save.
  - Stored as a list of `{text, done}` inside the task document, so a task and its checklist arrive in one read. The rules cap it at 50 items (devops.md 11). Viewers can't change a checklist, as with every field but the status.
  - Task and board cards show "2/5" beside the due date. Project cards show a bar and "3/8" of their tasks done; cards without tasks show nothing.
  - Project cards are a little taller (220), which also fixes a two-line name with a two-line description overflowing the old card. The status label on a narrow card is no longer cut short ("In pro…").
- [x] **Dashboard stats:** overdue count, done this week, and a small completion chart.
  - A card on Home, under the counts: how many tasks were done in the last 7 days (today and the six days before, not the calendar week), a bar for each of those days, and "2 overdue", which opens the Tasks page showing only those. With nothing late it says "Nothing overdue".
  - Tasks now record when they were completed (`completedAt`): set when the status becomes Complete, cleared when the task is reopened, and left alone when a done task is edited. The rules allow it only on a complete task (devops.md 11). Tasks completed before this count on the day they were last changed.
  - Like the counts above it, the card covers personal tasks and the project tasks assigned to you. The chart is drawn with plain widgets, so there's no chart package to keep up to date.
- [x] **Keyboard shortcuts** on desktop web (`N` for new task, `/` for search, `Esc` to close) via `Shortcuts`/`Actions`.
  - `N` opens the new-task form on any signed-in page: a task in the project whose page is open (nothing for a viewer, who can't add tasks), a personal task anywhere else.
  - `/` opens the Tasks page and puts the cursor in its search box. `Esc` there clears the search and leaves the box. `Esc` already closed forms, dialogs and menus; there's now a test for it.
  - `?` lists the shortcuts, as does "Keyboard shortcuts" in the account menu (not on phone-width windows).
  - In a text field the keys are typed as usual, and while a form or dialog is open the shortcuts are off. They work with any keyboard, not only on the web.

### Tier B: accounts and collaboration
- [x] **Google sign-in**, email verification, change password, delete account.
  - [x] Email verification: done in Phase 1 (the banner, "Resend" and "I've verified").
  - [x] Change password: "Change password" on the Profile page asks for the current password and a new one (at least 8 characters, and different). Checking the current one is what Firebase requires before a password change, and it stops someone at an unlocked laptop locking the owner out. "Forgot it? Email me a reset link" is still there for anyone who can't remember it.
  - [x] Delete account: "Delete account" at the bottom of the Profile page. The dialog says what goes (your personal tasks, the projects you own with their tasks and invites), warns when some of those projects are shared, and asks for your password.
    - Projects shared with you stay, without you. Tasks you created there stay too, and tasks assigned to you show as unassigned.
    - There are no Cloud Functions, so the app deletes the data as you, then the account last (devops.md 4). If the connection drops part-way the account is still there, and deleting again finishes the job.
    - Invites other people sent to your email are left alone: they belong to the inviter, who can cancel them.
  - [x] Google sign-in, on the web: "Continue with Google" on the login and sign-up pages. The first time it creates the account and its profile, with the name from Google. Closing Google's window just leaves you on the page.
    - **To do in the console before it works:** enable the Google provider and check the authorised domains (devops.md 7). Until then the button says that way of signing in isn't enabled. The flow is covered by tests against a fake, but has not been tried against real Google yet.
    - Someone who signs in with Google has no password, so the Profile page says "Signed in with Google" instead of "Change password", and deleting the account asks them to sign in with Google again rather than for a password.
    - Not on Android or iOS yet: that needs the `google_sign_in` package and per-app setup in the console, so the button isn't shown there. The button has no Google logo.
- [x] **Comments and an activity log** on tasks ("Alex moved this to In Progress").
  - A speech-bubble button on every project task (and "Comments and activity" in a board card's menu) opens the task's comments and its history in one list, oldest first, with a box to add a comment. Enter sends.
  - Everyone in the project can comment, viewers included. You can delete your own comments; owners and editors can delete anyone's. Comments can't be edited.
  - The log records who created the task, and each change to its title, description, status, priority, assignee and due date. Ticking checklist items isn't logged.
  - Each entry is written together with the change it describes, so the two can't disagree, and keeps its author's name, so it still reads properly after they leave the project or delete their account (devops.md 11).
  - Personal tasks have neither: there's nobody else to tell. Tasks made before this start with an empty history. The list shows the latest 100 entries, and cards don't show how many comments a task has.
- [ ] **Avatar upload** via Firebase Storage.
  - Not started, and waiting on a decision: Cloud Storage for Firebase now needs the pay-as-you-go (Blaze) plan, even to stay inside the free quota. Everything else in the app runs on the free plan.

### Tier C: platform
- [x] **Offline support.** Firestore persistence is on by default for mobile and can be enabled for web. Add an "offline" banner.
  - The app opens and can be used without a connection. Firestore keeps a copy of your data on the device: phones always did, and the browser is now told to as well, sharing one copy between tabs.
  - A banner under the app bar says "You're offline. Changes are saved on this device and sent when you're back online", on every signed-in page.
  - Forms no longer wait for the server while offline. Before, saving a task without a connection spun until it came back; now the change shows at once and is sent later (devops.md 11).
  - Still needs a connection: signing in and up, changing your password, deleting your account. If the server refuses a change made offline (you were removed from the project meanwhile), it's undone on the device when you reconnect, without a message.
  - "Offline" means no network at all. A Wi-Fi that isn't connected to the internet still counts as online, and there the app waits as before.
- [x] **Installable PWA** with an update prompt.
  - The web app can be installed: the browser offers it in the address bar, and while it does, "Install app" is in the account menu. Safari has no such offer; there it's Share, then "Add to Home Screen".
  - A copy of the app is kept on the device, so it opens at once and without a connection, on any page. With the offline support above, the installed app can be opened and used on a plane.
  - When a newer version has been deployed, the app downloads it in the background and a banner says "A new version of Taskly is ready", with a Reload button. It never reloads by itself, since there may be a half-written task on the screen. Leave the banner alone and the new version is simply there the next time the app is opened.
  - It looks for a new version shortly after opening, and again when you come back to a tab that has been open for half an hour or more.
  - Flutter no longer writes the service worker that makes this work, so the app has its own: `web/sw.js` (devops.md 9). It has tests (`web_test/`), which CI runs.
  - Tried in Chrome against a local release build: first visit, reopening with the server switched off, a second version appearing, Reload. The browser's real install offer could not be tried there (a simulated one was), and nothing has been tried in Safari or Firefox.
- [ ] **Android/iOS builds.** The responsive UI from Phase 3 already works on phones.
  - Android is ready to release, short of two things only you can do: make the upload key, and create the app in the Play Console (devops.md 9, "Releasing on Android").
    - A release build (`flutter build apk --release` or `appbundle`) compiles and runs: signing in, loading and saving were tried on the emulator against the Firebase emulators. Release builds shrink the code, which is where Firebase apps tend to break, so this was worth trying.
    - The build signs with your key as soon as `android/key.properties` exists, and with the debug key until then. Tried with a throwaway key.
    - The app is now called "Taskly" under its icon (it was "taskly"), and asks for the internet permission itself instead of relying on Firebase's libraries to.
    - Not done: Google sign-in on Android (Tier B), and a store listing (screenshots, description, privacy policy).
  - iOS hasn't been built at all: that needs a Mac with Xcode, and an Apple developer account to release.
- [ ] **Notifications:** due-date reminders via Firebase Cloud Messaging and a scheduled Cloud Function.

### Tier D: stretch
- [x] **Calendar view** of tasks by due date.
  - The Tasks page has a switch beside the search box: list or calendar. The calendar shows a month, with a dot on each day for every task due then (red if overdue, grey if done, "+" after three), and the chosen day's tasks listed underneath as the usual cards.
  - Tap a day to see it; arrows change the month and "Today" comes back. Weeks start on Sunday: the calendar takes that from the app's language, and the app is only in (US) English so far.
  - Search and the Priority, Status and Project filters narrow the calendar too. Sorting and the "Due" filter are hidden there, since the calendar is by due date already, and a "Due" filter set in the list doesn't hide days in it.
  - "New task" from the calendar starts with the chosen day as its due date.
  - Tasks without a due date can't be on a calendar; a line under it says how many there are.
  - The view and the chosen day are remembered while the app is open, like the filters. Dragging a task to another day isn't there; change its due date in the form.
- [ ] **Recurring tasks** (daily, weekly).
- [ ] **Labels/tags** with colours.
- [ ] **AI assist:** "break this task into subtasks" or natural-language quick add ("Finish report by Friday high priority"), via a Cloud Function calling an LLM API. Keep API keys server-side.
- [x] **Export** to CSV or iCal.
  - The download button beside the search box on the Tasks page saves the tasks on the page, so the search and filters decide what's in the file. In a browser it downloads; on a phone it opens the share sheet, to save the file or send it.
  - **Spreadsheet (.csv):** title, description, status, priority, due date, project, checklist progress, created and completed dates. Opens in Excel, Google Sheets and Numbers, accents included.
  - **Calendar (.ics):** each task with a due date as an all-day event, done ones ticked, to import into Google Calendar, Outlook or Apple Calendar. Tasks without a due date can't be in a calendar, and the message says how many were left out.
  - It's a snapshot: the file doesn't update when the tasks do. Importing a newer export updates the same events in calendars that support it, and may duplicate them in others.
  - Events rather than to-dos, because Google Calendar and Outlook ignore to-dos in an imported file.
  - The files were checked by reading them, on Android and in Chrome. They haven't been imported into an actual spreadsheet or calendar program yet.

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
