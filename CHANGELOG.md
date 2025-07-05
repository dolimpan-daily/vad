## 0.0.6

* **BREAKING CHANGE:** Convert all VAD APIs to async Future-based methods for better async/await support
  - API: Convert `startListening()`, `stopListening()`, `pauseListening()`, and `dispose()` methods in `VadHandlerBase` to return `Future<void>`
  - Web: Update `VadHandlerWeb` implementation to use async method signatures
  - Non-Web: Update `VadHandlerNonWeb` implementation to use async method signatures and properly await internal async operations
  - Example: Update example app to use async/await pattern when calling VAD methods
* introduce `pauseListening` feature
  - API: Add `pauseListening()` to `VadHandlerBase`.
  - Web: implement `pauseListeningImpl()` in `vad_web.js` and expose via JS bindings.
  - Non-Web: add `_isPaused` flag in `VadHandlerNonWeb`; ignore incoming frames when paused; if `submitUserSpeechOnPause` is true, call `forceEndSpeech()`.
  - Start/Stop: reset `_isPaused` in `startListening()`; guard `vadInstance` in `stopListeningImpl()` with null-check and log.
* Add pause/resume UI functionality to example app
  - Example: Add dynamic pause button that appears only while actively listening
  - Example: Transform start button to "Resume" when paused, calling `startListening()` to resume
  - Example: Hide pause button when paused state is active
  - Example: Add separate stop button (red) available in both listening and paused states
  - Example: Implement proper state management for `isListening` and `isPaused` tracking
* Add support for custom `RecordConfig` parameter in `startListening()` for non-web platforms
  - API: Add optional `RecordConfig? recordConfig` parameter to `startListening()` in `VadHandlerBase`.
  - Non-Web: Use custom `RecordConfig` if provided, otherwise fall back to default configuration with 16kHz sample rate, PCM16 encoding, echo cancellation, auto gain, and noise suppression.
  - Web: Accept the parameter for compatibility but ignore it (not applicable for web platform).
* Bump `record` package to version 6.0.0
* Example: Bump `permission_handler` package to version 12.0.0+1
* Example: Bump `audioplayers` package to version 6.5.0

## 0.0.5

* Add support for Silero VAD v5 model. (Default model is set to v4)
* Automatically upsample audio to 16kHz if the input audio is not 16kHz (fixes model load failures due to lower sample rates).
* Expose `onRealSpeechStart` event to notify when the number of speech positive frames exceeds the minimum speech frames (i.e. not a misfire event).
* Expose `onFrameProcessed` event to track VAD decisions by exposing speech probabilities and frame data for real-time processing.
* Update example app to show the `onRealSpeechStart` callback in action and introduce VAD Settings dialog to change the VAD model and other settings at runtime.
* For web platform, bundle the required files within the package to avoid download failures when fetching from CDNs and to ensure offline support.
* Update example app to log `onFrameProcessed` details for debugging.

## 0.0.4

* Fixed a bug where default `modelPath` was not picked up, resulting in silent failure if `modelPath` was not provided.
* Export `VadIterator` class for manual control over the VAD process for non-streaming use cases. Only available on iOS/Android.
* Added comments for all public methods and classes.

## 0.0.3

* Switch to `onnxruntime` package for inference on a separate isolate on iOS and Android to avoid using a full browser in the background, overall reducing the app size and improving performance.
* Example app will show audio track slider with controls while speech segment is being played and it will reflect a misfire event on the UI if occurred.

## 0.0.2

* Fix broken LICENSE hyperlink in README.md and add topics to pubspec.yaml

## 0.0.1

* Initial release
