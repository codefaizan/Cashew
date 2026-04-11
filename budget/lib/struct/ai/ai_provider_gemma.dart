import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:budget/struct/ai/ai_provider.dart';
import 'package:budget/struct/settings.dart';

const String _kModelUrl =
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';
const String _kModelFilename = 'gemma-4-E2B-it.litertlm';
const int _kMinAndroidApiLevel = 24;
const int _kMinTotalMemoryBytes = 4 * 1024 * 1024 * 1024;

class GemmaProvider implements AiProvider {
  static bool _gemmaInitialized = false;

  static Future<void> _ensureGemmaInitialized() async {
    if (_gemmaInitialized) return;
    await FlutterGemma.initialize();
    _gemmaInitialized = true;
  }

  InferenceModel? _model;
  InferenceChat? _chat;
  bool _initialized = false;
  CancelToken? _downloadCancelToken;

  @override
  String get name => 'Gemma 4 E2B';

  @override
  bool get isAvailable => _initialized && _model != null;

  static bool hasActiveModel() {
    return FlutterGemma.hasActiveModel();
  }

  static Future<bool> isModelDownloaded() async {
    await _ensureGemmaInitialized();
    return await FlutterGemma.isModelInstalled(_kModelFilename);
  }

  Future<void> downloadModel({
    required void Function(double progress) onProgress,
  }) async {
    await _ensureGemmaInitialized();
    _downloadCancelToken = CancelToken();

    try {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.task,
      )
          .fromNetwork(_kModelUrl)
          .withProgress((progress) {
            onProgress(progress / 100.0);
          })
          .withCancelToken(_downloadCancelToken!)
          .install();

      appStateSettings["aiModelDownloaded"] = true;
      appStateSettings["aiModelPath"] = _kModelFilename;
    } catch (e) {
      if (CancelToken.isCancel(e)) {
        rethrow;
      }
      appStateSettings["aiModelDownloaded"] = false;
      rethrow;
    } finally {
      _downloadCancelToken = null;
    }
  }

  void cancelDownload() {
    _downloadCancelToken?.cancel('User cancelled download');
    _downloadCancelToken = null;
  }

  Future<bool> deleteModel() async {
    try {
      await _ensureGemmaInitialized();
      await FlutterGemma.uninstallModel(_kModelFilename);
      _model = null;
      _chat = null;
      _initialized = false;
      appStateSettings["aiModelDownloaded"] = false;
      appStateSettings["aiModelPath"] = "";
      return true;
    } catch (e) {
      debugPrint('GemmaProvider: Error deleting model: $e');
      return false;
    }
  }

  @override
  Future<bool> initialize() async {
    if (_initialized && _model != null) return true;

    try {
      await _ensureGemmaInitialized();
      final downloaded = await isModelDownloaded();
      if (!downloaded) return false;

      _model = await FlutterGemma.getActiveModel(
        maxTokens: 2048,
        preferredBackend: PreferredBackend.gpu,
      );

      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('GemmaProvider: GPU init failed, trying CPU: $e');
      try {
        _model = await FlutterGemma.getActiveModel(
          maxTokens: 2048,
          preferredBackend: PreferredBackend.cpu,
        );
        _initialized = true;
        return true;
      } catch (e2) {
        debugPrint('GemmaProvider: CPU init also failed: $e2');
        _initialized = false;
        return false;
      }
    }
  }

  @override
  Future<String> generateChatResponse({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  }) async {
    if (!_initialized || _model == null) {
      throw StateError(
          'GemmaProvider not initialized. Call initialize() first.');
    }

    try {
      _chat = await _model!.createChat(
        temperature: 0.1,
        randomSeed: 1,
        topK: 1,
        systemInstruction: systemPrompt,
      );

      for (final msg in history) {
        await _chat!.addQueryChunk(
          Message.text(text: msg.content, isUser: msg.role == 'user'),
        );
      }

      await _chat!.addQueryChunk(Message.text(text: userMessage, isUser: true));

      final response = await _chat!.generateChatResponse();

      if (response is TextResponse) {
        return response.token;
      }

      return response.toString();
    } catch (e) {
      debugPrint('GemmaProvider: Error generating response: $e');
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _chat?.close();
    } catch (_) {}
    try {
      await _model?.close();
    } catch (_) {}
    _chat = null;
    _model = null;
    _initialized = false;
  }

  @visibleForTesting
  static bool meetsAndroidRequirements({
    required int sdkInt,
    required int totalMemoryBytes,
  }) {
    return sdkInt >= _kMinAndroidApiLevel &&
        totalMemoryBytes >= _kMinTotalMemoryBytes;
  }

  static Future<int?> _getAndroidTotalMemoryBytes() async {
    try {
      final memInfo = await File('/proc/meminfo').readAsString();
      final match = RegExp(r'^MemTotal:\s+(\d+)\s+kB', multiLine: true)
          .firstMatch(memInfo);
      if (match == null) return null;
      final totalKb = int.tryParse(match.group(1) ?? '');
      if (totalKb == null) return null;
      return totalKb * 1024;
    } catch (e) {
      debugPrint('GemmaProvider: Failed to read total memory: $e');
      return null;
    }
  }

  static Future<bool> isDeviceCompatible() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) return true;
    if (!Platform.isAndroid) return false;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final int sdkInt = androidInfo.version.sdkInt;
      if (sdkInt < _kMinAndroidApiLevel) return false;

      final totalMemoryBytes = await _getAndroidTotalMemoryBytes();
      if (totalMemoryBytes != null) {
        return meetsAndroidRequirements(
          sdkInt: sdkInt,
          totalMemoryBytes: totalMemoryBytes,
        );
      }

      // If memory query unavailable, reject known low-RAM devices.
      return !androidInfo.isLowRamDevice;
    } catch (e) {
      debugPrint('GemmaProvider: Device compatibility check failed: $e');
      return false;
    }
  }
}
