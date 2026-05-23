import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const H265RendererApp());
}

class H265RendererApp extends StatelessWidget {
  const H265RendererApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'H.265 Renderer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A84FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1A1A1E),
        cardColor: const Color(0xFF2C2C2E),
      ),
      home: const RendererScreen(),
    );
  }
}

/// Resolves the path to the ffmpeg binary.
/// If ffmpeg(.exe) sits next to the compiled app binary, use that.
/// Otherwise fall back to the system PATH so development works without copying.
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

class RendererScreen extends StatefulWidget {
  const RendererScreen({super.key});

  @override
  State<RendererScreen> createState() => _RendererScreenState();
}

class _RendererScreenState extends State<RendererScreen> {
  String? _inputPath;
  String? _outputPath;
  bool _isRendering = false;
  final List<String> _logLines = [];
  final ScrollController _scrollController = ScrollController();
  Process? _process;

  bool get _canRender =>
      _inputPath != null && _outputPath != null && !_isRendering;

  Future<void> _pickInputFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      dialogTitle: 'Select Input Video',
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _inputPath = result.files.single.path;
      });
    }
  }

  Future<void> _pickOutputLocation() async {
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
      setState(() {
        _outputPath = outPath;
      });
    }
  }

  void _appendLog(String line) {
    setState(() {
      _logLines.add(line);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startRender() async {
    if (!_canRender) return;

    setState(() {
      _isRendering = true;
      _logLines.clear();
    });

    final ffmpegPath = _resolveFfmpegPath();
    _appendLog('► Using FFmpeg binary: $ffmpegPath');
    _appendLog('► Input:  $_inputPath');
    _appendLog('► Output: $_outputPath');
    _appendLog('');

    final args = [
      '-y',
      '-i', _inputPath!,
      '-c:v', 'libx265',
      '-preset', 'veryfast',
      '-crf', '28',
      '-x265-params', 'crf=28',
      '-c:a', 'aac',
      '-b:a', '160k',
      '-ac', '2',
      '-threads', '0',
      '-f', 'mp4',
      _outputPath!,
    ];
  
    try {
      _process = await Process.start(ffmpegPath, args);

      // FFmpeg writes progress/info to stderr
      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _appendLog(line));

      // stdout is usually empty for FFmpeg but we listen anyway
      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _appendLog(line));

      final exitCode = await _process!.exitCode;

      setState(() => _isRendering = false);

      if (!mounted) return;

      if (exitCode == 0) {
        _appendLog('');
        _appendLog('✓ Render complete. Exit code: $exitCode');
        _showResultDialog(success: true);
      } else {
        _appendLog('');
        _appendLog('✗ Render failed. Exit code: $exitCode');
        _showResultDialog(success: false, exitCode: exitCode);
      }
    } on ProcessException catch (e) {
      setState(() => _isRendering = false);
      _appendLog('');
      _appendLog('✗ Failed to start FFmpeg: ${e.message}');
      _appendLog('  Make sure ffmpeg is installed and accessible.');
      if (!mounted) return;
      _showResultDialog(success: false, exitCode: -1, message: e.message);
    }
  }

  void _cancelRender() {
    _process?.kill(ProcessSignal.sigterm);
    setState(() => _isRendering = false);
    _appendLog('');
    _appendLog('⚠ Render cancelled by user.');
  }

  void _showResultDialog({
    required bool success,
    int exitCode = 0,
    String? message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: success ? const Color(0xFF30D158) : const Color(0xFFFF453A),
              size: 26,
            ),
            const SizedBox(width: 10),
            Text(
              success ? 'Render Complete' : 'Render Failed',
              style: TextStyle(
                color: success
                    ? const Color(0xFF30D158)
                    : const Color(0xFFFF453A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          success
              ? 'Your video has been successfully encoded and saved to:\n\n$_outputPath'
              : message != null
                  ? 'FFmpeg could not be started:\n\n$message'
                  : 'FFmpeg exited with code $exitCode.\nCheck the log window for details.',
          style: const TextStyle(color: Color(0xFFEBEBF5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Color(0xFF0A84FF))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 28),
            _buildPathSection(
              label: 'Input Video',
              icon: Icons.video_file_rounded,
              path: _inputPath,
              buttonLabel: 'Select Input Video',
              onPressed: _isRendering ? null : _pickInputFile,
            ),
            const SizedBox(height: 16),
            _buildPathSection(
              label: 'Output File',
              icon: Icons.save_rounded,
              path: _outputPath,
              buttonLabel: 'Choose Save Location',
              onPressed: _isRendering ? null : _pickOutputLocation,
            ),
            const SizedBox(height: 28),
            _buildRenderButton(),
            const SizedBox(height: 28),
            _buildLogPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'H.265 Renderer',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(0xFFEBEBF5),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'libx265 · CRF 28 · veryfast preset · AAC 160 k',
          style: TextStyle(
            fontSize: 13,
            color: const Color(0xFFEBEBF5).withValues(alpha: 0.45),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildPathSection({
    required String label,
    required IconData icon,
    required String? path,
    required String buttonLabel,
    required VoidCallback? onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0A84FF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFFEBEBF5).withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  path ?? 'Not selected',
                  style: TextStyle(
                    fontSize: 13,
                    color: path != null
                        ? const Color(0xFFEBEBF5)
                        : const Color(0xFFEBEBF5).withValues(alpha: 0.3),
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3A3A3C),
              foregroundColor: const Color(0xFF0A84FF),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(buttonLabel, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildRenderButton() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _canRender ? _startRender : null,
            icon: _isRendering
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 22),
            label: Text(
              _isRendering ? 'Rendering…' : 'Start Render',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _canRender
                  ? const Color(0xFF0A84FF)
                  : const Color(0xFF3A3A3C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (_isRendering) ...[
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _cancelRender,
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF453A),
              side: const BorderSide(color: Color(0xFFFF453A)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLogPanel() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal_rounded,
                  size: 16, color: Color(0xFF98989D)),
              const SizedBox(width: 6),
              Text(
                'FFmpeg Output',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEBEBF5).withValues(alpha: 0.5),
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              if (_logLines.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _logLines.clear()),
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF0A84FF).withValues(alpha: 0.8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3A3A3C)),
              ),
              child: _logLines.isEmpty
                  ? Center(
                      child: Text(
                        'FFmpeg output will appear here…',
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFFEBEBF5).withValues(alpha: 0.2),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _logLines.length,
                      itemBuilder: (context, index) {
                        final line = _logLines[index];
                        Color lineColor = const Color(0xFF9DB5B2);
                        if (line.startsWith('►') || line.startsWith('✓')) {
                          lineColor = const Color(0xFF30D158);
                        } else if (line.startsWith('✗') ||
                            line.toLowerCase().contains('error')) {
                          lineColor = const Color(0xFFFF453A);
                        } else if (line.startsWith('⚠')) {
                          lineColor = const Color(0xFFFFD60A);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 1),
                          child: Text(
                            line,
                            style: TextStyle(
                              fontSize: 12,
                              color: lineColor,
                              fontFamily: 'monospace',
                              height: 1.55,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
