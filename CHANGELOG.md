# Changelog

## [2.1.0](https://github.com/Old-Gods/og_messenger/compare/v2.0.0...v2.1.0) (2026-02-24)


### Features

* add multicast membership refresh to prevent IGMP timeout ([793f402](https://github.com/Old-Gods/og_messenger/commit/793f402c5ef83966a86599f2764fffcf83734b06))
* add theme mode setting and dialog for user preference ([7703480](https://github.com/Old-Gods/og_messenger/commit/770348011fb38019a4fc8a8d083d1861b4754855))
* enhance message bubble to display online status of members ([e3fddde](https://github.com/Old-Gods/og_messenger/commit/e3fddde5f94b16a3a7d65b97a478c10299cd2d8e))
* implement health check for UDP discovery service and improve multicast lock handling ([89de50b](https://github.com/Old-Gods/og_messenger/commit/89de50b1c981abd643693c3ea6a426e0cf9f2960))


### Bug Fixes

* cross-room message synchronization ([67af62b](https://github.com/Old-Gods/og_messenger/commit/67af62bd78d7a8d0b556b430d9b9d2eee3492441))
* enhance multicast membership handling and improve error reporting ([4cd61b5](https://github.com/Old-Gods/og_messenger/commit/4cd61b56c81fdb02c8759f15e2e0c56d6942cc16))
* remove clear all messages dialog and associated button from settings screen ([7fc984b](https://github.com/Old-Gods/og_messenger/commit/7fc984bded9ea3197110e117ab3afdb28bc5c218))
* remove clear all messages dialog and associated button from settings screen ([c368074](https://github.com/Old-Gods/og_messenger/commit/c3680743f27457c554e94bf6b3c383ad07d5ee5b)), closes [#23](https://github.com/Old-Gods/og_messenger/issues/23)
* update reusePort setting for cross-platform compatibility in UDP socket binding ([f7dbed6](https://github.com/Old-Gods/og_messenger/commit/f7dbed6d9447a8ada102e697133d77fe2a3a6626))

## [2.0.0](https://github.com/Old-Gods/og_messenger/compare/v1.2.0...v2.0.0) (2026-02-24)


### ⚠ BREAKING CHANGES

* Rooms are no-longer based on wifi ssid. Your old rooms will no longer work

### Features

* add new room images and update asset references in chat and room list screens ([f16d202](https://github.com/Old-Gods/og_messenger/commit/f16d2022e7810d380b5ac826fd2ec5cc23d26752))
* add no messages images for empty state in chat screen ([541c578](https://github.com/Old-Gods/og_messenger/commit/541c5784225b5c837dede9a2a47ab66150f5864e))
* add request resolved notification handling and stream ([849cbd0](https://github.com/Old-Gods/og_messenger/commit/849cbd04227eed1dbe6c3fc9b4d503f3524e91ba))
* add themed empty state icon for room list screen ([9baf4fb](https://github.com/Old-Gods/og_messenger/commit/9baf4fb9f0d218441ef1dc6e9d39100b76b87169))
* enhance snackbar behavior and styling across multiple screens ([427c1e6](https://github.com/Old-Gods/og_messenger/commit/427c1e68151f166d5388563c5c9983035669187d))
* implement join request dialog with accept and reject options ([c4d8a6a](https://github.com/Old-Gods/og_messenger/commit/c4d8a6a83c7b3629b214616296fffdfd24e9b1cc))
* implement per-room notification channels for messages ([857316c](https://github.com/Old-Gods/og_messenger/commit/857316c00a7abf079b4d05f2c65ae111480a6ab2))
* implement reusable dialog for leaving a room ([5a12a6b](https://github.com/Old-Gods/og_messenger/commit/5a12a6bf1cc7721cdd86ca9752b30e31be25a23e))
* implement room ID handling in notifications and navigation ([45abf75](https://github.com/Old-Gods/og_messenger/commit/45abf75a58a5caca6ef6effba9e1214eb0e06ef8))
* **messaging:** implement message pagination and initial load functionality ([527b422](https://github.com/Old-Gods/og_messenger/commit/527b422c432a87903f697aaff8cbedb428db30a7))
* **sync:** enhance message sync functionality with acknowledgment and pagination ([366eb2a](https://github.com/Old-Gods/og_messenger/commit/366eb2ac1278a613bc5914f40a0bf71e37f9967c))
* **tcp:** implement message encryption and decryption based on room keys ([d33287f](https://github.com/Old-Gods/og_messenger/commit/d33287f60192cfdd396a6de811464df437a122fb))
* update username prompt screen UI and add image assets ([dc89638](https://github.com/Old-Gods/og_messenger/commit/dc896382739df4272a6e380e787527d13520b5af))


### Bug Fixes

* change notificationDetails declaration to final for consistency ([8ef23a5](https://github.com/Old-Gods/og_messenger/commit/8ef23a5617703ff8a55c0cfc88fca496d1bf88fc))
* enhance message handling with room ID support and improve decryption error handling ([93338aa](https://github.com/Old-Gods/og_messenger/commit/93338aa9e241083a408cfc727452d5e3494a42bf))
* enhance message sync tracking with per-peer expected and received counts ([05d076e](https://github.com/Old-Gods/og_messenger/commit/05d076ee3f72cc7509b039588e67ff82276a72e4))
* implement duplicate message checking in message processing ([f43c5d4](https://github.com/Old-Gods/og_messenger/commit/f43c5d4445d70937dd8127df7f870b6d037a5f76))
* **messaging:** message sync with peers ([0885dd1](https://github.com/Old-Gods/og_messenger/commit/0885dd1f45cb9699dc1b6c81bc6f74a1edb54dd0))
* **network:** implement network ID refresh on macOS location permission grant ([9d9e4ed](https://github.com/Old-Gods/og_messenger/commit/9d9e4ed6ad27b52854150ba58977cc14d7a58dc9))
* notification logic based on active room and app state ([ec7e93e](https://github.com/Old-Gods/og_messenger/commit/ec7e93ee415d1b89d13c2d868a4488cd991bd960))
* prevent manual dialog closure on join request acceptance ([c83ed03](https://github.com/Old-Gods/og_messenger/commit/c83ed033b4daee43a288957cad1546fa78d44b38))
* remove ios unneccessary capabilities ([ebb0352](https://github.com/Old-Gods/og_messenger/commit/ebb0352938f2e3ae9584b5c3d42802205c50d842))
* replace SnackBar with Flushbar for improved message display ([8025cf3](https://github.com/Old-Gods/og_messenger/commit/8025cf3f9c42935f33242503f376e1398bbdb141))
* snackbars to dissapear automatically ([b85a836](https://github.com/Old-Gods/og_messenger/commit/b85a8366dd2aab043c57b8c6e3ce378adb85431c))
* update join request dialog to handle pending requests dynamically ([f2fcb76](https://github.com/Old-Gods/og_messenger/commit/f2fcb76cb3e60083fc0f1b7b71c88cc24d07a6b8))


### Code Refactoring

* setup screen and database schema for multi-room architecture ([3a8cc09](https://github.com/Old-Gods/og_messenger/commit/3a8cc095e4e90acc347f69352753c5dd2e63c0f9))

## [1.2.0](https://github.com/Old-Gods/og_messenger/compare/v1.1.0...v1.2.0) (2026-02-22)


### Features

* add network connectivity monitoring and handling ([4b21a22](https://github.com/Old-Gods/og_messenger/commit/4b21a22af32543f350c92e727e644850efd95898))
* add network connectivity monitoring and handling ([d7f92cb](https://github.com/Old-Gods/og_messenger/commit/d7f92cb73e99660311b3fe2ca5fd709f4d9ec92d))
* **chat:** enhance message bubble to display peer connection status ([3a234fe](https://github.com/Old-Gods/og_messenger/commit/3a234fe0b3b07be9f03ad56ba801ab6e3a0dfd4e))
* **chat:** implement typing indicators and related configurations ([316ab00](https://github.com/Old-Gods/og_messenger/commit/316ab00365eb142dd0f65b25f6412eccb592eb24))


### Bug Fixes

* optimize navigator usage in re-authentication flow ([0e10589](https://github.com/Old-Gods/og_messenger/commit/0e105895d1f14c4e9105f0dd6edd3cdd2f40def2))

## [1.1.0](https://github.com/Old-Gods/og_messenger/compare/v1.0.2...v1.1.0) (2026-02-21)


### Features

* **chat:** enhance message bubble with dynamic color assignment and theming ([6f667cb](https://github.com/Old-Gods/og_messenger/commit/6f667cbfd95052bee2914e9deea1e64ccc8761f3))


### Bug Fixes

* **settings:** trim username and clamp retention days in SettingsService ([35fbbc8](https://github.com/Old-Gods/og_messenger/commit/35fbbc8c12598ae1df9283a997882b348b12bde3))

## [1.0.2](https://github.com/Old-Gods/og_messenger/compare/v1.0.1...v1.0.2) (2026-02-21)


### Bug Fixes

* **app:** update product name to 'OG Messenger' in configuration files ([ae9c028](https://github.com/Old-Gods/og_messenger/commit/ae9c0286ff82d96cd66eab845d94ae78fed0fbd2))
* **chat:** replace Text with SelectableText for message content ([5b53578](https://github.com/Old-Gods/og_messenger/commit/5b535788725b78c7132f7f310214800adbd9b51c))
* **network:** integrate network info service and add location permissions for WiFi SSID detection ([661d323](https://github.com/Old-Gods/og_messenger/commit/661d323e3d7f0b4ff1d43233da2e867dfb5d7530))

## [1.0.1](https://github.com/Old-Gods/og_messenger/compare/v1.0.0...v1.0.1) (2026-02-21)


### Bug Fixes

* **auth:** clear authentication data on app startup to enforce re-authentication ([2075abc](https://github.com/Old-Gods/og_messenger/commit/2075abc1df1342244d78111e095793603af4c7b1))
* **chat:** add focus management for message input field ([478d7c5](https://github.com/Old-Gods/og_messenger/commit/478d7c5e00b0550c793c4c3b2b55e588ef736e3a))
* **setup:** improve peer discovery logic to handle authenticated peers more efficiently ([37fb748](https://github.com/Old-Gods/og_messenger/commit/37fb748e45899d0acb15daa240afbc95225d4b26))

## 1.0.0 (2026-02-21)


### Features

* add adaptive launcher icons and update app icon configurations for multiple platforms ([962508a](https://github.com/Old-Gods/og_messenger/commit/962508a8a73a8d27f9d87be89f31d20f76ba3e68))
* add devtools options file and update peer timeout duration ([2189643](https://github.com/Old-Gods/og_messenger/commit/2189643280db2f9210b21a21f37580263ce79d74))
* Add dismiss action to SnackBars for improved user experience ([0658207](https://github.com/Old-Gods/og_messenger/commit/0658207c8f0290fbb9c49cb15578fffb3cff0154))
* add functionality to clear user authentication data and improve setup screen usability ([847df1b](https://github.com/Old-Gods/og_messenger/commit/847df1bfe68a2ca89dfe00292c4f9951450067fb))
* add initial Windows runner and Flutter integration ([9b9bd5b](https://github.com/Old-Gods/og_messenger/commit/9b9bd5b33adf950b24e815211ef6f3e57450c87e))
* add iOS build job to GitHub Actions workflow ([4bcb204](https://github.com/Old-Gods/og_messenger/commit/4bcb204302b84bf71c9b63f5e2db5bd6d08ee600))
* add notification for incoming messages ([42af111](https://github.com/Old-Gods/og_messenger/commit/42af11128a4f184b605e34781e83f27675cb964d))
* add sync request handling and peer synchronization in messaging service ([44ad5f6](https://github.com/Old-Gods/og_messenger/commit/44ad5f6c46f19a178d5abdd02f7ca1b5145e65be))
* **assets:** update app icons for all platforms with light/dark theme support ([1c013b8](https://github.com/Old-Gods/og_messenger/commit/1c013b8219a14fac0ac1690a67058b02c947027c))
* **assets:** update app icons for light/dark theme support across platforms ([407bfd2](https://github.com/Old-Gods/og_messenger/commit/407bfd2c0e0d02d2ec2e58c91b60331fff546cce))
* enhance notification handling and app lifecycle management ([daa1fb3](https://github.com/Old-Gods/og_messenger/commit/daa1fb328a1268c2f3d33a350c5d4945cbd68ca1))
* Enhance security architecture with RSA/AES encryption and authentication flow ([cf21c04](https://github.com/Old-Gods/og_messenger/commit/cf21c04ce0b403963e40fe5de35876bebf742f54))
* Implement authentication and encryption services ([21e8723](https://github.com/Old-Gods/og_messenger/commit/21e8723402f2e5f6df92e74f253dd643693cd9c0))
* implement auto-scrolling for new messages and after sending ([56ed176](https://github.com/Old-Gods/og_messenger/commit/56ed176e44751b2d5d183882ab12845032b85293))
* Implement messaging feature with TCP server and local storage ([4a94e42](https://github.com/Old-Gods/og_messenger/commit/4a94e420c8d4f11c5e4008b3c0de86a5c123f21e))
* implement name change handling and broadcasting across peers ([5203527](https://github.com/Old-Gods/og_messenger/commit/52035279249629896db61c231d7e2603f01145f7))
* integrate device_info_plus for hardware-based device ID management ([d880c57](https://github.com/Old-Gods/og_messenger/commit/d880c574b735db4cb9ff1e9d5284c7f37990531a))
* integrate package_info_plus for version display and message retention settings ([08b2103](https://github.com/Old-Gods/og_messenger/commit/08b210311d1fb4c8af87a825ca02dc786b014964))
* Pre-populate name field after widget build and check authentication status ([1d19522](https://github.com/Old-Gods/og_messenger/commit/1d19522bed300812465d663a3fb7e2146d36f91a))
* **security:** enhance password management with detailed logging and new password proposal handling ([6da2700](https://github.com/Old-Gods/og_messenger/commit/6da270047e32098959c5e2e7c9c0c538467f55ee))
* **security:** enhance password proposal handling with detailed logging and automatic voting ([fc9a400](https://github.com/Old-Gods/og_messenger/commit/fc9a4003f0b41ef0ad16d3cec6372adba9f4c434))
* **security:** implement password change proposals and voting mechanism ([373eeef](https://github.com/Old-Gods/og_messenger/commit/373eeef6b8c53b39735ca22665850ac06894311c))
* **setup:** update app icons and add asset references for light and dark themes ([4d2213e](https://github.com/Old-Gods/og_messenger/commit/4d2213e10d0619c5ffb30dabf6f2ed5582cfc8a9))


### Bug Fixes

* add flutter_local_notifications_windows to FFI plugin list ([9b4a5e0](https://github.com/Old-Gods/og_messenger/commit/9b4a5e07d24d570bb04dd56854ddc593095b403e))
* add key salt handling for encryption and improve peer detection logic ([b72228d](https://github.com/Old-Gods/og_messenger/commit/b72228d243fc4ebaf602f39f07c7c89b56b42188))
* **chat:** update color opacity handling in message bubble decoration ([bffe210](https://github.com/Old-Gods/og_messenger/commit/bffe2102fac5d7b5ecb505665a042d567b94cec8))
* forcing the first release ([874506a](https://github.com/Old-Gods/og_messenger/commit/874506a77f9f568013f5f5c3e77c1485a01e3715))
* Improve sync request handling and add rate limiting for authentication attempts ([cf21c04](https://github.com/Old-Gods/og_messenger/commit/cf21c04ce0b403963e40fe5de35876bebf742f54))
* prevent multiple initializations and improve user name broadcast logic ([42eaa73](https://github.com/Old-Gods/og_messenger/commit/42eaa735e7c98aa900d4d8e17d78a0a748a0b6fd))
* Refactor auth response construction to use null-aware spread operator ([750759b](https://github.com/Old-Gods/og_messenger/commit/750759b72b9f6b5b51f3ec9531fd369c23ccf4e5))
* **security:** implement listen-only mode for UDP discovery during setup ([36ce974](https://github.com/Old-Gods/og_messenger/commit/36ce97479e9ca4f638efd756ce5b045c09cb77b9))
* **settings:** add method to mark first launch as complete and initialize settings service ([d2faa03](https://github.com/Old-Gods/og_messenger/commit/d2faa036b7c6642ffa71e7b427fe21ebdf8aac85))
* **setup:** improve layout and responsiveness of setup screen ([4961213](https://github.com/Old-Gods/og_messenger/commit/4961213403375b0d3e689f7935d65794eedf2b16))
* **setup:** signing in with a phone ([017b031](https://github.com/Old-Gods/og_messenger/commit/017b031913f8ea0dbf62b3dc16164668d4b48a1a))
* update iOS and macOS build output format from .app to .zip ([38fd130](https://github.com/Old-Gods/og_messenger/commit/38fd1300a2ebcf218129c259685bae8f06e3dd04))
* update notification plugin method calls to use named parameters ([601c7fa](https://github.com/Old-Gods/og_messenger/commit/601c7faaa129dab06b890e029cc03ae5200c3af4))
* update password handling to store only hashed values ([ccd5ef9](https://github.com/Old-Gods/og_messenger/commit/ccd5ef9523fd0796c39ff6efd1ab742434b559c2))
* update send button color to use color scheme ([a80c21f](https://github.com/Old-Gods/og_messenger/commit/a80c21fb28e946a23a381f90f9bfef9c008d1060))
* update setup screen layout for better usability and readability ([7f690a2](https://github.com/Old-Gods/og_messenger/commit/7f690a2355de041b74b0629525b6908f4757d82d))
* update user name handling to skip broadcast during initial setup ([d881ec7](https://github.com/Old-Gods/og_messenger/commit/d881ec76db77c73c172e97dda45c62e1117ef775))
