import '../../voice_doubt/services/voice_doubt_service.dart';
import '../../voice_doubt/widgets/voice_doubt_sheet.dart';
import '../../voice_doubt/widgets/ai_audio_player_bar.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../../core/reuse/reuse.dart';
import '../controllers/ai_tutor_controller.dart';
import 'package:intl/intl.dart';
import '../models/chat_message_model.dart';
import '../models/chat_session_model.dart';
import '../widgets/formatted_ai_text.dart';
import '../../student_memory/widgets/student_memory_sheet.dart';

class AiTutorChatScreen extends StatefulWidget {
  final String? initialQuery;
  final String? noteTitle;
  final String? noteContext;

  const AiTutorChatScreen({
    super.key,
    this.initialQuery,
    this.noteTitle,
    this.noteContext,
  });

  @override
  State<AiTutorChatScreen> createState() => _AiTutorChatScreenState();
}

class _AiTutorChatScreenState extends State<AiTutorChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _showScrollToLatest = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScrollPosition);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<AiTutorController>();
      if (widget.noteTitle != null && widget.noteContext != null) {
        controller.setNoteContext(widget.noteTitle!, widget.noteContext!);
      }
      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        controller.sendQuestion(widget.initialQuery!);
      }
    });
  }

  @override
  void dispose() {
    VoiceDoubtService().stopListening();
    _scrollController.removeListener(_handleScrollPosition);
    _textController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _handleScrollPosition() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final shouldShow = position.maxScrollExtent - position.pixels > 180;
    if (shouldShow != _showScrollToLatest && mounted) {
      setState(() => _showScrollToLatest = shouldShow);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        if (mounted) {
          context.read<AiTutorController>().setImageAttachment(file.path, base64String);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, 'Could not access image: $e');
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Attach Math Problem / Question',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: AppColors.primary),
                ),
                title: const Text('Capture with Camera'),
                subtitle: const Text('Snap handwritten equations or textbook problems'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library, color: AppColors.secondary),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Upload diagram, screenshot or photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleVoiceRecording() async {
    final voiceService = VoiceDoubtService();

    if (_isRecording) {
      await voiceService.stopListening();
      if (!mounted) return;
      setState(() => _isRecording = false);
      final text = _textController.text.trim();
      if (text.isNotEmpty) {
        final cleaned = voiceService.cleanAcademicSpeech(text);
        _textController.text = cleaned;
        _sendMessage();
      }
    } else {
      // 1. Initialize speech recognition
      final available = await voiceService.initSpeech();
      if (!available) {
        // Fallback: If browser / OS speech is not ready, open Voice Doubt Assistant sheet
        if (mounted) _openVoiceDoubtSheet();
        return;
      }

      if (!mounted) return;
      setState(() => _isRecording = true);
      CustomSnackbar.showInfo(context, '🎙️ Listening... Bol kar doubt poochhein (Speak now)');

      final started = await voiceService.startListening(
        localeId: 'hi_IN',
        onResult: (transcription) {
          if (!mounted) return;
          setState(() {
            _textController.text = transcription;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _isRecording = false);
          final text = _textController.text.trim();
          if (text.isNotEmpty && mounted) {
            final cleaned = voiceService.cleanAcademicSpeech(text);
            _textController.text = cleaned;
            _sendMessage();
          }
        },
      );

      if (!started && mounted) {
        setState(() => _isRecording = false);
        _openVoiceDoubtSheet();
      }
    }
  }

  void _openVoiceDoubtSheet() {
    VoiceDoubtSheet.show(
      context,
      scopeTitle: 'General AI Study Tutor',
      initialPrompt: _textController.text,
      onAskAi: (transcribedDoubt) {
        _textController.text = transcribedDoubt;
        _sendMessage();
      },
      onPasteToChat: (transcribedDoubt) {
        setState(() {
          _textController.text = transcribedDoubt;
        });
      },
    );
  }

  void _showTutorModeDialog(BuildContext context, AiTutorController controller) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  'Select Pedagogical Mode',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              ...TutorMode.values.map((mode) {
                final isSel = controller.tutorMode == mode;
                return ListTile(
                  title: Text(mode.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: isSel ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                  onTap: () {
                    controller.setTutorMode(mode);
                    Navigator.pop(ctx);
                    CustomSnackbar.showInfo(context, 'Mode: ${mode.label}');
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showModelSelectorBottomSheet(BuildContext context, AiTutorController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select AI Model Engine',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose model for math solving, long reasoning, or fast response.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: AiTutorController.availableModels.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final option = AiTutorController.availableModels[index];
                    final isSelected = controller.selectedModel.modelId == option.modelId;

                    return InkWell(
                      onTap: () {
                        controller.selectModel(option);
                        Navigator.pop(ctx);
                        CustomSnackbar.showSuccess(context, 'Switched to ${option.modelName}');
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF1E293B) : Colors.grey[50]),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? const Color(0xFF334155) : Colors.grey[200]!),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(option.iconEmoji, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          option.modelName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isSelected ? AppColors.primary : null,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF334155) : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          option.providerName.split(' ').first,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    option.description,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  void _showRenameDialog(BuildContext context, AiTutorController controller, ChatSessionModel session) {
    final textCtrl = TextEditingController(text: session.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Rename Conversation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Chat Title',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final newTitle = textCtrl.text.trim();
              Navigator.pop(ctx);
              if (newTitle.isNotEmpty) {
                controller.renameSession(session.id, newTitle);
                CustomSnackbar.showSuccess(context, 'Conversation renamed');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, AiTutorController controller, ChatSessionModel session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Delete Conversation?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${session.title}"? All messages in this thread will be permanently removed from the database.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              controller.deleteSession(session.id);
              CustomSnackbar.showInfo(context, 'Conversation deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteChatTurn(
    BuildContext context,
    AiTutorController controller,
    ChatMessageModel message,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this exchange?'),
        content: const Text('The question and its AI response will be removed from this chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final deleted = await controller.deleteChatTurn(message.id);
    if (!context.mounted) return;
    if (deleted) {
      CustomSnackbar.showSuccess(context, 'Question and response deleted');
    } else {
      CustomSnackbar.showError(context, 'Could not delete this exchange. Try again.');
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    final controller = context.read<AiTutorController>();

    if (text.isEmpty && controller.selectedImageBase64 == null) return;

    _textController.clear();
    if (mounted) {
      setState(() {});
    }
    controller.sendQuestion(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = context.watch<AiTutorController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleScrollPosition();
        if (controller.isStreaming && _scrollController.hasClients) {
          final pos = _scrollController.position;
          if (pos.maxScrollExtent - pos.pixels < 120) {
            _scrollController.jumpTo(pos.maxScrollExtent);
          }
        }
      }
    });

    return Scaffold(
      drawer: _ChatHistoryDrawer(
        controller: controller,
        isDark: isDark,
        onRename: (s) => _showRenameDialog(context, controller, s),
        onDelete: (s) => _showDeleteDialog(context, controller, s),
      ),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.history_rounded, size: 22),
            tooltip: 'Chat History',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: InkWell(
          onTap: () => _showModelSelectorBottomSheet(context, controller),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  controller.currentSessionTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${controller.selectedModel.modelName} • ${controller.tutorMode.shortTag}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 22),
            tooltip: 'Start New Chat',
            onPressed: () {
              controller.startNewChat();
              CustomSnackbar.showInfo(context, 'Started fresh chat session');
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Chat Options',
            icon: const Icon(Icons.more_horiz_rounded, size: 20),
            onSelected: (val) {
              if (val == 'mode') {
                _showTutorModeDialog(context, controller);
              } else if (val == 'model') {
                _showModelSelectorBottomSheet(context, controller);
              } else if (val == 'rename') {
                if (controller.currentSession != null) {
                  _showRenameDialog(context, controller, controller.currentSession!);
                }
              } else if (val == 'clear') {
                controller.clearChat();
                CustomSnackbar.showInfo(context, 'Chat history cleared');
              } else if (val == 'memory') {
                StudentMemorySheet.show(context);
              } else if (val == 'export') {
                _exportChatAsStudyNotes(context, controller);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'mode',
                child: Row(
                  children: [
                    Icon(Icons.psychology_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Switch Tutor Mode'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'model',
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Switch AI Model'),
                  ],
                ),
              ),
              if (controller.currentSession != null)
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Rename Chat'),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text('Export Chat Notes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'memory',
                child: Row(
                  children: [
                    Icon(Icons.school_outlined, size: 18, color: Color(0xFF6366F1)),
                    SizedBox(width: 8),
                    Text('Target Exam & Weak Topics'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear Chat', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
          child: Column(
            children: [
              // Active Note Grounding Banner
              if (controller.activeNoteTitle != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book_rounded, size: 15, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Grounded in note: ${controller.activeNoteTitle}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () => controller.setNoteContext('', ''),
                        child: const Icon(Icons.close_rounded, size: 16, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],

              // Main Chat Message Area
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: controller.messages.isEmpty
                          ? _buildEmptyState(context, controller, isDark)
                          : ListView.builder(
                              controller: _scrollController,
                              cacheExtent: 280,
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: true,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              itemCount: controller.messages.length + (controller.isLoading && controller.streamingAssistantMessageId == null ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == controller.messages.length && controller.isLoading && controller.streamingAssistantMessageId == null) {
                                  return _buildTypingIndicator(isDark);
                                }
                                final msg = controller.messages[index];
                                return KeyedSubtree(
                                  key: ValueKey(msg.id),
                                  child: RepaintBoundary(
                                    child: _buildMessageItem(context, msg, isDark, controller),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (_showScrollToLatest && controller.messages.isNotEmpty)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          heroTag: 'ai-chat-scroll-to-latest',
                          tooltip: 'Jump to latest message',
                          backgroundColor: isDark ? const Color(0xFF334155) : Colors.white,
                          foregroundColor: AppColors.primary,
                          elevation: 4,
                          onPressed: _scrollToBottom,
                          child: const Icon(Icons.keyboard_double_arrow_down_rounded),
                        ),
                      ),
                  ],
                ),
              ),

              // Image Attachment Bar Preview
              if (controller.selectedImagePath != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: kIsWeb
                            ? Container(
                                width: 44,
                                height: 44,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image, size: 20),
                              )
                            : Image.file(
                                File(controller.selectedImagePath!),
                                width: 44,
                                height: 44,
                                cacheWidth: 132,
                                cacheHeight: 132,
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Attached handwritten image for analysis',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.grey),
                        onPressed: controller.clearImageAttachment,
                      ),
                    ],
                  ),
                ),
              ],

              // Floating Masterclass Audio Player Bar + Bottom Input Bar (Safely Wrapped)
              SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AiAudioPlayerBar(isDark: isDark),
                    _buildInputBar(controller, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildEmptyState(BuildContext context, AiTutorController controller, bool isDark) {
    final suggestions = [
      'Explain a difficult concept simply',
      'Solve a numerical step-by-step',
      'Quiz me on high-yield formulas',
      'Practice previous year questions',
    ];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'How can I help you study?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ask a doubt, solve equations, or pick a prompt below',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: suggestions.map((prompt) {
                return InkWell(
                  onTap: () {
                    _textController.text = prompt;
                    _textController.selection = TextSelection.collapsed(offset: prompt.length);
                    _inputFocusNode.requestFocus();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      prompt,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

    void _exportChatAsStudyNotes(BuildContext context, AiTutorController controller) {
    if (controller.messages.isEmpty) {
      CustomSnackbar.showInfo(context, 'No messages to export');
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('# AI Study Session Notes');
    buffer.writeln('Date: ${DateTime.now().toLocal().toString().split('.')[0]}');
    buffer.writeln('Mode: ${controller.tutorMode.label}');
    buffer.writeln('\n---\n');

    for (final m in controller.messages) {
      if (m.isUser) {
        buffer.writeln('## 👤 Student Doubt\n');
        buffer.writeln(m.content);
        buffer.writeln();
      } else {
        buffer.writeln('## 🤖 AI Tutor Solution\n');
        buffer.writeln(m.content);
        buffer.writeln('\n---\n');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    CustomSnackbar.showSuccess(context, 'Study notes copied to clipboard! 📋');
  }

  Widget _buildMessageItem(
    BuildContext context,
    ChatMessageModel msg,
    bool isDark,
    AiTutorController controller,
  ) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (isUser) const SizedBox(width: 44),
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            fit: isUser ? FlexFit.loose : FlexFit.tight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.getSurface(isDark),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: Border.all(
                  color: isUser
                      ? AppColors.primaryDark
                      : AppColors.getBorder(isDark),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.imageUrl != null && msg.imageUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: kIsWeb
                          ? Container(
                              height: 120,
                              color: Colors.grey[300],
                              child: const Center(child: Icon(Icons.image)),
                            )
                          : Image.file(
                              File(msg.imageUrl!),
                              height: 180,
                              cacheWidth: 600,
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (isUser) ...[
                    if (msg.content.contains('🎤')) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Spoken Voice Doubt',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Audio analyzed by AI Tutor',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (!controller.isLoading)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                              padding: EdgeInsets.zero,
                              tooltip: 'Delete question and response',
                              onPressed: () => _confirmDeleteChatTurn(context, controller, msg),
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white70),
                            ),
                        ],
                      ),
                    ] else ...[
                      _ExpandableUserQuestionContent(
                        content: msg.content,
                        canEdit: controller.canEditLastQuestion(msg.id),
                        isLoading: controller.isLoading,
                        onEdit: () {
                          controller.beginEditingLastQuestion(msg.id);
                          _textController.text = msg.content;
                          _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
                          _inputFocusNode.requestFocus();
                        },
                        onDelete: () => _confirmDeleteChatTurn(context, controller, msg),
                      ),
                    ],
                  ]
                  else ...[
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.psychology_rounded, size: 12, color: Color(0xFF6366F1)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    controller.tutorMode.label,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: msg.content));
                            CustomSnackbar.showSuccess(context, 'Full response copied!');
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(Icons.copy_rounded, size: 13, color: Color(0xFF94A3B8)),
                          ),
                        ),
                        if (!controller.isLoading)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                            padding: EdgeInsets.zero,
                            tooltip: 'Delete question and response',
                            onPressed: () => _confirmDeleteChatTurn(context, controller, msg),
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    FormattedAiText(
                      text: msg.content,
                      isDark: isDark,
                      isStreaming: controller.isStreaming && msg.id == controller.streamingAssistantMessageId,
                      sourceNoteTitle: controller.activeNoteTitle,
                      precomputedBlocks: msg.blocks,
                      onSwitchMode: (mode) {
                        controller.switchModeByName(mode);
                        CustomSnackbar.showInfo(context, 'Switched to ${controller.tutorMode.label}');
                      },
                      onGeneratePracticeProblem: (_) {
                        controller.sendQuestion('Give a practice question on this concept with step-by-step solution');
                        _scrollToBottom();
                      },
                    ),

                    // Quick Action Bar for AI Response (Reusable Component)
                    if (!(controller.isStreaming && msg.id == controller.streamingAssistantMessageId)) ...[
                      const SizedBox(height: 10),
                      AiResponseActionBar(
                        solutionContent: msg.content,
                        spokenTranscript: msg.spokenTranscript,
                        isDark: isDark,
                        onSimplify: () {
                          controller.sendQuestion('Explain this in simpler words using Feynman Technique with a simple analogy');
                          _scrollToBottom();
                        },
                        onPractice: () {
                          controller.sendQuestion('Give a practice question on this concept with step-by-step solution');
                          _scrollToBottom();
                        },
                        onSummarize: () {
                          controller.sendQuestion('Summarize this concept in 3 key bullet points with high-yield exam takeaways');
                          _scrollToBottom();
                        },
                        onRegenerate: controller.canRegenerateAnswer(msg.id)
                            ? () {
                                controller.regenerateLastAnswer(msg.id);
                                _scrollToBottom();
                              }
                            : null,
                      ),
                    ],

                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    final controller = context.read<AiTutorController>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Thinking in ${controller.tutorMode.shortTag} mode with ${controller.selectedModel.modelName}...',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(AiTutorController controller, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.editingMessageId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  const Expanded(child: Text('Editing last question', style: TextStyle(fontSize: 12))),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Cancel edit',
                    onPressed: () {
                      _textController.clear();
                      controller.cancelEditingMessage();
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          AiChatInputBar(
            controller: _textController,
            focusNode: _inputFocusNode,
            isDark: isDark,
            isLoading: controller.isLoading,
            isStreaming: controller.isStreaming,
            onStop: controller.stopGeneration,
            isRecordingVoice: _isRecording,
            hintText: 'Ask in ${controller.tutorMode.shortTag} mode...',
            onSend: _sendMessage,
            onSubmitted: (_) => _sendMessage(),
            onAttachImage: _showAttachmentOptions,
            onToggleVoiceRecord: _toggleVoiceRecording,
            onLongPressVoiceRecord: _openVoiceDoubtSheet,
          ),
        ],
      ),
    );
  }
}

/// Compact, Expandable User Question Bubble
/// If the question is longer than 2 lines, it collapses with an ellipsis
/// and shows a toggle arrow button to expand/collapse on demand.
class _ExpandableUserQuestionContent extends StatefulWidget {
  final String content;
  final bool canEdit;
  final bool isLoading;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ExpandableUserQuestionContent({
    required this.content,
    required this.canEdit,
    required this.isLoading,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_ExpandableUserQuestionContent> createState() => _ExpandableUserQuestionContentState();
}

class _ExpandableUserQuestionContentState extends State<_ExpandableUserQuestionContent> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure whether the text exceeds 2 lines with the available bubble width
        final span = TextSpan(
          text: widget.content,
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        );
        final tp = TextPainter(
          text: span,
          textDirection: Directionality.of(context),
          maxLines: 2,
        )..layout(maxWidth: constraints.maxWidth > 70 ? constraints.maxWidth - 65 : constraints.maxWidth);

        final isLong = tp.didExceedMaxLines || widget.content.contains('\n') || widget.content.length > 90;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: InkWell(
                    onTap: isLong ? () => setState(() => _isExpanded = !_isExpanded) : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Text(
                      widget.content,
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                      maxLines: _isExpanded ? null : (isLong ? 2 : null),
                      overflow: _isExpanded ? TextOverflow.visible : (isLong ? TextOverflow.ellipsis : TextOverflow.visible),
                    ),
                  ),
                ),
                if (isLong) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                if (widget.canEdit)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                    padding: EdgeInsets.zero,
                    tooltip: 'Edit last question',
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_rounded, size: 15, color: Colors.white70),
                  ),
                if (!widget.isLoading)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                    padding: EdgeInsets.zero,
                    tooltip: 'Delete question and response',
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.white70),
                  ),
              ],
            ),
            if (isLong)
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded ? 'Collapse' : 'Show full question',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}


/// --- ChatGPT-Style Chat History Sidebar / Drawer ---
class _ChatHistoryDrawer extends StatefulWidget {
  final AiTutorController controller;
  final bool isDark;
  final ValueChanged<ChatSessionModel> onRename;
  final ValueChanged<ChatSessionModel> onDelete;

  const _ChatHistoryDrawer({
    required this.controller,
    required this.isDark,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_ChatHistoryDrawer> createState() => _ChatHistoryDrawerState();
}

class _ChatHistoryDrawerState extends State<_ChatHistoryDrawer> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Map<String, List<ChatSessionModel>> _groupSessions(List<ChatSessionModel> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sevenDaysAgo = today.subtract(const Duration(days: 7));

    final Map<String, List<ChatSessionModel>> groups = {
      'Today': [],
      'Yesterday': [],
      'Previous 7 Days': [],
      'Older': [],
    };

    for (final s in sessions) {
      if (_filter.isNotEmpty && !s.title.toLowerCase().contains(_filter.toLowerCase())) {
        continue;
      }
      final sDate = DateTime(s.updatedAt.year, s.updatedAt.month, s.updatedAt.day);
      if (sDate.isAtSameMomentAs(today)) {
        groups['Today']!.add(s);
      } else if (sDate.isAtSameMomentAs(yesterday)) {
        groups['Yesterday']!.add(s);
      } else if (sDate.isAfter(sevenDaysAgo)) {
        groups['Previous 7 Days']!.add(s);
      } else {
        groups['Older']!.add(s);
      }
    }

    return groups;
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dtDate = DateTime(dt.year, dt.month, dt.day);

    if (dtDate.isAtSameMomentAs(today)) {
      return DateFormat.jm().format(dt);
    }
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final controller = widget.controller;
    final groups = _groupSessions(controller.sessions);
    final totalCount = controller.sessions.length;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Top Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.forum_rounded, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Chat History',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$totalCount',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Close sidebar',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Prominent "+ New Chat" Button (like ChatGPT)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        controller.startNewChat();
                        Navigator.pop(context);
                        CustomSnackbar.showInfo(context, 'Started fresh chat session');
                      },
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'New Chat',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Search Filter
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search chats...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _filter.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _filter = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _filter = v.trim()),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Conversation Groups List
            Expanded(
              child: controller.isLoadingSessions
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : totalCount == 0
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                const Text(
                                  'No Past Conversations',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Ask your first doubt to start your cloud-synced study log!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          children: [
                            for (final entry in groups.entries)
                              if (entry.value.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                                  child: Text(
                                    entry.key.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                for (final session in entry.value)
                                  _buildSessionTile(session, controller, isDark),
                              ],
                          ],
                        ),
            ),

            // Drawer Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_done_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PostgreSQL Cloud History Synced',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(ChatSessionModel session, AiTutorController controller, bool isDark) {
    final isSelected = controller.currentSessionId == session.id;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.5))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          leading: Icon(
            isSelected ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
            size: 18,
            color: isSelected ? AppColors.primary : (isDark ? Colors.white60 : Colors.black54),
          ),
          title: Text(
            session.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? (isDark ? Colors.white : AppColors.primary) : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _formatTimestamp(session.updatedAt),
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              size: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            tooltip: 'Session options',
            onSelected: (val) {
              if (val == 'rename') {
                widget.onRename(session);
              } else if (val == 'delete') {
                widget.onDelete(session);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 16),
                    SizedBox(width: 8),
                    Text('Rename', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(fontSize: 13, color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
          onTap: () {
            controller.selectSession(session);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
