import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

sealed class RendererState {
  final String? inputPath;
  final String? outputPath;
  final List<String> logLines;

  const RendererState({
    this.inputPath,
    this.outputPath,
    this.logLines = const [],
  });
}

class RendererInitial extends RendererState {
  const RendererInitial({
    super.inputPath,
    super.outputPath,
    super.logLines,
  });
}

class RendererLoading extends RendererState {
  const RendererLoading({
    super.inputPath,
    super.outputPath,
    super.logLines,
  });
}

class RendererSuccess extends RendererState {
  final int exitCode;
  
  const RendererSuccess({
    super.inputPath,
    super.outputPath,
    super.logLines,
    required this.exitCode,
  });
}

class RendererError extends RendererState {
  final int exitCode;
  final String? errorMessage;
  
  const RendererError({
    super.inputPath,
    super.outputPath,
    super.logLines,
    required this.exitCode,
    this.errorMessage,
  });
}

class RendererViewModel extends ValueNotifier<RendererState> {
  Process? _process;

  RendererViewModel() : super(const RendererInitial());

  bool get canRender =>
      value.inputPath != null && value.outputPath != null && value is! RendererLoading;

  Future<void> pickInputFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      dialogTitle: 'Select Input Video',
    );
    if (result != null && result.files.single.path != null) {
      _updateState(RendererInitial(
        inputPath: result.files.single.path,
        outputPath: value.outputPath,
        logLines: value.logLines,
      ));
    }
  }

  Future<void> pickOutputLocation() async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Choose Save Location',
      fileName: 'output.mp4',
      allowedExtensions: ['mp4'],
      type: FileType.custom,
    );
    if (result != null) {
      String outPath = result;
      if (!outPath.toLowerCase().endsWith('.mp4')) {
        outPath = '$outPath.mp4';
      }
      _updateState(RendererInitial(
        inputPath: value.inputPath,
        outputPath: outPath,
        logLines: value.logLines,
      ));
    }
  }

  void _appendLog(String line) {
    _updateState(RendererLoading(
      inputPath: value.inputPath,
      outputPath: value.outputPath,
      logLines: List.of(value.logLines)..add(line),
    ));
  }

  void _updateState(RendererState newState) {
    value = newState;
  }

  String _resolveFfmpegPath() {
    final String binaryName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    final String executableDir = p.dirname(Platform.resolvedExecutable);
    final String localPath = p.join(executableDir, binaryName);

    if (File(localPath).existsSync()) {
      debugPrint('Found ffmpeg at: $localPath');
      return localPath;
    }
    debugPrint('FFmpeg not found at: $localPath');
    return binaryName;
  }

  Future<void> startRender() async {
    if (!canRender) return;

    _updateState(RendererLoading(
      inputPath: value.inputPath,
      outputPath: value.outputPath,
      logLines: const [],
    ));

    final ffmpegPath = _resolveFfmpegPath();
    _appendLog('► Using FFmpeg binary: $ffmpegPath');
    _appendLog('► Input:  ${value.inputPath}');
    _appendLog('► Output: ${value.outputPath}');
    _appendLog('');

    final args = [
      '-y',
      '-i', value.inputPath!,
      '-c:v', 'libx265',
      '-preset', 'veryfast',
      '-crf', '28',
      '-x265-params', 'crf=28',
      '-c:a', 'aac',
      '-b:a', '160k',
      '-ac', '2',
      '-threads', '0',
      '-f', 'mp4',
      value.outputPath!,
    ];
  
    try {
      _process = await Process.start(ffmpegPath, args);

      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _appendLog(line));

      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _appendLog(line));

      final exitCode = await _process!.exitCode;

      if (exitCode == 0) {
        _appendLog('');
        _appendLog('✓ Render complete. Exit code: $exitCode');
        _updateState(RendererSuccess(
          inputPath: value.inputPath,
          outputPath: value.outputPath,
          logLines: value.logLines,
          exitCode: exitCode,
        ));
      } else {
        _appendLog('');
        _appendLog('✗ Render failed. Exit code: $exitCode');
        _updateState(RendererError(
          inputPath: value.inputPath,
          outputPath: value.outputPath,
          logLines: value.logLines,
          exitCode: exitCode,
        ));
      }
    } on ProcessException catch (e) {
      _appendLog('');
      _appendLog('✗ Failed to start FFmpeg: ${e.message}');
      _appendLog('  Make sure ffmpeg is installed and accessible.');
      _updateState(RendererError(
        inputPath: value.inputPath,
        outputPath: value.outputPath,
        logLines: value.logLines,
        exitCode: -1,
        errorMessage: e.message,
      ));
    }
  }

  void cancelRender() {
    _process?.kill(ProcessSignal.sigterm);
    _appendLog('');
    _appendLog('⚠ Render cancelled by user.');
    _updateState(RendererInitial(
      inputPath: value.inputPath,
      outputPath: value.outputPath,
      logLines: value.logLines,
    ));
  }

  void resetState() {
    _updateState(RendererInitial(
      inputPath: value.inputPath,
      outputPath: value.outputPath,
      logLines: value.logLines,
    ));
  }
}
