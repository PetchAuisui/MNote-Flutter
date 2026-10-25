import 'package:mnote/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../domain/chat_message.dart';
import 'assistant_chat_controller.dart';
import 'assistant_code_block_builder.dart';

Future<void> showAssistantChat(
  BuildContext context, {
  required AssistantChatController controller,
}) {
  final screenWidth = MediaQuery.sizeOf(context).width;

  if (screenWidth < 600) {
    return showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (dialogContext) => Dialog.fullscreen(
        key: const Key('assistant-chat-dialog'),
        child: SafeArea(
          child: AssistantChatPanel(
            controller: controller,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
  } else {
    final colorScheme = Theme.of(context).colorScheme;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.l10n.aiCloseLabel,
      barrierColor: colorScheme.scrim.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Padding(
          // side sheet ไม่หลบแป้นพิมพ์เองเหมือน Dialog ต้องดันขึ้นเอง
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(dialogContext).bottom,
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              key: const Key('assistant-side-sheet'),
              elevation: 1,
              color: colorScheme.surfaceContainerLow,
              child: SizedBox(
                width: 400,
                height: double.infinity,
                child: SafeArea(
                  child: AssistantChatPanel(
                    controller: controller,
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final slideTween = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));

        return SlideTransition(
          position: animation.drive(slideTween),
          child: child,
        );
      },
    );
  }
}

class AssistantChatPanel extends StatefulWidget {
  final AssistantChatController controller;
  final VoidCallback? onClose;

  const AssistantChatPanel({super.key, required this.controller, this.onClose});

  @override
  State<AssistantChatPanel> createState() => _AssistantChatPanelState();
}

class _AssistantChatPanelState extends State<AssistantChatPanel> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _previousMessageCount = 0;
  int _previousLastMessageLength = 0;

  List<String> get _suggestions => [
    context.l10n.aiSuggest1,
    context.l10n.aiSuggest2,
    context.l10n.aiSuggest3,
  ];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    widget.controller.addListener(_onControllerChanged);

    // controller อยู่ต่อหลังปิดแผง ถ้ามีบทสนทนาเดิมให้เริ่มที่ข้อความล่าสุด
    final messages = widget.controller.messages;
    _previousMessageCount = messages.length;
    _previousLastMessageLength = messages.isNotEmpty
        ? messages.last.text.length
        : 0;
    if (messages.isNotEmpty) _scrollToBottom();
  }

  @override
  void didUpdateWidget(covariant AssistantChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _onControllerChanged() {
    final messages = widget.controller.messages;
    final currentCount = messages.length;
    final currentLastLength = messages.isNotEmpty
        ? messages.last.text.length
        : 0;

    if (currentCount == _previousMessageCount &&
        currentLastLength == _previousLastMessageLength) {
      return;
    }
    // มีข้อความใหม่ (ผู้ใช้เพิ่งส่ง) เลื่อนลงเสมอ
    // ถ้าแค่ AI ตอบต่อ เลื่อนเฉพาะตอนที่ผู้ใช้อยู่ใกล้ท้ายรายการ
    final hasNewMessage = currentCount > _previousMessageCount;
    _previousMessageCount = currentCount;
    _previousLastMessageLength = currentLastLength;
    if (hasNewMessage || _isNearBottom()) _scrollToBottom();
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 80;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendMessage([String? textOverride]) async {
    final text = textOverride ?? _textController.text;
    if (text.trim().isEmpty || widget.controller.isResponding) return;

    final sending = widget.controller.send(text);
    // controller ตรวจความยาวและเริ่มตอบทันทีก่อน await แรก
    // ถ้าถูกปฏิเสธ isResponding จะเป็น false ข้อความจึงยังอยู่ให้แก้
    if (textOverride == null && widget.controller.isResponding) {
      _textController.clear();
    }

    final sent = await sending;
    // ส่งไม่สำเร็จ: คืนข้อความเข้าช่องพิมพ์ให้กดส่งซ้ำได้
    // ถ้าระหว่างรอผู้ใช้พิมพ์อะไรใหม่ไว้แล้ว ไม่เขียนทับ
    if (!sent && mounted && _textController.text.isEmpty) {
      _textController.text = text;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final messages = widget.controller.messages;
        final isResponding = widget.controller.isResponding;
        final errorMessage = widget.controller.errorMessage;
        final canSend = _textController.text.trim().isNotEmpty && !isResponding;
        final canClear = messages.isNotEmpty && !isResponding;

        return Material(
          key: const Key('assistant-chat-panel'),
          type: MaterialType.transparency,
          child: Column(
            children: [
              // 1. ส่วนหัว สูง 64
              SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.aiAssistant,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        key: const Key('assistant-clear'),
                        icon: const Icon(Icons.delete_sweep_outlined),
                        tooltip: context.l10n.aiClearChat,
                        onPressed: canClear ? widget.controller.clear : null,
                      ),
                      if (widget.onClose != null)
                        IconButton(
                          key: const Key('assistant-close'),
                          icon: const Icon(Icons.close),
                          tooltip: context.l10n.close,
                          onPressed: widget.onClose,
                        ),
                    ],
                  ),
                ),
              ),

              // 2. แถบความเป็นส่วนตัว
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  context.l10n.aiPrivacyNote,
                  key: const Key('assistant-privacy-note'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const Divider(height: 1),

              // 3. รายการข้อความ หรือ หน้าว่าง
              Expanded(
                child: messages.isEmpty
                    ? _buildEmptyState(theme, colorScheme)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isLast = index == messages.length - 1;
                          final isStreaming =
                              isLast &&
                              msg.role == ChatRole.assistant &&
                              isResponding;
                          final showTyping = isStreaming && msg.text.isEmpty;

                          return _MessageBubble(
                            message: msg,
                            showTypingIndicator: showTyping,
                            isStreaming: isStreaming,
                          );
                        },
                      ),
              ),

              // 4. แถบ error
              if (errorMessage != null)
                Container(
                  key: const Key('assistant-error'),
                  width: double.infinity,
                  color: colorScheme.errorContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    errorMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),

              const Divider(height: 1),

              // 5. ช่องพิมพ์ข้อความ
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('assistant-input'),
                        controller: _textController,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: AssistantChatController.maxInputLength,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: context.l10n.aiHint,
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) {
                          if (canSend) _sendMessage();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      key: const Key('assistant-send'),
                      icon: const Icon(Icons.arrow_upward_rounded),
                      tooltip: context.l10n.aiSend,
                      onPressed: canSend ? () => _sendMessage() : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      key: const Key('assistant-empty'),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Icon(Icons.auto_awesome, size: 40, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              context.l10n.aiStart,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(_suggestions.length, (index) {
                final suggestion = _suggestions[index];
                return ActionChip(
                  key: Key('assistant-suggestion-$index'),
                  label: Text(suggestion),
                  onPressed: () => _sendMessage(suggestion),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showTypingIndicator;
  final bool isStreaming;

  const _MessageBubble({
    required this.message,
    this.showTypingIndicator = false,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUser = message.role == ChatRole.user;

    final bubbleColor = isUser
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHigh;
    final textColor = isUser
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isUser ? 16 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 16),
    );

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          key: Key(isUser ? 'assistant-message-user' : 'assistant-message-ai'),
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.85),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: borderRadius,
          ),
          child: showTypingIndicator
              ? const _TypingIndicator()
              : isUser
              ? SelectableText(
                  message.text,
                  style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                )
              : MarkdownBody(
                  // MarkdownBody แปลงใหม่เฉพาะตอน data เปลี่ยน
                  // พอสตรีมจบ data เท่าเดิม จึงต้องเปลี่ยน key ให้สร้างใหม่
                  // การ์ด Mermaid จะได้เปลี่ยนจากโค้ดเป็นภาพ
                  key: ValueKey(isStreaming),
                  data: message.text,
                  selectable: true,
                  builders: {
                    'code': AssistantCodeBlockBuilder(isStreaming: isStreaming),
                  },
                  onTapLink: null,
                  imageBuilder: (uri, title, alt) => Text(alt ?? ''),
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                  ),
                ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      key: const Key('assistant-typing'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          context.l10n.aiThinking,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
