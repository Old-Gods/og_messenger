# Changelog

## [1.5.0](https://github.com/Old-Gods/og_messenger/compare/v1.4.0...v1.5.0) (2026-02-20)


### Features

* **assets:** update app icons for all platforms with light/dark theme support ([1c013b8](https://github.com/Old-Gods/og_messenger/commit/1c013b8219a14fac0ac1690a67058b02c947027c))
* **assets:** update app icons for light/dark theme support across platforms ([407bfd2](https://github.com/Old-Gods/og_messenger/commit/407bfd2c0e0d02d2ec2e58c91b60331fff546cce))
* **security:** enhance password management with detailed logging and new password proposal handling ([6da2700](https://github.com/Old-Gods/og_messenger/commit/6da270047e32098959c5e2e7c9c0c538467f55ee))
* **security:** enhance password proposal handling with detailed logging and automatic voting ([fc9a400](https://github.com/Old-Gods/og_messenger/commit/fc9a4003f0b41ef0ad16d3cec6372adba9f4c434))
* **security:** implement password change proposals and voting mechanism ([373eeef](https://github.com/Old-Gods/og_messenger/commit/373eeef6b8c53b39735ca22665850ac06894311c))
* **setup:** update app icons and add asset references for light and dark themes ([4d2213e](https://github.com/Old-Gods/og_messenger/commit/4d2213e10d0619c5ffb30dabf6f2ed5582cfc8a9))


### Bug Fixes

* **chat:** update color opacity handling in message bubble decoration ([bffe210](https://github.com/Old-Gods/og_messenger/commit/bffe2102fac5d7b5ecb505665a042d567b94cec8))
* **security:** implement listen-only mode for UDP discovery during setup ([36ce974](https://github.com/Old-Gods/og_messenger/commit/36ce97479e9ca4f638efd756ce5b045c09cb77b9))
* **settings:** add method to mark first launch as complete and initialize settings service ([d2faa03](https://github.com/Old-Gods/og_messenger/commit/d2faa036b7c6642ffa71e7b427fe21ebdf8aac85))
* **setup:** improve layout and responsiveness of setup screen ([4961213](https://github.com/Old-Gods/og_messenger/commit/4961213403375b0d3e689f7935d65794eedf2b16))
* **setup:** signing in with a phone ([017b031](https://github.com/Old-Gods/og_messenger/commit/017b031913f8ea0dbf62b3dc16164668d4b48a1a))

## [1.4.0](https://github.com/Old-Gods/og_messenger/compare/v1.3.0...v1.4.0) (2026-02-20)


### Features

* add adaptive launcher icons and update app icon configurations for multiple platforms ([962508a](https://github.com/Old-Gods/og_messenger/commit/962508a8a73a8d27f9d87be89f31d20f76ba3e68))
* add devtools options file and update peer timeout duration ([2189643](https://github.com/Old-Gods/og_messenger/commit/2189643280db2f9210b21a21f37580263ce79d74))
* integrate device_info_plus for hardware-based device ID management ([d880c57](https://github.com/Old-Gods/og_messenger/commit/d880c574b735db4cb9ff1e9d5284c7f37990531a))


### Bug Fixes

* add flutter_local_notifications_windows to FFI plugin list ([9b4a5e0](https://github.com/Old-Gods/og_messenger/commit/9b4a5e07d24d570bb04dd56854ddc593095b403e))
* update notification plugin method calls to use named parameters ([601c7fa](https://github.com/Old-Gods/og_messenger/commit/601c7faaa129dab06b890e029cc03ae5200c3af4))

## [1.3.0](https://github.com/Old-Gods/og_messenger/compare/v1.2.0...v1.3.0) (2026-02-19)


### Features

* add notification for incoming messages ([42af111](https://github.com/Old-Gods/og_messenger/commit/42af11128a4f184b605e34781e83f27675cb964d))
* enhance notification handling and app lifecycle management ([daa1fb3](https://github.com/Old-Gods/og_messenger/commit/daa1fb328a1268c2f3d33a350c5d4945cbd68ca1))
* implement auto-scrolling for new messages and after sending ([56ed176](https://github.com/Old-Gods/og_messenger/commit/56ed176e44751b2d5d183882ab12845032b85293))
* integrate package_info_plus for version display and message retention settings ([08b2103](https://github.com/Old-Gods/og_messenger/commit/08b210311d1fb4c8af87a825ca02dc786b014964))

## [1.2.0](https://github.com/Old-Gods/og_messenger/compare/v1.1.0...v1.2.0) (2026-02-19)


### Features

* add iOS build job to GitHub Actions workflow ([4bcb204](https://github.com/Old-Gods/og_messenger/commit/4bcb204302b84bf71c9b63f5e2db5bd6d08ee600))


### Bug Fixes

* prevent multiple initializations and improve user name broadcast logic ([42eaa73](https://github.com/Old-Gods/og_messenger/commit/42eaa735e7c98aa900d4d8e17d78a0a748a0b6fd))
* update iOS and macOS build output format from .app to .zip ([38fd130](https://github.com/Old-Gods/og_messenger/commit/38fd1300a2ebcf218129c259685bae8f06e3dd04))
* update user name handling to skip broadcast during initial setup ([d881ec7](https://github.com/Old-Gods/og_messenger/commit/d881ec76db77c73c172e97dda45c62e1117ef775))

## [1.1.0](https://github.com/Old-Gods/og_messenger/compare/v1.0.0...v1.1.0) (2026-02-19)


### Features

* add initial Windows runner and Flutter integration ([9b9bd5b](https://github.com/Old-Gods/og_messenger/commit/9b9bd5b33adf950b24e815211ef6f3e57450c87e))
* add sync request handling and peer synchronization in messaging service ([44ad5f6](https://github.com/Old-Gods/og_messenger/commit/44ad5f6c46f19a178d5abdd02f7ca1b5145e65be))
* Implement messaging feature with TCP server and local storage ([4a94e42](https://github.com/Old-Gods/og_messenger/commit/4a94e420c8d4f11c5e4008b3c0de86a5c123f21e))
* implement name change handling and broadcasting across peers ([5203527](https://github.com/Old-Gods/og_messenger/commit/52035279249629896db61c231d7e2603f01145f7))
