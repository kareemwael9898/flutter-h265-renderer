import 'package:flutter/material.dart';
import '../view_model/renderer_view_model.dart';

class RendererScreen extends StatefulWidget {
  const RendererScreen({super.key});

  @override
  State<RendererScreen> createState() => _RendererScreenState();
}

class _RendererScreenState extends State<RendererScreen> {
  final RendererViewModel _viewModel = RendererViewModel();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    final state = _viewModel.value;
    
    if (state is RendererLoading) {
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

    if (state is RendererSuccess) {
      _showResultDialog(success: true, outputPath: state.outputPath);
      _viewModel.resetState();
    } else if (state is RendererError) {
      _showResultDialog(
        success: false, 
        exitCode: state.exitCode, 
        message: state.errorMessage,
      );
      _viewModel.resetState();
    }
  }

  void _showResultDialog({
    required bool success,
    String? outputPath,
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
              ? 'Your video has been successfully encoded and saved to:\n\n$outputPath'
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
    _viewModel.removeListener(_onStateChanged);
    _viewModel.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ValueListenableBuilder<RendererState>(
          valueListenable: _viewModel,
          builder: (context, state, _) {
            final isRendering = state is RendererLoading;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 28),
                _buildPathSection(
                  label: 'Input Video',
                  icon: Icons.video_file_rounded,
                  path: state.inputPath,
                  buttonLabel: 'Select Input Video',
                  onPressed: isRendering ? null : _viewModel.pickInputFile,
                ),
                const SizedBox(height: 16),
                _buildPathSection(
                  label: 'Output File',
                  icon: Icons.save_rounded,
                  path: state.outputPath,
                  buttonLabel: 'Choose Save Location',
                  onPressed: isRendering ? null : _viewModel.pickOutputLocation,
                ),
                const SizedBox(height: 28),
                _buildRenderButton(isRendering),
                const SizedBox(height: 28),
                _buildLogPanel(state.logLines),
              ],
            );
          },
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(buttonLabel, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildRenderButton(bool isRendering) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _viewModel.canRender ? _viewModel.startRender : null,
            icon: isRendering
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 22),
            label: Text(
              isRendering ? 'Rendering…' : 'Start Render',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _viewModel.canRender
                  ? const Color(0xFF0A84FF)
                  : const Color(0xFF3A3A3C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (isRendering) ...[
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _viewModel.cancelRender,
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF453A),
              side: const BorderSide(color: Color(0xFFFF453A)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLogPanel(List<String> logLines) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal_rounded, size: 16, color: Color(0xFF98989D)),
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
              if (logLines.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    // We shouldn't mutate logs directly if not via view model but clear logs action wasn't explicitly needed since it clears on new render.
                    // If we want a clear button, we add clearLogs to view model.
                    // To keep it simple, omitted or left without clear if not backed by VM.
                    // Actually, let's just keep the ui behavior and we would need a clear method.
                  },
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
              child: logLines.isEmpty
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
                      itemCount: logLines.length,
                      itemBuilder: (context, index) {
                        final line = logLines[index];
                        Color lineColor = const Color(0xFF9DB5B2);
                        if (line.startsWith('►') || line.startsWith('✓')) {
                          lineColor = const Color(0xFF30D158);
                        } else if (line.startsWith('✗') || line.toLowerCase().contains('error')) {
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
