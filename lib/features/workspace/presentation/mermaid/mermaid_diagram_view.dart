import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'mermaid_height_cache.dart';
import 'mermaid_html.dart';
import 'mermaid_html_cache.dart';
import 'mermaid_status_views.dart';

/// วิดเจ็ตสำหรับแสดงผลไดอะแกรม Mermaid ด้วย WebView พร้อมรองรับสถานะการโหลด ข้อผิดพลาด และ fallback
class MermaidDiagramView extends StatefulWidget {
  final String source;
  final MermaidHtmlCache? htmlCache;
  final MermaidHeightCache? heightCache;
  final bool? webViewSupported;

  const MermaidDiagramView({
    super.key,
    required this.source,
    this.htmlCache,
    this.heightCache,
    this.webViewSupported,
  });

  @override
  State<MermaidDiagramView> createState() => _MermaidDiagramViewState();
}

class _MermaidDiagramViewState extends State<MermaidDiagramView> {
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
  MermaidHeightCache get _heightCache =>
      widget.heightCache ?? defaultMermaidHeightCache;

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
      final cachedHeight = _heightCache.lookup(
        isDark: isDark,
        source: widget.source,
      );
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
    _diagramHeight =
        _heightCache.lookup(isDark: isDark, source: widget.source) ?? 120.0;
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
                final clampedHeight = clampMermaidHeight(height);
                _diagramHeight = clampedHeight;
                _errorMessage = null;
                _heightCache.store(
                  isDark: _lastIsDark ?? false,
                  source: widget.source,
                  height: clampedHeight,
                );

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
      return const MermaidDiagramEmptyView();
    }

    if (!_isSupported) {
      return MermaidDiagramFallbackView(source: widget.source);
    }

    if (_errorMessage != null) {
      return MermaidDiagramErrorView(
        message: _errorMessage!,
        source: widget.source,
      );
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
}
