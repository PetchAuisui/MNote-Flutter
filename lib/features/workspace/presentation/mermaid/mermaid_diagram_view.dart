import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'mermaid_html.dart';
import 'mermaid_html_cache.dart';

/// วิดเจ็ตสำหรับแสดงผลไดอะแกรม Mermaid ด้วย WebView พร้อมรองรับสถานะการโหลด ข้อผิดพลาด และ fallback
class MermaidDiagramView extends StatefulWidget {
  final String source;
  final MermaidHtmlCache? htmlCache;
  final bool? webViewSupported;

  const MermaidDiagramView({
    super.key,
    required this.source,
    this.htmlCache,
    this.webViewSupported,
  });

  @override
  State<MermaidDiagramView> createState() => _MermaidDiagramViewState();
}

class _MermaidDiagramViewState extends State<MermaidDiagramView> {
  static final Map<String, double> _heightCache = {};
  static const int _heightCacheLimit = 100;

  WebViewController? _controller;
  bool _isPageFinished = false;
  bool _isLoading = true;
  String? _errorMessage;
  double _diagramHeight = 120.0;
  bool? _lastIsDark;
  Timer? _timeoutTimer;
  int _generation = 0;

  bool get _isSupported =>
      widget.webViewSupported ?? (WebViewPlatform.instance != null);

  MermaidHtmlCache get _cache => widget.htmlCache ?? defaultMermaidHtmlCache;

  String _heightKey(bool isDark) =>
      '${isDark ? 'dark' : 'light'}:${widget.source}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWithWidget();
  }

  @override
  void didUpdateWidget(covariant MermaidDiagramView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWithWidget(previousSource: oldWidget.source);
  }

  void _syncWithWidget({String? previousSource}) {
    if (!_isSupported || widget.source.trim().isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_controller == null || _lastIsDark != isDark) {
      _lastIsDark = isDark;
      _initAndLoadHtml(isDark);
      return;
    }

    if (previousSource != null &&
        previousSource != widget.source &&
        _isPageFinished) {
      final cachedHeight = _heightCache[_heightKey(isDark)];
      if (cachedHeight != null) {
        _diagramHeight = cachedHeight;
      }
      _startTimeoutTimer();
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      unawaited(_renderDiagram());
    }
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'หมดเวลาในการแสดงไดอะแกรม';
        });
      }
    });
  }

  Future<void> _initAndLoadHtml(bool isDark) async {
    final gen = ++_generation;
    _diagramHeight = _heightCache[_heightKey(isDark)] ?? 120.0;
    _startTimeoutTimer();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isPageFinished = false;
    });

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..enableZoom(false)
      ..addJavaScriptChannel(
        mermaidChannelName,
        onMessageReceived: (message) {
          if (gen != _generation) return;
          final parsed = parseMermaidBridgeMessage(message.message);
          if (parsed == null) return;

          _timeoutTimer?.cancel();
          if (!mounted) return;

          setState(() {
            _isLoading = false;
            switch (parsed) {
              case MermaidRendered(:final height):
                final clampedHeight = height.clamp(48.0, 2000.0);
                _diagramHeight = clampedHeight;
                _errorMessage = null;

                final currentKey = _heightKey(_lastIsDark ?? false);
                if (!_heightCache.containsKey(currentKey) &&
                    _heightCache.length >= _heightCacheLimit) {
                  _heightCache.remove(_heightCache.keys.first);
                }
                _heightCache[currentKey] = clampedHeight;

              case MermaidRenderFailed(:final message):
                _errorMessage = message;
            }
          });
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url == 'about:blank') {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            if (gen != _generation) return;
            _isPageFinished = true;
            unawaited(_renderDiagram());
          },
        ),
      );

    _controller = controller;

    try {
      final html = await _cache.htmlFor(isDark: isDark);
      if (gen != _generation || !mounted) return;
      await controller.loadHtmlString(html);
    } catch (e) {
      if (gen != _generation) return;
      _timeoutTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _renderDiagram() async {
    final js = buildMermaidRenderCall(widget.source);
    try {
      await _controller?.runJavaScript(js);
    } catch (e) {
      _timeoutTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.source.trim().isEmpty) {
      return _buildEmptyState(context);
    }

    if (!_isSupported) {
      return _buildFallbackState(context);
    }

    if (_errorMessage != null) {
      return _buildErrorState(context);
    }

    return SizedBox(
      height: _diagramHeight,
      child: Stack(
        children: [
          if (_controller != null)
            WebViewWidget(
              key: const Key('mermaid-diagram-webview'),
              controller: _controller!,
            ),
          if (_isLoading)
            Container(
              key: const Key('mermaid-diagram-loading'),
              color: Colors.transparent,
              height: 120.0,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      key: const Key('mermaid-diagram-empty'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'ไดอะแกรมว่าง',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }

  Widget _buildFallbackState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('mermaid-diagram-fallback'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            widget.source,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          Text(
            'แพลตฟอร์มนี้ยังไม่รองรับการแสดงไดอะแกรม',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('mermaid-diagram-error'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'แสดงไดอะแกรมไม่ได้',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              _errorMessage!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
          const Divider(height: 16),
          SelectableText(
            widget.source,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
