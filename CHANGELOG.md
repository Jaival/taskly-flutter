# Changelog

## [2.1.0](https://github.com/Jaival/taskly-flutter/compare/v2.0.0...v2.1.0) (2026-10-17)


### Features

* **settings:** add six colour themes and an Appearance section ([d97cb47](https://github.com/Jaival/taskly-flutter/commit/d97cb47ba195936f03ecaafda7970741323f2095))
* **settings:** choose the default view and sort of the Tasks page ([eea2f56](https://github.com/Jaival/taskly-flutter/commit/eea2f56878234223f12593e24c174a373fb467a0))
* **tasks:** move search into the app bar ([eea2f56](https://github.com/Jaival/taskly-flutter/commit/eea2f56878234223f12593e24c174a373fb467a0))
* **tasks:** make task rows compact, with a menu and swipe actions ([ad48c87](https://github.com/Jaival/taskly-flutter/commit/ad48c878a3db21e079cee4b8c77ecf0214326316))
* **tasks:** add quick add to the Tasks page ([44ef65e](https://github.com/Jaival/taskly-flutter/commit/44ef65eab927a3f6998cf3e92de0956ee6db5290))
* **projects:** replace the desktop drawer with a sidebar that lists the projects ([4fb91d8](https://github.com/Jaival/taskly-flutter/commit/4fb91d8f16a39c4d98058d5ff759ab0f7820b6d6))
* replace the check-mark logo with a to-do list ([761ff39](https://github.com/Jaival/taskly-flutter/commit/761ff39aeef69951e382e4e3ff7d807c8f334f11))

## [2.0.0](https://github.com/Jaival/taskly-flutter/compare/v1-internship...v2.0.0) (2026-10-04)


### ⚠ BREAKING CHANGES

* Taskly is rewritten from scratch on Flutter 3.47, Dart 3 and a new Firebase project. Accounts and data from 1.0.0 don't carry over.

### Features

* **auth:** log in, sign up, reset the password and verify the email address ([a9a8898](https://github.com/Jaival/taskly-flutter/commit/a9a889845dd176f0bd7eeca1091419abb777d7ee))
* **auth:** sign in with Google on the web ([9eb471c](https://github.com/Jaival/taskly-flutter/commit/9eb471c8d862434c943c7f6643a106fcf5792d2d))
* **profile:** edit the display name ([5a5847e](https://github.com/Jaival/taskly-flutter/commit/5a5847ed4cf351838c9d4c8f3a11f01f116ca52d))
* **profile:** change the password ([f4d6de0](https://github.com/Jaival/taskly-flutter/commit/f4d6de097467e24c4566ee3cbf7c6eb6f018c795))
* **profile:** delete your account ([b0aa1c9](https://github.com/Jaival/taskly-flutter/commit/b0aa1c903224396664653a2d6a871c7e95c9ca11))
* **home:** show counts, up next and recent projects ([8d6882b](https://github.com/Jaival/taskly-flutter/commit/8d6882b2a23c1757fa31d50d40ab3f70502fb15d))
* **home:** add stats: done in the last 7 days, by day, and overdue ([7fc43eb](https://github.com/Jaival/taskly-flutter/commit/7fc43eb40945811c8ee77c36b06a66381fe2d43a))
* **home:** open the forms straight from the welcome ([4363b2e](https://github.com/Jaival/taskly-flutter/commit/4363b2e264313f8c7e141ec12ab270528baf4f5c))
* **projects:** responsive grid, create and edit form, detail page, delete with undo ([db39413](https://github.com/Jaival/taskly-flutter/commit/db39413dad38f97114b8e86eaa7cd5433cb88df1))
* **projects:** add a board view with drag and drop between statuses ([0e7ee78](https://github.com/Jaival/taskly-flutter/commit/0e7ee785a490085b30ac2b5d81660cea7e6b2613))
* **tasks:** personal and project task lists, task form, complete, and undo delete ([f18778d](https://github.com/Jaival/taskly-flutter/commit/f18778d3223f006dc92b69f9e7b42fb6b5d9604e))
* **tasks:** add due dates, with relative labels and grouping by due date ([ca3047c](https://github.com/Jaival/taskly-flutter/commit/ca3047c9dda18ca359490d00a5b01f4d15f4100a))
* **tasks:** add search, filters and sort, including assigned project tasks ([4512c7b](https://github.com/Jaival/taskly-flutter/commit/4512c7b7d0efcd010435b3fb8fbaff579d45136d))
* **tasks:** add checklists, and task progress on project cards ([8037760](https://github.com/Jaival/taskly-flutter/commit/803776030b54e855d3eab597cda004b12be2053c))
* **tasks:** add comments and an activity log to project tasks ([6e688cc](https://github.com/Jaival/taskly-flutter/commit/6e688ccf0e6d70b04cdba676fbc9b0b156825ea4))
* **tasks:** add a calendar view ([b5e10f3](https://github.com/Jaival/taskly-flutter/commit/b5e10f3fd475e20b5ec4ccae9fc13e0327cfc9ca))
* **tasks:** export tasks as a spreadsheet or a calendar file ([1caaf4b](https://github.com/Jaival/taskly-flutter/commit/1caaf4bafb8ca4a5a82c36ba0091ec204078bd2b))
* **tasks:** add recurring tasks: daily, weekly or monthly ([eeb22c6](https://github.com/Jaival/taskly-flutter/commit/eeb22c6aa2edc07249063579411ac5dc8706238c))
* **labels:** add labels to tasks, in nine colours ([0d6c47b](https://github.com/Jaival/taskly-flutter/commit/0d6c47bac1e74dd5587812fc1c8ad51d176b77f6))
* **sharing:** invite people by email, with members, roles and assignees ([8ed396d](https://github.com/Jaival/taskly-flutter/commit/8ed396d7261e59f4ad502d66a089dc54ee5ced61))
* **offline:** keep working offline, with the data kept in the browser ([ec02ed0](https://github.com/Jaival/taskly-flutter/commit/ec02ed03f3b4f994431ac9f03be49e00c4e198a7))
* **web:** make the web app installable, usable offline, and able to update itself ([5d1d457](https://github.com/Jaival/taskly-flutter/commit/5d1d457fa552d41ccf571a2bad25b9ace70f09e8))
* add keyboard shortcuts: N for a new task, / to search, ? for the list ([f696de6](https://github.com/Jaival/taskly-flutter/commit/f696de640a91fd94a4ed98f67161bd92f60d98d8))
* fit all text at 200% and pass the accessibility guidelines ([4d33827](https://github.com/Jaival/taskly-flutter/commit/4d33827958789ea4eb31b538dd1d918abb1a832b))
* rewrite the landing page ([d828ef2](https://github.com/Jaival/taskly-flutter/commit/d828ef23b3cdc2c78b32fdcc4995f00258d1d765))
* add a new app icon for every platform ([fd1330c](https://github.com/Jaival/taskly-flutter/commit/fd1330ca4f30e370a055174ad4a3d58488c85f0c))
* download builds for Android, iOS, macOS, Windows and the web from each GitHub Release ([91e36ea](https://github.com/Jaival/taskly-flutter/commit/91e36ea1d0e387c74fa7e94c93f728f0f401d2ab))

## [1.0.0](https://github.com/Jaival/taskly-flutter/tree/v1-internship) (2021-04-25)

The original Taskly, built during an internship: a Flutter web app with sign-in, a profile, projects, tasks, a home page, sharing and a landing page. The code is kept at the [`v1-internship`](https://github.com/Jaival/taskly-flutter/tree/v1-internship) tag.
