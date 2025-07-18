// vad_handler_non_web.dart

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:record/record.dart';
import 'package:vad/vad.dart';

import 'vad_iterator_base.dart';

/// VadHandlerNonWeb class
class VadHandlerNonWeb implements VadHandlerBase {
  final AudioRecorder _audioRecorder = AudioRecorder();
  late VadIteratorBase _vadIterator;
  StreamSubscription<List<int>>? _audioStreamSubscription;

  /// Path to the model file
  String modelPath;

  /// Debug flag
  bool isDebug = false;

  Completer<void>? _initializeCompleter;

  bool _submitUserSpeechOnPause = false;

  /// Flag to indicate if audio processing is paused
  bool _isPaused = false;

  /// Sample rate
  static const int sampleRate = 16000;

  /// Default Silero VAD Legacy (v4) model path (used for non-web)
  static const String vadLegacyModelPath =
      'packages/vad/assets/silero_vad_legacy.onnx';

  /// Default Silero VAD V5 model path (used for non-web)
  static const String vadV5ModelPath = 'packages/vad/assets/silero_vad_v5.onnx';

  final _onSpeechEndController = StreamController<List<double>>.broadcast();
  final _onFrameProcessedController = StreamController<
      ({double isSpeech, double notSpeech, List<double> frame})>.broadcast();
  final _onSpeechStartController = StreamController<void>.broadcast();
  final _onRealSpeechStartController = StreamController<void>.broadcast();
  final _onVADMisfireController = StreamController<void>.broadcast();
  final _onErrorController = StreamController<String>.broadcast();

  @override
  Stream<List<double>> get onSpeechEnd => _onSpeechEndController.stream;

  @override
  Stream<({double isSpeech, double notSpeech, List<double> frame})>
      get onFrameProcessed => _onFrameProcessedController.stream;

  @override
  Stream<void> get onSpeechStart => _onSpeechStartController.stream;

  @override
  Stream<void> get onRealSpeechStart => _onRealSpeechStartController.stream;

  @override
  Stream<void> get onVADMisfire => _onVADMisfireController.stream;

  @override
  Stream<String> get onError => _onErrorController.stream;

  /// Constructor
  VadHandlerNonWeb({required this.isDebug, this.modelPath = ''});

  /// Handle VAD event
  void _handleVadEvent(VadEvent event) {
    if (isDebug) {
      debugPrint(
          'VadHandlerNonWeb: VAD Event: ${event.type} with message ${event.message}');
    }
    switch (event.type) {
      case VadEventType.start:
        _onSpeechStartController.add(null);
        break;
      case VadEventType.realStart:
        _onRealSpeechStartController.add(null);
        break;
      case VadEventType.end:
        if (event.audioData != null) {
          final int16List = event.audioData!.buffer.asInt16List();
          final floatSamples = int16List.map((e) => e / 32768.0).toList();
          _onSpeechEndController.add(floatSamples);
        }
        break;
      case VadEventType.frameProcessed:
        if (event.probabilities != null && event.frameData != null) {
          _onFrameProcessedController.add((
            isSpeech: event.probabilities!.isSpeech,
            notSpeech: event.probabilities!.notSpeech,
            frame: event.frameData!
          ));
        }
        break;
      case VadEventType.misfire:
        _onVADMisfireController.add(null);
        break;
      case VadEventType.error:
        _onErrorController.add(event.message);
        break;
    }
  }

  @override
  Future<void> init({
    double positiveSpeechThreshold = 0.5,
    double negativeSpeechThreshold = 0.35,
    int preSpeechPadFrames = 1,
    int redemptionFrames = 8,
    int frameSamples = 1536,
    int minSpeechFrames = 3,
    bool submitUserSpeechOnPause = false,
    String model = 'legacy',
    String baseAssetPath = 'assets/packages/vad/assets/',
    String onnxWASMBasePath = 'assets/packages/vad/assets/',
  }) async {
    if (_initializeCompleter != null) {
      return;
    }
    _initializeCompleter = Completer();
    _vadIterator = VadIterator.create(
      isDebug: isDebug,
      sampleRate: sampleRate,
      frameSamples: frameSamples,
      positiveSpeechThreshold: positiveSpeechThreshold,
      negativeSpeechThreshold: negativeSpeechThreshold,
      redemptionFrames: redemptionFrames,
      preSpeechPadFrames: preSpeechPadFrames,
      minSpeechFrames: minSpeechFrames,
      submitUserSpeechOnPause: submitUserSpeechOnPause,
      model: model,
    );
    if (modelPath.isEmpty) {
      if (model == 'v5') {
        modelPath = vadV5ModelPath;
      } else {
        modelPath = vadLegacyModelPath;
      }
    }
    await _vadIterator.initModel(modelPath);
    _vadIterator.setVadEventCallback(_handleVadEvent);
    _submitUserSpeechOnPause = submitUserSpeechOnPause;
    _initializeCompleter!.complete();
  }

  @override
  Future<void> startListening({
    RecordConfig? recordConfig,
  }) async {
    await _initializeCompleter?.future;

    // Reset pause state when starting listening
    _isPaused = false;

    // Start recording with a stream
    final config = recordConfig ??
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          bitRate: 16,
          numChannels: 1,
          echoCancel: false,
          autoGain: false,
          noiseSuppress: false,
          iosConfig: IosRecordConfig(manageAudioSession: false),
        );
    final stream = await _audioRecorder.startStream(config);

    _audioStreamSubscription = stream.listen((data) async {
      // Only process audio data if not paused
      if (!_isPaused) {
        await _vadIterator.processAudioData(data);
      }
      // When paused, incoming data is received but ignored
    });
  }

  @override
  Future<void> stopListening() async {
    if (isDebug) debugPrint('stopListening');
    try {
      // Before stopping the audio stream, handle forced speech end if needed
      if (_submitUserSpeechOnPause) {
        _vadIterator.forceEndSpeech();
      }

      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      await _audioRecorder.cancel();
      _vadIterator.reset();
      _isPaused = false;
    } catch (e) {
      _onErrorController.add(e.toString());
      if (isDebug) debugPrint('Error stopping audio stream: $e');
    }
  }

  @override
  Future<void> pauseListening() async {
    if (isDebug) debugPrint('pauseListening');
    // Set paused flag to true to ignore incoming audio data
    _isPaused = true;

    // If submitUserSpeechOnPause is enabled, force end speech on pause
    if (_submitUserSpeechOnPause) {
      _vadIterator.forceEndSpeech();
    }
  }

  @override
  Future<void> dispose() async {
    if (isDebug) debugPrint('VadHandlerNonWeb: dispose');
    await _initializeCompleter?.future;
    await stopListening();
    await _audioRecorder.dispose();
    _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    _vadIterator.release();
    await _onSpeechEndController.close();
    await _onFrameProcessedController.close();
    await _onSpeechStartController.close();
    await _onRealSpeechStartController.close();
    await _onVADMisfireController.close();
    await _onErrorController.close();
    await _audioRecorder.dispose();
  }
}

/// Create a VAD handler for the non-web platforms
VadHandlerBase createVadHandler({required isDebug, modelPath}) =>
    VadHandlerNonWeb(isDebug: isDebug, modelPath: modelPath);
