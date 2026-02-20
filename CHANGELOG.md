# Changelog

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
