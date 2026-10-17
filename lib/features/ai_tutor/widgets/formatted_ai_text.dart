import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../core/utils/latex_sanitizer.dart';
import '../../../core/widgets/custom_snackbar.dart';
import '../../voice_doubt/services/ai_tts_service.dart';
import 'collapsible_derivation_card.dart';
import '../../diagram_viewer/widgets/interactive_visual_diagram.dart';
import '../../diagram_viewer/widgets/interactive_graph_plotter.dart';
import '../models/chat_message_model.dart' show AiBlockModel;

/// Professional academic markdown & rich visual renderer for AI responses.
/// Supports:
/// 📊 Visual Diagrams, Flowcharts, Trees & Box Architecture (with Pan & Zoom Modal)
/// 🧮 LaTeX & Scientific Math Formulas / Greek & Physics Symbols
/// 📋 Responsive Markdown Tables with Cell Styling & Horizontal Scrolling
/// 💡 Callout & Exam Tip Alert Boxes
/// 💻 Code Blocks with Syntax Header & One-Tap Copy
/// ☑️ Interactive-styled Checklists & Numbered / Bullet Hierarchies
/// ⚡ Student Action Bar (Copy, + Flashcard Deck, ELI5 Analogy, Exam Points, Test Me)
class FormattedAiText extends StatefulWidget {
  final String text;
  final bool isDark;
  final double baseFontSize;
  final Color? defaultTextColor;
  final VoidCallback? onSaveToFlashcards;
  final Function(String mode)? onSwitchMode;
  final Function(String topic)? onGeneratePracticeProblem;
  final String? sourceNoteTitle;
  final bool isStreaming;
  final List<AiBlockModel>? precomputedBlocks;

  const FormattedAiText({
    super.key,
    required this.text,
    required this.isDark,
    this.baseFontSize = 13.5,
    this.defaultTextColor,
    this.onSaveToFlashcards,
    this.onSwitchMode,
    this.onGeneratePracticeProblem,
    this.sourceNoteTitle,
    this.isStreaming = false,
    this.precomputedBlocks,
  });

  @override
  State<FormattedAiText> createState() => _FormattedAiTextState();
}

class _FormattedAiTextState extends State<FormattedAiText> {
  static const _initialBlockCount = 12;
  static const _blocksPerPage = 12;

  // ⚡ Memoized block parse: only re-parses when text changes, not on every streaming setState
  List<_AiBlock>? _cachedBlocks;
  String? _cachedText;
  int _visibleBlockCount = _initialBlockCount;
  int _lastParseTimeMs = 0;
  int _lastSpokenBlockIndex = 0;
  int _lastChunkIndex = -1;

  @override
  void didUpdateWidget(covariant FormattedAiText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isStreaming != widget.isStreaming || oldWidget.precomputedBlocks != widget.precomputedBlocks) {
      _cachedText = null;
      _cachedBlocks = null;
      _visibleBlockCount = _initialBlockCount;
    } else if (oldWidget.text != widget.text) {
      _lastSpokenBlockIndex = 0;
      _lastChunkIndex = -1;
      if (!widget.isStreaming) {
        _cachedText = null;
        _cachedBlocks = null;
      }
      _visibleBlockCount = _initialBlockCount;
    }
  }

  List<_AiBlock> _getBlocks() {
    // ⚡ Server-Side Pre-Parsed AST Blocks: Skip heavy multi-pass regex scanning on phone
    if (widget.precomputedBlocks != null && widget.precomputedBlocks!.isNotEmpty) {
      if (_cachedBlocks != null && _cachedText == widget.text) {
        return _cachedBlocks!;
      }
      _cachedText = widget.text;
      _cachedBlocks = widget.precomputedBlocks!
          .map((b) => _AiBlock(
                type: _blockTypeFromString(b.type),
                text: b.text,
                extra: b.extra,
              ))
          .toList();
      return _cachedBlocks!;
    }
    if (_cachedText != widget.text || _cachedBlocks == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      // ⚡ Smooth 60 FPS Streaming Throttler:
      // While active streaming is ongoing without server precomputed blocks, avoid re-parsing
      // 50+ times per second on micro-token arrivals. Throttle to ~50ms intervals unless a newline occurs.
      final shouldThrottle = widget.isStreaming &&
          _cachedBlocks != null &&
          _cachedBlocks!.isNotEmpty &&
          (now - _lastParseTimeMs < 50) &&
          !widget.text.endsWith('\n');

      if (shouldThrottle) {
        return _cachedBlocks!;
      }

      _lastParseTimeMs = now;
      _cachedText = widget.text;
      _cachedBlocks = _parseTextIntoBlocks(widget.text);
    }
    return _cachedBlocks!;
  }

  static _BlockType _blockTypeFromString(String t) {
    switch (t) {
      case 'heading1': return _BlockType.heading1;
      case 'heading2': return _BlockType.heading2;
      case 'heading3': return _BlockType.heading3;
      case 'bullet': return _BlockType.bullet;
      case 'numbered': return _BlockType.numbered;
      case 'checklist': return _BlockType.checklist;
      case 'table': return _BlockType.table;
      case 'diagram': return _BlockType.diagram;
      case 'graph': return _BlockType.graph;
      case 'visualFlow': return _BlockType.visualFlow;
      case 'formula': return _BlockType.formula;
      case 'derivation': return _BlockType.derivation;
      case 'code': return _BlockType.code;
      case 'callout': return _BlockType.callout;
      case 'comparison': return _BlockType.comparison;
      case 'divider': return _BlockType.divider;
      default: return _BlockType.paragraph;
    }
  }

  // Expose widget fields as local getters for ergonomic access in helper methods
  String get text => widget.text;
  bool get isDark => widget.isDark;
  double get baseFontSize => widget.baseFontSize;
  Color? get defaultTextColor => widget.defaultTextColor;
  VoidCallback? get onSaveToFlashcards => widget.onSaveToFlashcards;
  Function(String mode)? get onSwitchMode => widget.onSwitchMode;
  Function(String topic)? get onGeneratePracticeProblem => widget.onGeneratePracticeProblem;
  String? get sourceNoteTitle => widget.sourceNoteTitle;
  bool get isStreaming => widget.isStreaming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = _getBlocks();
    final tts = AiTtsService();

    final isSpeakingThis = tts.isPlaying && tts.currentText == text;
    final currentSentence = tts.currentRawSentence.trim();
    final currentChunk = tts.currentChunkIndex;

    int activeBlockIndex = -1;
    if (isSpeakingThis && currentSentence.isNotEmpty && blocks.isNotEmpty) {
      activeBlockIndex = _resolveSequentialSpokenBlock(
        blocks: blocks,
        currentSentence: currentSentence,
        currentChunkIndex: currentChunk,
        totalChunks: tts.totalChunks,
      );
      if (activeBlockIndex >= _visibleBlockCount) {
        _visibleBlockCount = (activeBlockIndex + 1 + _blocksPerPage).clamp(0, blocks.length);
      }
    }

    final visibleBlockCount = _visibleBlockCount < blocks.length ? _visibleBlockCount : blocks.length;

    Widget buildBody() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Grounding Badge (if source note provided)
        if (sourceNoteTitle != null && sourceNoteTitle!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF6366F1)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Grounded in: $sourceNoteTitle',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Render Parsed Blocks with Strict Sequential Highlighting
        ...List.generate(
          visibleBlockCount,
          (index) => _renderBlock(context, blocks[index], theme, index: index, isSpokenActive: index == activeBlockIndex),
        ),

        if (visibleBlockCount < blocks.length)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _visibleBlockCount += _blocksPerPage;
              }),
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              label: Text('Load more (${blocks.length - visibleBlockCount} sections left)'),
            ),
          ),

        // In-flight streaming pulse indicator
        if (isStreaming) ...[
          const SizedBox(height: 8),
          const _StreamingPulseCursor(),
        ],

        // Interactive Student Action Bar (shown when streaming completed)
        if (visibleBlockCount == blocks.length &&
          !isStreaming &&
          (onSaveToFlashcards != null || onSwitchMode != null || onGeneratePracticeProblem != null)) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Copy Action
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: text));
                    CustomSnackbar.showSuccess(context, 'AI explanation copied!');
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 13, color: Color(0xFF64748B)),
                        SizedBox(width: 4),
                        Text('Copy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Save to Flashcard Deck
                if (onSaveToFlashcards != null) ...[
                  InkWell(
                    onTap: onSaveToFlashcards,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.style_rounded, size: 13, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text('+ Flashcard', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // ELI5 Mode Switch
                if (onSwitchMode != null) ...[
                  InkWell(
                    onTap: () => onSwitchMode!('eli5'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.child_care_rounded, size: 13, color: Color(0xFFD97706)),
                          SizedBox(width: 4),
                          Text('👶 ELI5 Analogy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => onSwitchMode!('exam'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.assignment_turned_in_rounded, size: 13, color: Color(0xFF6366F1)),
                          SizedBox(width: 4),
                          Text('🎯 Exam Points', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => onSwitchMode!('derivation'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.straighten_rounded, size: 13, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text('📐 Math Steps', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // Practice Problem / Test Me
                if (onGeneratePracticeProblem != null) ...[
                  InkWell(
                    onTap: () => onGeneratePracticeProblem!('similar_problem'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.quiz_rounded, size: 13, color: Color(0xFF8B5CF6)),
                          SizedBox(width: 4),
                          Text('⚡ Test Me', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );

    final initialBody = buildBody();
    final content = ListenableBuilder(
      listenable: tts,
      builder: (context, child) {
        // ⚡ Performance optimization: Only rebuild block tree if this specific message
        // is currently playing audio! If audio is playing for another message or stopped,
        // instantly return the cached child without re-rendering math/diagrams!
        if (tts.currentText != text) {
          return child!;
        }
        return buildBody();
      },
      child: initialBody,
    );

    // ⚡ Performance optimization: do NOT wrap in SelectionArea while actively streaming
    // SelectionArea recalculates all selectable text metrics and node geometries on every frame,
    // which causes severe UI thread frame drops during token generation.
    // Once streaming completes, SelectionArea is cleanly enabled for copy/selection support.
    if (isStreaming) {
      return content;
    }
    return SelectionArea(child: content);
  }

  int _resolveSequentialSpokenBlock({
    required List<_AiBlock> blocks,
    required String currentSentence,
    required int currentChunkIndex,
    required int totalChunks,
  }) {
    if (blocks.isEmpty) return -1;

    // If user tapped a prior section or navigated back, allow moving back
    if (currentChunkIndex < _lastChunkIndex) {
      _lastSpokenBlockIndex = 0;
    }
    _lastChunkIndex = currentChunkIndex;

    // 1. First priority: Check if currentSentence is still inside the current active block
    // (A single block or explanation paragraph often contains 2 to 4 spoken sentences)
    if (_lastSpokenBlockIndex >= 0 && _lastSpokenBlockIndex < blocks.length) {
      final currentBlockText = blocks[_lastSpokenBlockIndex].text.trim();
      if (_matchesBlock(currentBlockText, currentSentence)) {
        return _lastSpokenBlockIndex;
      }
    }

    // 2. Second priority: Search forward in a strictly localized window (+1, +2, +3 blocks)
    // This PREVENTS JUMPING to distant topics that share keywords like "Formula", "Step", or "Law"
    final int startSearch = (_lastSpokenBlockIndex >= 0) ? _lastSpokenBlockIndex + 1 : 0;
    final int forwardLimit = (startSearch + 3 < blocks.length) ? startSearch + 3 : blocks.length;

    for (int i = startSearch; i < forwardLimit; i++) {
      if (_matchesBlock(blocks[i].text.trim(), currentSentence)) {
        _lastSpokenBlockIndex = i;
        return i;
      }
    }

    // 3. Third priority: Extended sequential forward search (only forward, never jump backward)
    for (int i = forwardLimit; i < blocks.length; i++) {
      if (_matchesBlock(blocks[i].text.trim(), currentSentence)) {
        _lastSpokenBlockIndex = i;
        return i;
      }
    }

    // 4. Proportional progressive estimate if text was heavily stripped of formatting
    if (totalChunks > 0 && currentChunkIndex >= 0) {
      final estimatedIndex = ((currentChunkIndex / totalChunks) * blocks.length).floor().clamp(0, blocks.length - 1);
      if (estimatedIndex >= _lastSpokenBlockIndex) {
        _lastSpokenBlockIndex = estimatedIndex;
        return estimatedIndex;
      }
    }

    return _lastSpokenBlockIndex.clamp(0, blocks.length - 1);
  }

  bool _matchesBlock(String blockText, String sentence) {
    if (blockText.isEmpty || sentence.isEmpty) return false;
    final b = blockText.toLowerCase();
    final s = sentence.toLowerCase();
    return b.contains(s) || s.contains(b) || _isSubstantialOverlap(b, s);
  }

  Widget _renderBlock(
    BuildContext context,
    _AiBlock block,
    ThemeData theme, {
    int index = -1,
    bool isSpokenActive = false,
  }) {
    final textColor = defaultTextColor ?? (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B));
    final blockWidget = _buildRawBlockWidget(context, block, theme, textColor);

    if (!isSpokenActive) {
      return InkWell(
        onDoubleTap: () {
          if (index >= 0) {
            _lastSpokenBlockIndex = index;
          }
          AiTtsService().speakFromSection(text, block.text);
        },
        borderRadius: BorderRadius.circular(8),
        splashColor: const Color(0x1A6366F1),
        child: blockWidget,
      );
    }

    // Glowing Real-Time Karaoke Highlight with Automatic Smooth Viewport Scroll
    return _AutoScrollBlockWrapper(
      isSpeakingActive: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF6366F1).withValues(alpha: 0.20)
              : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? const Color(0xFF818CF8).withValues(alpha: 0.55)
                : const Color(0xFFC7D2FE),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.22 : 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_up_rounded, size: 10, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    'Reading Now',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            blockWidget,
          ],
        ),
      ),
    );
  }

  static bool _isSubstantialOverlap(String a, String b) {
    if (a.length < 10 || b.length < 10) return false;
    final cleanA = a.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ').toLowerCase();
    final cleanB = b.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ').toLowerCase();
    final wordsB = cleanB.split(RegExp(r'\s+')).where((w) => w.length > 3).toList();
    if (wordsB.isEmpty) return false;
    int matches = 0;
    for (final w in wordsB) {
      if (cleanA.contains(w)) matches++;
    }
    return matches >= 2 && (matches / wordsB.length) >= 0.4;
  }

  Widget _buildRawBlockWidget(BuildContext context, _AiBlock block, ThemeData theme, Color textColor) {
    try {
      switch (block.type) {
      case _BlockType.heading1:
        final h1Text = _cleanHeadingText(block.text);
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(
            h1Text,
            style: GoogleFonts.outfit(
              fontSize: baseFontSize + 4,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6366F1),
              height: 1.3,
            ),
          ),
        );

      case _BlockType.heading2:
        final h2Text = _cleanHeadingText(block.text);
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            children: [
              Container(
                width: 3.5,
                height: 16,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text(
                  h2Text,
                  style: GoogleFonts.outfit(
                    fontSize: baseFontSize + 2,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        );

      case _BlockType.heading3:
        return _buildHeading3Widget(context, block);

      case _BlockType.bullet:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 7, right: 8),
                height: 6,
                width: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildRichInlineText(block.text, textColor),
              ),
            ],
          ),
        );

      case _BlockType.numbered:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2, right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  block.extra ?? '•',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                ),
              ),
              Expanded(
                child: _buildRichInlineText(block.text, textColor),
              ),
            ],
          ),
        );

      case _BlockType.checklist:
        final isChecked = block.extra == 'true';
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Icon(
                  isChecked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 15,
                  color: isChecked ? const Color(0xFF10B981) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                ),
              ),
              Expanded(
                child: _buildRichInlineText(
                  block.text,
                  isChecked ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)) : textColor,
                ),
              ),
            ],
          ),
        );

      case _BlockType.table:
        return RepaintBoundary(child: _buildTableWidget(context, block));

      case _BlockType.diagram:
        return _DeferredAiBlock(
          label: 'Render interactive diagram',
          builder: () => _buildDiagramWidget(context, block),
        );

      case _BlockType.graph:
        return RepaintBoundary(child: _buildGraphWidget(context, block));

      case _BlockType.visualFlow:
        return RepaintBoundary(child: _buildVisualFlowWidget(context, block));

      case _BlockType.formula:
        return RepaintBoundary(child: _buildFormulaWidget(context, block));

      case _BlockType.derivation:
        return RepaintBoundary(child: _buildDerivationWidget(context, block));

      case _BlockType.code:
        return RepaintBoundary(child: _buildCodeWidget(context, block));

      case _BlockType.comparison:
        return RepaintBoundary(child: _buildComparisonWidget(context, block));

      case _BlockType.callout:
        return RepaintBoundary(child: _buildCalloutWidget(context, block));

      case _BlockType.divider:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        );

        case _BlockType.paragraph:
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildRichInlineText(block.text, textColor),
          );
      }
    } catch (e, stack) {
      debugPrint('FormattedAiText _renderBlock error on ${block.type}: $e\n$stack');
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _buildRichInlineText(block.text, textColor),
      );
    }
  }

  static String _cleanHeadingText(String text) {
    return _formatInlineMathFallback(text).replaceAll(RegExp(r'\*{1,2}'), '').trim();
  }

  static final RegExp _inlineMathFallbackRx = RegExp(
    r'\$\$([^$]+)\$\$|\$([^$]+)\$|\\\((.*?)\\\)|\\\[(.*?)\\\]',
  );

  static String _formatInlineMathFallback(String text) {
    final formatted = text.replaceAllMapped(_inlineMathFallbackRx, (match) {
      final rawMath = (match.group(1) ?? match.group(2) ?? match.group(3) ?? match.group(4) ?? '').trim();
      return _isGenuineMath(rawMath) ? _formatMathText(rawMath) : rawMath;
    });
    return LatexSanitizer.clean(formatted);
  }

  Widget _buildHeading3Widget(BuildContext context, _AiBlock block) {
    final title = _cleanHeadingText(block.text);
    final lower = title.toLowerCase();

    // 💡 Themed badge for Exam Tips & Scoring Points
    if (lower.contains('exam tip') || lower.contains('high-yield') || title.contains('💡')) {
      return Container(
        margin: const EdgeInsets.only(top: 14, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.16 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.35 : 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lightbulb_rounded, size: 15, color: Color(0xFFD97706)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title.replaceAll('💡', '').trim(),
                style: GoogleFonts.outfit(
                  fontSize: baseFontSize + 1.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ⚠️ Themed badge for Common Misconceptions & Traps
    if (lower.contains('misconception') || lower.contains('trap') || title.contains('⚠️')) {
      return Container(
        margin: const EdgeInsets.only(top: 14, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.16 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.35 : 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFDC2626)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title.replaceAll('⚠️', '').trim(),
                style: GoogleFonts.outfit(
                  fontSize: baseFontSize + 1.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 🔗 Themed badge for Related Concepts
    if (lower.contains('related concept') || title.contains('🔗')) {
      return Container(
        margin: const EdgeInsets.only(top: 14, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.16 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.35 : 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hub_rounded, size: 15, color: Color(0xFF0284C7)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title.replaceAll('🔗', '').trim(),
                style: GoogleFonts.outfit(
                  fontSize: baseFontSize + 1.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 📌 Themed badge for Key Takeaways / Summary
    if (lower.contains('takeaway') || lower.contains('summary') || title.contains('📌')) {
      return Container(
        margin: const EdgeInsets.only(top: 14, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.16 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 15, color: Color(0xFF059669)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title.replaceAll('📌', '').trim(),
                style: GoogleFonts.outfit(
                  fontSize: baseFontSize + 1.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 📘 Themed badge for Foundation
    if (lower.contains('foundation') || lower.contains('core concept') || lower.contains('core intuition')) {
      return Container(
        margin: const EdgeInsets.only(top: 14, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.16 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.35 : 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_rounded, size: 15, color: Color(0xFF6366F1)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title.replaceAll('📘', '').trim(),
                style: GoogleFonts.outfit(
                  fontSize: baseFontSize + 1.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6366F1),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 🧠 Themed badge for Deep Explanation
    if (lower.contains('deep explanation') || lower.contains('detailed explanation') || lower.contains('deep mechanism')) {
      return Container(
        margin: const EdgeInsets.only(top: 14, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.16 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.35 : 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.psychology_rounded, size: 15, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title.replaceAll('🧠', '').trim(),
                style: GoogleFonts.outfit(
                  fontSize: baseFontSize + 1.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Standard heading3 with sleek modern bar
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 14,
            margin: const EdgeInsets.only(right: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: baseFontSize + 1.5,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 📊 DIAGRAM & FLOWCHART RENDERER (With Interactive Zoom/Pan Modal)
  // ===========================================================================
  Widget _buildDiagramWidget(BuildContext context, _AiBlock block) {
    final diagramTitle = _extractDiagramTitle(block.extra, block.text);
    final archetype = InteractiveVisualDiagram.detectArchetype(block.extra ?? diagramTitle, block.text);
    return InteractiveVisualDiagram(
      rawText: block.text,
      diagramTitle: diagramTitle,
      isDark: isDark,
      baseFontSize: baseFontSize,
      initialArchetype: archetype,
    );
  }

  Widget _buildGraphWidget(BuildContext context, _AiBlock block) {
    return InteractiveGraphPlotter(
      rawGraphSpec: block.text,
      title: block.extra ?? 'Mathematical Function Plotter',
      isDark: isDark,
    );
  }

  String _extractDiagramTitle(String? lang, String text) {
    // Check if JSON diagram has a "title"
    if (text.contains('"title"')) {
      final titleMatch = _jsonTitleRx.firstMatch(text);
      if (titleMatch != null) {
        final extracted = titleMatch.group(1)!.trim();
        if (extracted.isNotEmpty) return extracted;
      }
    }

    if (lang != null && lang.trim().isNotEmpty) {
      final trimmed = lang.trim();
      // If language tag has a title like: diagram:cycle Krebs Citric Acid Cycle
      if (trimmed.contains(' ')) {
        final title = trimmed.substring(trimmed.indexOf(' ') + 1).trim();
        if (title.isNotEmpty) return title;
      }
      if (trimmed.contains(':')) {
        final title = trimmed.substring(trimmed.indexOf(':') + 1).trim();
        if (title.isNotEmpty && !['flow', 'cycle', 'compare', 'tree', 'hub', 'mindmap', 'stack', 'json', 'sketch'].contains(title.toLowerCase())) {
          return title;
        }
      }
    }
    final archetype = InteractiveVisualDiagram.detectArchetype(lang ?? '', text);
    switch (archetype) {
      case DiagramArchetype.cycle:
        return '⟳ Biological / Physical Closed Cycle';
      case DiagramArchetype.comparison:
        return '⚔️ Comparative Concept Analysis';
      case DiagramArchetype.tree:
        return '🌳 Hierarchical Taxonomy & Classification';
      case DiagramArchetype.hub:
        return '🧠 Concept Hub & Core Pillars';
      case DiagramArchetype.stack:
        return '📚 Layered Architecture & Protocol Stack';
      case DiagramArchetype.timeline:
        return '⏱️ Chronological Timeline & Sequence';
      case DiagramArchetype.flow:
        return '➔ Sequential Process & Decision Flow';
    }
  }

  // ===========================================================================
  // 🔄 VISUAL SEQUENTIAL FLOW (e.g. Step 1 -> Step 2 -> Step 3)
  // ===========================================================================
  Widget _buildVisualFlowWidget(BuildContext context, _AiBlock block) {
    final steps = block.text.split(_flowSplitRx).where((s) => s.trim().isNotEmpty).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.25) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.alt_route_rounded, size: 14, color: Color(0xFF6366F1)),
              SizedBox(width: 6),
              Text(
                'Sequential Step-by-Step Flow',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(steps.length, (idx) {
                final isLast = idx == steps.length - 1;
                final stepText = steps[idx].trim();

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            stepText,
                            style: TextStyle(
                              fontSize: baseFontSize - 1,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 16, color: const Color(0xFF6366F1).withValues(alpha: 0.8)),
                      ),
                    ],
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 📋 MARKDOWN TABLE RENDERER
  // ===========================================================================
  Widget _buildTableWidget(BuildContext context, _AiBlock block) {
    final tableData = _parseMarkdownTable(block.text);
    if (tableData == null || tableData.headers.isEmpty) {
      return SelectableText(block.text);
    }

    final headers = tableData.headers;
    final rows = tableData.rows;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder(
              horizontalInside: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                width: 1,
              ),
              verticalInside: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                width: 1,
              ),
            ),
            children: [
              // Header Row
              TableRow(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.7) : const Color(0xFFEEF2FF),
                ),
                children: headers.map((h) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: _buildRichInlineText(
                      h.trim(),
                      const Color(0xFF6366F1),
                    ),
                  );
                }).toList(),
              ),

              // Data Rows
              ...rows.asMap().entries.map((entry) {
                final rowIdx = entry.key;
                final row = entry.value;
                final isEven = rowIdx % 2 == 0;

                return TableRow(
                  decoration: BoxDecoration(
                    color: isEven
                        ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                        : (isDark ? const Color(0xFF131D31) : const Color(0xFFF8FAFC)),
                  ),
                  children: List.generate(headers.length, (colIdx) {
                    final cellText = colIdx < row.length ? row[colIdx].trim() : '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      child: _buildRichInlineText(
                        cellText,
                        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    );
                  }),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 🧮 SCIENTIFIC & LATEX FORMULA RENDERER (KaTeX Display + Symbol Fallback)
  // ===========================================================================
  Widget _buildFormulaWidget(BuildContext context, _AiBlock block) {
    var rawFormula = block.text.trim();
    if (rawFormula.startsWith(r'$$') && rawFormula.endsWith(r'$$') && rawFormula.length >= 4) {
      rawFormula = rawFormula.substring(2, rawFormula.length - 2).trim();
    } else if (rawFormula.startsWith(r'\[') && rawFormula.endsWith(r'\]') && rawFormula.length >= 4) {
      rawFormula = rawFormula.substring(2, rawFormula.length - 2).trim();
    } else if (rawFormula.startsWith(r'$') && rawFormula.endsWith(r'$') && rawFormula.length >= 2) {
      rawFormula = rawFormula.substring(1, rawFormula.length - 1).trim();
    } else if (rawFormula.toLowerCase().startsWith('formula:')) {
      rawFormula = rawFormula.substring(8).trim();
    } else if (rawFormula.toLowerCase().startsWith('equation:')) {
      rawFormula = rawFormula.substring(9).trim();
    }

    final fallbackText = _formatMathText(rawFormula);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF082F49).withValues(alpha: 0.28) : const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.45 : 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: isDark ? 0.12 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.functions_rounded, size: 14, color: Color(0xFF0284C7)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'FORMULA & EQUATION',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: Color(0xFF0284C7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF0284C7)),
                tooltip: 'Copy LaTeX Formula',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: rawFormula));
                  CustomSnackbar.showSuccess(context, 'LaTeX equation copied to clipboard!');
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: !_isGenuineMath(rawFormula)
                  ? SelectableText(
                      rawFormula,
                      style: GoogleFonts.outfit(
                        fontSize: baseFontSize + 1.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                      ),
                    )
                  : Math.tex(
                      rawFormula,
                      textStyle: TextStyle(
                        fontSize: baseFontSize + 2.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                      ),
                      mathStyle: MathStyle.display,
                      onErrorFallback: (err) => SelectableText(
                        fallbackText,
                        style: GoogleFonts.firaCode(
                          fontSize: baseFontSize + 1,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 📐 COLLAPSIBLE MATH & LOGICAL DERIVATION ACCORDION RENDERER
  // ===========================================================================
  Widget _buildDerivationWidget(BuildContext context, _AiBlock block) {
    final subBlocks = _parseTextIntoBlocks(block.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: subBlocks.map((b) => _renderBlock(context, b, Theme.of(context))).toList(),
    );
  }

  // ===========================================================================
  // 💻 CODE BLOCK RENDERER
  // ===========================================================================
  Widget _buildCodeWidget(BuildContext context, _AiBlock block) {
    final lang = block.extra?.isNotEmpty == true ? block.extra!.toLowerCase().trim() : 'code';

    Color langColor;
    String langName;
    IconData langIcon;

    if (lang.contains('py')) {
      langColor = const Color(0xFF38BDF8);
      langName = 'PYTHON 3';
      langIcon = Icons.code_rounded;
    } else if (lang.contains('cpp') || lang.contains('c++') || lang == 'c') {
      langColor = const Color(0xFF6366F1);
      langName = 'C++ / ALGORITHMIC CODE';
      langIcon = Icons.terminal_rounded;
    } else if (lang.contains('java') && !lang.contains('script')) {
      langColor = const Color(0xFFF59E0B);
      langName = 'JAVA HARDCORE';
      langIcon = Icons.coffee_rounded;
    } else if (lang.contains('js') || lang.contains('javascript') || lang.contains('ts') || lang.contains('typescript')) {
      langColor = const Color(0xFFFBBF24);
      langName = 'JAVASCRIPT / NODE.JS';
      langIcon = Icons.javascript_rounded;
    } else if (lang.contains('sql') || lang.contains('postgres') || lang.contains('mysql')) {
      langColor = const Color(0xFFEC4899);
      langName = 'SQL DATABASE QUERY';
      langIcon = Icons.storage_rounded;
    } else if (lang.contains('go') || lang.contains('golang')) {
      langColor = const Color(0xFF06B6D4);
      langName = 'GO SYSTEM CODE';
      langIcon = Icons.data_object_rounded;
    } else if (lang.contains('dart')) {
      langColor = const Color(0xFF10B981);
      langName = 'DART / FLUTTER';
      langIcon = Icons.flutter_dash_rounded;
    } else {
      langColor = const Color(0xFF94A3B8);
      langName = lang.toUpperCase();
      langIcon = Icons.code_rounded;
    }

    final codeLines = block.text.split('\n');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF020617) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: langColor.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Studio CS Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(bottom: BorderSide(color: langColor.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: langColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(langIcon, size: 14, color: langColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    langName,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: langColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 1-Tap Big-O Complexity Action
                InkWell(
                  onTap: () {
                    if (onGeneratePracticeProblem != null) {
                      onGeneratePracticeProblem!('What is the Time and Space Complexity (Big-O) of this code algorithm?');
                    } else {
                      Clipboard.setData(ClipboardData(text: 'What is the Big-O Time & Space Complexity of this code:\n\n${block.text}'));
                      CustomSnackbar.showSuccess(context, 'Ask AI for Big-O Complexity copied!');
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, size: 11, color: Color(0xFFA5B4FC)),
                        SizedBox(width: 3),
                        Text('⏱️ Big-O', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFA5B4FC))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
                  tooltip: 'Copy Code',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: block.text));
                    CustomSnackbar.showSuccess(context, 'Code copied to clipboard! 💻');
                  },
                ),
              ],
            ),
          ),

          // Code Text with Monospace Line Numbers
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line Number Margin
                  if (codeLines.length > 1) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(codeLines.length, (idx) {
                        return Text(
                          '${idx + 1}',
                          style: GoogleFonts.firaCode(
                            fontSize: baseFontSize - 1.5,
                            color: const Color(0xFF475569),
                            height: 1.45,
                          ),
                        );
                      }),
                    ),
                    Container(
                      width: 1,
                      height: (codeLines.length * (baseFontSize - 1.5) * 1.45),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: const Color(0xFF334155),
                    ),
                  ],

                  // Code Text
                  SelectableText(
                    block.text,
                    style: GoogleFonts.firaCode(
                      fontSize: baseFontSize - 1,
                      color: const Color(0xFFE2E8F0),
                      height: 1.45,
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

  // ===========================================================================
  // 💡 CALLOUT / EXAM TIP ALERT RENDERER (6 Studio-Grade Archetypes)
  // ===========================================================================
  Widget _buildComparisonWidget(BuildContext context, _AiBlock block) {
    final isMistake = block.extra == 'mistake';
    final cardColor = isMistake
        ? const Color(0xFFEF4444).withValues(alpha: isDark ? 0.12 : 0.07)
        : const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.07);
    final borderColor = isMistake
        ? const Color(0xFFEF4444).withValues(alpha: isDark ? 0.35 : 0.25)
        : const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.25);
    final icon = isMistake ? Icons.cancel_rounded : Icons.check_circle_rounded;
    final iconColor = isMistake ? const Color(0xFFDC2626) : const Color(0xFF059669);
    final displayText = block.text.replaceFirst(RegExp(r'^[❌✅]\\s*'), '').trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildRichInlineText(
              displayText,
              isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalloutWidget(BuildContext context, _AiBlock block) {
    final alertType = block.extra?.toLowerCase() ?? 'tip';

    Color cardBg;
    Color borderColor;
    Color accentBarColor;
    Color iconColor;
    Color textColor;
    IconData iconData;
    String alertTitle;

    if (alertType.contains('exam') || alertType.contains('important') || alertType.contains('tip')) {
      // 🎯 High-Yield Exam Focus (Indigo/Violet)
      cardBg = const Color(0xFF6366F1).withValues(alpha: isDark ? 0.12 : 0.07);
      borderColor = const Color(0xFF6366F1).withValues(alpha: isDark ? 0.35 : 0.25);
      accentBarColor = const Color(0xFF6366F1);
      iconColor = const Color(0xFF6366F1);
      textColor = isDark ? const Color(0xFFE0E7FF) : const Color(0xFF312E81);
      iconData = Icons.assignment_turned_in_rounded;
      alertTitle = '🎯 HIGH-YIELD EXAM FOCUS & SCORING KEYWORDS';
    } else if (alertType.contains('warning') || alertType.contains('pitfall') || alertType.contains('trap') || alertType.contains('watch')) {
      // ⚠️ Common Pitfall / Trap (Rose/Red)
      cardBg = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.14 : 0.08);
      borderColor = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.4 : 0.25);
      accentBarColor = const Color(0xFFEF4444);
      iconColor = const Color(0xFFEF4444);
      textColor = isDark ? const Color(0xFFFECDD3) : const Color(0xFF881337);
      iconData = Icons.warning_amber_rounded;
      alertTitle = '⚠️ COMMON EXAM TRAP & MISCONCEPTION';
    } else if (alertType.contains('feynman') || alertType.contains('hook')) {
      // 🧠 Feynman Mental Hook (Cyan/Teal)
      cardBg = const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.12 : 0.07);
      borderColor = const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.35 : 0.25);
      accentBarColor = const Color(0xFF06B6D4);
      iconColor = const Color(0xFF0891B2);
      textColor = isDark ? const Color(0xFFCFFAFE) : const Color(0xFF164E63);
      iconData = Icons.psychology_rounded;
      alertTitle = '🧠 FEYNMAN MENTAL HOOK & CORE ESSENCE';
    } else if (alertType.contains('connected') || alertType.contains('link') || alertType.contains('next')) {
      // 🔗 Connected Concept / Study Next (Blue/Sky)
      cardBg = const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.12 : 0.07);
      borderColor = const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.35 : 0.25);
      accentBarColor = const Color(0xFF3B82F6);
      iconColor = const Color(0xFF2563EB);
      textColor = isDark ? const Color(0xFFDBEAFE) : const Color(0xFF1E3A8A);
      iconData = Icons.link_rounded;
      alertTitle = '🔗 CONNECTED TOPIC & PREREQUISITE';
    } else if (alertType.contains('derivation') || alertType.contains('step') || alertType.contains('proof')) {
      // 📐 Step Rationale / Proof Note (Emerald/Green)
      cardBg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.07);
      borderColor = const Color(0xFF10B981).withValues(alpha: isDark ? 0.35 : 0.25);
      accentBarColor = const Color(0xFF10B981);
      iconColor = const Color(0xFF059669);
      textColor = isDark ? const Color(0xFFD1FAE5) : const Color(0xFF064E3B);
      iconData = Icons.straighten_rounded;
      alertTitle = '📐 STEP-BY-STEP DERIVATION RATIONALE';
    } else {
      // 💡 Core Intuition & Analogy (Amber/Gold)
      cardBg = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.08);
      borderColor = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.35 : 0.25);
      accentBarColor = const Color(0xFFF59E0B);
      iconColor = const Color(0xFFD97706);
      textColor = isDark ? const Color(0xFFFEF3C7) : const Color(0xFF78350F);
      iconData = Icons.lightbulb_rounded;
      alertTitle = '💡 CORE INTUITION & REAL-WORLD ANALOGY';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: accentBarColor.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored Left Accent Strip
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentBarColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(9),
                  bottomLeft: Radius.circular(9),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(iconData, size: 15, color: iconColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            alertTitle,
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: iconColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildRichInlineText(block.text, textColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 🔤 INLINE RICH TEXT & MATH SPANS (With In-Flight Streaming Sanitizer)
  // ===========================================================================
  // ⚡ Static compiled regex — avoids recompilation on every paragraph render during streaming
  static final RegExp _inlineRichRegex = RegExp(
    r'(\*\*([^*]+)\*\*)|(\*([^*]+)\*)|(`([^`]+)`)|(\$\$([^$]+)\$\$)|(\$([^$]+)\$(- ?[a-zA-Z0-9_\-]+)?)|(\\\((.*?)\\\)(- ?[a-zA-Z0-9_\-]+)?)|(\\\[(.*?)\\\])',
  );

  Widget _buildRichInlineText(String text, Color baseColor) {
    final sanitized = _sanitizeStreamingInlineText(text, isStreaming: isStreaming);
    final spans = <InlineSpan>[];
    final regex = _inlineRichRegex;
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(sanitized)) {
      if (match.start > lastMatchEnd) {
        final snippet = sanitized.substring(lastMatchEnd, match.start);
        spans.add(TextSpan(
          text: LatexSanitizer.clean(snippet),
          style: TextStyle(
            fontSize: baseFontSize,
            height: 1.55,
            color: baseColor,
          ),
        ));
      }

      if (match.group(2) != null) {
        // **bold** text with student pastel highlighter pen tint
        spans.add(TextSpan(
          text: ' ${_formatInlineMathFallback(match.group(2)!)} ',
          style: TextStyle(
            fontSize: baseFontSize,
            fontWeight: FontWeight.w700,
            height: 1.55,
            backgroundColor: isDark
                ? const Color(0xFFF59E0B).withValues(alpha: 0.22)
                : const Color(0xFFFEF08A).withValues(alpha: 0.75),
            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F),
          ),
        ));
      } else if (match.group(4) != null) {
        // *italic*
        spans.add(TextSpan(
          text: LatexSanitizer.clean(match.group(4)!),
          style: TextStyle(
            fontSize: baseFontSize,
            fontStyle: FontStyle.italic,
            height: 1.55,
            color: baseColor,
          ),
        ));
      } else if (match.group(6) != null) {
        // `code`
        spans.add(TextSpan(
          text: ' ${match.group(6)!} ',
          style: GoogleFonts.firaCode(
            fontSize: baseFontSize - 1,
            fontWeight: FontWeight.w600,
            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
          ),
        ));
      } else {
        // Math symbol or formula ($math$-suffix or $$math$$ or \(math\)-suffix or \[math\])
        final rawMath = (match.group(8) ?? match.group(10) ?? match.group(13) ?? match.group(16) ?? '').trim();
        final suffix = (match.group(11) ?? match.group(14) ?? '').trim();

        // 🛡️ Guard against regular text mistakenly wrapped in single dollars (e.g. "$some text$" or "$speed of light$")
        // If not a genuine math expression, render as clean regular inline text without dollar signs
        if (!_isGenuineMath(rawMath)) {
          spans.add(TextSpan(
            text: '${LatexSanitizer.clean(rawMath)}$suffix',
            style: TextStyle(
              fontSize: baseFontSize,
              fontWeight: FontWeight.w600,
              height: 1.55,
              color: baseColor,
            ),
          ));
          lastMatchEnd = match.end;
          continue;
        }

        final mathColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
        final fallbackMath = _formatMathText(rawMath);

        // Check if rawMath is a simple single symbol/Greek letter (e.g. \epsilon, \alpha, \theta, x, y)
        final isSimpleSymbol = !fallbackMath.contains('\\') && fallbackMath.trim().isNotEmpty && (fallbackMath.length <= 6 || rawMath.startsWith('\\'));

        // ⚡ While streaming: render math as lightweight TextSpan using Unicode formatting.
        // Re-compiling Math.tex AST and creating WidgetSpans on every 100ms streaming tick
        // causes heavy UI thread stalls. Once streaming completes, full Math.tex renders beautifully.
        if (isStreaming || (isSimpleSymbol && !rawMath.contains('\\frac') && !rawMath.contains('\\sqrt') && !rawMath.contains('^') && !rawMath.contains('_'))) {
          spans.add(TextSpan(
            text: '$fallbackMath$suffix',
            style: TextStyle(
              fontSize: baseFontSize,
              fontWeight: FontWeight.w700,
              fontStyle: isStreaming ? FontStyle.italic : FontStyle.normal,
              height: 1.55,
              color: mathColor,
            ),
          ));
        } else {
          final isDisplayMath = match.group(8) != null || match.group(16) != null;
          Widget mathWidget = RepaintBoundary(
            child: Math.tex(
              rawMath,
              textStyle: TextStyle(
                fontSize: baseFontSize,
                fontWeight: FontWeight.w600,
                color: mathColor,
              ),
              mathStyle: isDisplayMath ? MathStyle.display : MathStyle.text,
              onErrorFallback: (err) => Text(
                '$fallbackMath ',
                style: GoogleFonts.firaCode(
                  fontSize: baseFontSize,
                  fontWeight: FontWeight.bold,
                  color: mathColor,
                ),
              ),
            ),
          );

          if (suffix.isNotEmpty) {
            mathWidget = Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                mathWidget,
                Text(
                  suffix,
                  style: TextStyle(
                    fontSize: baseFontSize,
                    fontWeight: FontWeight.w700,
                    color: mathColor,
                    height: 1.55,
                  ),
                ),
              ],
            );
          }

          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Tooltip(
                message: rawMath,
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: rawMath));
                    if (mounted) {
                      CustomSnackbar.showSuccess(context, 'LaTeX equation copied!');
                    }
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: mathWidget,
                  ),
                ),
              ),
            ),
          ));
        }
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < sanitized.length) {
      final trailing = sanitized.substring(lastMatchEnd);
      spans.add(TextSpan(
        text: LatexSanitizer.clean(trailing),
        style: TextStyle(
          fontSize: baseFontSize,
          height: 1.55,
          color: baseColor,
        ),
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }

  // ⚡ Static compiled regexes for streaming sanitizer, math validation, and LaTeX formatter
  static final RegExp _boldMarkerRx = RegExp(r'\*\*');
  static final RegExp _backtickRx = RegExp(r'`');
  static final RegExp _singleDollarRx = RegExp(r'(?<!\$)\$(?!\$)');
  static final RegExp _supScriptRx = RegExp(r'\^([0-9\+\-a-zA-Z])');
  static final RegExp _supBraceRx = RegExp(r'\^\{([0-9\+\-a-zA-Z=()]+)\}');
  static final RegExp _subScriptRx = RegExp(r'_([0-9\+\-a-zA-Z])');
  static final RegExp _subBraceRx = RegExp(r'_\{([0-9\+\-a-zA-Z=()]+)\}');

  static final RegExp _jsonTitleRx = RegExp(r'"title"\s*:\s*"([^"]+)"');
  static final RegExp _flowSplitRx = RegExp(r'\s*(?:-->|==>|->|➔|⭢)\s*');
  static final RegExp _stepHeaderRx = RegExp(
    r'^(?:#{1,4}\s*)?(?:\*\*)?(?:Step|Phase|Stage)\s*(\d+)[:\.\-\s]*(.*)$',
    caseSensitive: false,
  );
  static final RegExp _asterisksStripRx = RegExp(r'^\*+|\*+$');
  static final RegExp _equationPrefixRx = RegExp(r'^(?:equation|formula):\s*', caseSensitive: false);
  static final RegExp _intuitionPrefixRx = RegExp(r'^(?:💡\s*|intuition:\s*|why:\s*|reason:\s*)', caseSensitive: false);
  static final RegExp _rulePrefixRx = RegExp(r'^(?:rule|theorem|law):\s*', caseSensitive: false);

  static final RegExp _mathOperatorRx = RegExp(r'[\+\-\*\/\=><]');
  static final RegExp _alphanumericRx = RegExp(r'[0-9a-zA-Z]');
  static final RegExp _hyphenatedWordRx = RegExp(r'^[a-zA-Z]+-[a-zA-Z]+$');
  static final RegExp _digitWithUnitRx = RegExp(r'^[0-9]+[a-zA-Z%]+$');

  static final RegExp _vecRx = RegExp(r'\\vec\{([^}]+)\}');
  static final RegExp _sqrtNthRx = RegExp(r'\\sqrt\[([^\]]+)\]\{([^}]+)\}');
  static final RegExp _sqrtRx = RegExp(r'\\sqrt\{([^}]+)\}');
  static final RegExp _fracRx = RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}');
  static final RegExp _limRx = RegExp(r'\\lim_\{([^}]+)\}');
  static final RegExp _textTagsRx = RegExp(r'\\(?:text|mathbf|mathit|mathrm|mathbb)\{([^}]+)\}');

  static final RegExp _calloutPrefixRx = RegExp(r'^(>|\[!(?:NOTE|TIP|WARNING|IMPORTANT|CAUTION|EXAMPLE)\])\s*', caseSensitive: false);
  static final RegExp _calloutHeaderEmojiRx = RegExp(
    r'^(?:🎯\s*(?:Exam Tip|High-Yield Exam Focus|Exam Focus)?:?|⚠️\s*(?:Common Trap|Common Pitfall|Watch Out)?:?|🧠\s*(?:Feynman Hook|Mental Model)?:?|🔗\s*(?:Connected Concept|Study Next)?:?|📐\s*(?:Derivation Note|Proof Note)?:?|💡\s*(?:Intuition|Analogy|Key Insight)?:?)\s*',
    caseSensitive: false,
  );
  static final RegExp _quotePrefixRx = RegExp(r'^>\s*');
  static final RegExp _flowArrowCountRx = RegExp(r'(?:-->|==>|->)');
  static final RegExp _dividerRx = RegExp(r'^(?:---|[*]{3,}|_{3,})$');
  static final RegExp _h4to6Rx = RegExp(r'^#{4,6}\s+');

  /// Auto-closes uncompleted streaming markdown markers on-the-fly to prevent visual flashing during live streaming
  static String _sanitizeStreamingInlineText(String text, {bool isStreaming = false}) {
    if (!isStreaming || text.isEmpty) return text;
    // ⚡ Fast path: avoid running 3 regex passes on paragraphs that contain no markdown/math markers
    if (!text.contains('*') && !text.contains('`') && !text.contains(r'$')) return text;
    var s = text;
    if (_boldMarkerRx.allMatches(s).length % 2 == 1) s = '$s**';
    if (_backtickRx.allMatches(s).length % 2 == 1) s = '$s`';
    if (_singleDollarRx.allMatches(s).length % 2 == 1) s = '$s\$';
    return s;
  }

  /// Validates whether the text inside $ ... $ is a true mathematical expression or symbol,
  /// rather than regular plain words that the AI mistakenly wrapped in dollar signs (e.g. "$some text$").
  static bool _isGenuineMath(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return false;

    // 1. LaTeX command backslash (e.g. \frac, \sqrt, \alpha, \times, \vec, \sum, \int)
    if (trimmed.contains(r'\')) return true;

    // 2. Mathematical operators & relational symbols
    if (trimmed.contains('=') ||
        trimmed.contains('^') ||
        trimmed.contains('_') ||
        trimmed.contains('±') ||
        trimmed.contains('×') ||
        trimmed.contains('÷') ||
        trimmed.contains('≠') ||
        trimmed.contains('≤') ||
        trimmed.contains('≥') ||
        trimmed.contains('≈') ||
        trimmed.contains('→') ||
        trimmed.contains('∑') ||
        trimmed.contains('∫') ||
        trimmed.contains('√')) {
      return true;
    }

    // If text contains multiple words separated by spaces and lacks explicit math syntax (=, \, ^, _, operators)
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      final hasMathStructure = trimmed.contains(r'\') ||
          trimmed.contains('=') ||
          trimmed.contains('^') ||
          trimmed.contains('_') ||
          trimmed.contains('±') ||
          trimmed.contains('×') ||
          trimmed.contains('÷') ||
          trimmed.contains('≠') ||
          trimmed.contains('≤') ||
          trimmed.contains('≥') ||
          trimmed.contains('≈') ||
          trimmed.contains('→') ||
          trimmed.contains('∑') ||
          trimmed.contains('∫') ||
          trimmed.contains('√');
      if (!hasMathStructure) {
        return false;
      }
    }

    // 3. Mathematical expressions containing operators (+, -, *, /, <, >) with numbers or variables
    if (_mathOperatorRx.hasMatch(trimmed) && _alphanumericRx.hasMatch(trimmed)) {
      // Avoid hyphens in normal hyphenated words (e.g. "step-by-step", "in-depth")
      if (!_hyphenatedWordRx.hasMatch(trimmed)) {
        return true;
      }
    }

    // 4. Mathematical function calls: sin(x), cos(x), tan(x), ln(x), log(x), exp(x), f(x), g(x)
    if (trimmed.contains('(') && trimmed.endsWith(')')) {
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('sin') ||
          lower.startsWith('cos') ||
          lower.startsWith('tan') ||
          lower.startsWith('ln') ||
          lower.startsWith('log') ||
          lower.startsWith('exp') ||
          lower.startsWith('f(') ||
          lower.startsWith('g(')) {
        return true;
      }
    }

    // 5. Single variable or short algebraic term without spaces (e.g. x, y, z, F, v, t, m, c, E, 2x, 5m/s)
    if (!trimmed.contains(' ')) {
      // 1-2 char variable (e.g. x, y, dx, dt, E, F)
      if (trimmed.length <= 2) return true;
      // Formula with digits and symbols (e.g. 10m/s, x^2, 100%)
      if (_digitWithUnitRx.hasMatch(trimmed)) return true;
    }

    // Otherwise it's plain text (e.g. "some text", "speed of light", "uniform motion")
    return false;
  }

  // ===========================================================================
  // 🧮 SCIENTIFIC & LATEX SYMBOL REPLACEMENTS (Comprehensive Universal Engine)
  // ===========================================================================
  // ⚡ Static const maps — allocated once at class load, never re-created per-call
  static const Map<String, String> _greekMap = {
    r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ', r'\Gamma': 'Γ',
    r'\delta': 'δ', r'\Delta': 'Δ', r'\epsilon': 'ε', r'\varepsilon': 'ε',
    r'\zeta': 'ζ', r'\eta': 'η', r'\theta': 'θ', r'\vartheta': 'ϑ',
    r'\Theta': 'Θ', r'\iota': 'ι', r'\kappa': 'κ', r'\lambda': 'λ',
    r'\Lambda': 'Λ', r'\mu': 'μ', r'\nu': 'ν', r'\xi': 'ξ', r'\Xi': 'Ξ',
    r'\pi': 'π', r'\Pi': 'Π', r'\rho': 'ρ', r'\varrho': 'ϱ',
    r'\sigma': 'σ', r'\Sigma': 'Σ', r'\tau': 'τ', r'\upsilon': 'υ',
    r'\Upsilon': 'Υ', r'\phi': 'φ', r'\varphi': 'ϕ', r'\Phi': 'Φ',
    r'\chi': 'χ', r'\psi': 'ψ', r'\Psi': 'Ψ', r'\omega': 'ω', r'\Omega': 'Ω',
  };

  static String _formatMathText(String input) {
    String s = input.trim();

    // Remove wrapping $$ or $ or \( \)
    if (s.startsWith(r'$$') && s.endsWith(r'$$') && s.length >= 4) {
      s = s.substring(2, s.length - 2).trim();
    } else if (s.startsWith(r'$') && s.endsWith(r'$') && s.length >= 2) {
      s = s.substring(1, s.length - 1).trim();
    } else if (s.startsWith(r'\(') && s.endsWith(r'\)') && s.length >= 4) {
      s = s.substring(2, s.length - 2).trim();
    }

    _greekMap.forEach((k, v) { s = s.replaceAll(k, v); });

    // ⚡ Static const operator map — no allocation per call
    const opMap = {
      r'\times': '×', r'\cdot': '·', r'\div': '÷', r'\pm': '±', r'\mp': '∓',
      r'\leq': '≤', r'\le': '≤', r'\geq': '≥', r'\ge': '≥',
      r'\neq': '≠', r'\ne': '≠', r'\approx': '≈', r'\equiv': '≡',
      r'\propto': '∝', r'\sim': '∼', r'\infty': '∞', r'\partial': '∂',
      r'\nabla': '∇', r'\in': '∈', r'\notin': '∉', r'\subset': '⊂',
      r'\subseteq': '⊆', r'\cup': '∪', r'\cap': '∩',
      r'\forall': '∀', r'\exists': '∃',
      r'\int': '∫', r'\iint': '∬', r'\oint': '∮',
      r'\sum': '∑', r'\prod': '∏',
      r'\rightarrow': '→', r'\to': '→', r'\leftarrow': '←',
      r'\Rightarrow': '⇒', r'\Leftarrow': '⇐',
      r'\leftrightarrow': '↔', r'\Leftrightarrow': '⇔',
      r'\degree': '°', r'^\circ': '°',
      r'\therefore': '∴', r'\because': '∵',
      r'\angle': '∠', r'\perp': '⊥', r'\parallel': '∥',
      r'\hbar': 'ℏ', r'\hat{i}': 'î', r'\hat{j}': 'ĵ', r'\hat{k}': 'k̂',
    };
    opMap.forEach((k, v) { s = s.replaceAll(k, v); });

    // Vectors: \vec{v} -> v⃗
    s = s.replaceAllMapped(_vecRx, (m) => '${m.group(1)}⃗');

    // Square root: \sqrt{x} -> √(x), \sqrt[n]{x} -> ⁿ√(x)
    s = s.replaceAllMapped(_sqrtNthRx, (m) => '${m.group(1)}√(${m.group(2)})');
    s = s.replaceAllMapped(_sqrtRx, (m) => '√(${m.group(1)})');
    s = s.replaceAll(r'\sqrt', '√');

    // Fractions: \frac{a}{b} -> (a / b)
    s = s.replaceAllMapped(_fracRx, (m) => '(${m.group(1)} / ${m.group(2)})');

    // Limits: \lim_{x \to 0} -> lim(x→0)
    s = s.replaceAllMapped(_limRx, (m) => 'lim(${m.group(1)})');

    // Text tags: \text{...}, \mathbf{...}, \mathit{...}, \mathrm{...}
    s = s.replaceAllMapped(_textTagsRx, (m) => m.group(1) ?? '');
    s = s.replaceAll(r'\left', '').replaceAll(r'\right', '');

    // ⚡ Static const super/sub maps + static compiled regexes
    const supMap = {
      '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
      '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
      '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
      'a': 'ᵃ', 'b': 'ᵇ', 'c': 'ᶜ', 'd': 'ᵈ', 'e': 'ᵉ',
      'f': 'ᶠ', 'g': 'ᵍ', 'h': 'ʰ', 'i': 'ⁱ', 'j': 'ʲ',
      'k': 'ᵏ', 'l': 'ˡ', 'm': 'ᵐ', 'n': 'ⁿ', 'o': 'ᵒ',
      'p': 'ᵖ', 'r': 'ʳ', 's': 'ˢ', 't': 'ᵗ', 'u': 'ᵘ',
      'v': 'ᵛ', 'w': 'ʷ', 'x': 'ˣ', 'y': 'ʸ', 'z': 'ᶻ',
      'A': 'ᴬ', 'B': 'ᴮ', 'D': 'ᴰ', 'E': 'ᴱ', 'G': 'ᴳ',
      'H': 'ᴴ', 'I': 'ᴵ', 'J': 'ᴶ', 'K': 'ᴷ', 'L': 'ᴸ',
      'M': 'ᴹ', 'N': 'ᴺ', 'O': 'ᴼ', 'P': 'ᴾ', 'R': 'ᴿ',
      'T': 'ᵀ', 'U': 'ᵁ', 'V': 'ⱽ', 'W': 'ᵂ',
    };
    const subMap = {
      '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
      '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
      '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
      'a': 'ₐ', 'e': 'ₑ', 'o': 'ₒ', 'x': 'ₓ', 'n': 'ₙ',
      'i': 'ᵢ', 'j': 'ⱼ', 'k': 'ₖ', 't': 'ₜ', 'p': 'ₚ',
      'r': 'ᵣ', 'u': 'ᵤ', 'v': 'ᵥ', 'm': 'ₘ', 's': 'ₛ',
      'l': 'ₗ', 'h': 'ₕ',
    };
    s = s.replaceAllMapped(_supScriptRx, (m) => supMap[m.group(1)] ?? m.group(0)!);
    s = s.replaceAllMapped(_supBraceRx, (m) {
      return (m.group(1) ?? '').split('').map((c) => supMap[c] ?? c).join();
    });
    s = s.replaceAllMapped(_subScriptRx, (m) => subMap[m.group(1)] ?? m.group(0)!);
    s = s.replaceAllMapped(_subBraceRx, (m) {
      return (m.group(1) ?? '').split('').map((c) => subMap[c] ?? c).join();
    });

    return LatexSanitizer.clean(s);
  }

  // ===========================================================================
  // 🧩 BLOCK PARSER (With Multi-Line Callouts, Formulas & Streaming Smoothing)
  // ===========================================================================
  List<_AiBlock> _parseTextIntoBlocks(String raw) {
    final trimmedRaw = raw.trim();
    // Support structured AI responses: { "explanation": "...", "nodes": [...], "edges": [...] } or { "diagram": { ... } }
    if (trimmedRaw.startsWith('{') &&
        trimmedRaw.endsWith('}') &&
        (trimmedRaw.contains('"diagram"') || (trimmedRaw.contains('"nodes"') && (trimmedRaw.contains('"edges"') || trimmedRaw.contains('"relations"'))))) {
      try {
        final decoded = jsonDecode(trimmedRaw);
        if (decoded is Map<String, dynamic> && (decoded.containsKey('diagram') || decoded.containsKey('nodes'))) {
          final List<_AiBlock> jsonBlocks = [];
          final explanation = decoded['explanation']?.toString() ?? decoded['summary']?.toString();
          if (explanation != null && explanation.trim().isNotEmpty) {
            jsonBlocks.add(_AiBlock(type: _BlockType.paragraph, text: explanation.trim()));
          }
          final diagramObj = decoded['diagram'] ?? decoded;
          final diagramJson = jsonEncode(diagramObj);
          String title = decoded['title']?.toString() ??
              (diagramObj is Map ? (diagramObj['title']?.toString() ?? 'Hand-Drawn Concept Diagram') : 'Hand-Drawn Concept Diagram');
          jsonBlocks.add(_AiBlock(
            type: _BlockType.diagram,
            text: diagramJson,
            extra: 'diagram:sketch $title',
          ));
          return jsonBlocks;
        }
      } catch (_) {}
    }

    final lines = raw.split('\n');
    final List<_AiBlock> blocks = [];

    bool insideCodeBlock = false;
    String codeLanguage = '';
    final codeBuffer = StringBuffer();

    bool insideTable = false;
    final tableBuffer = StringBuffer();

    bool insideFormulaBlock = false;
    final formulaBuffer = StringBuffer();

    bool insideCallout = false;
    String currentCalloutType = 'tip';
    final calloutBuffer = StringBuffer();

    void flushCallout() {
      if (insideCallout) {
        final content = calloutBuffer.toString().trim();
        if (content.isNotEmpty) {
          blocks.add(_AiBlock(type: _BlockType.callout, text: content, extra: currentCalloutType));
        }
        calloutBuffer.clear();
        insideCallout = false;
      }
    }

    void flushTable() {
      if (insideTable) {
        final content = tableBuffer.toString().trim();
        if (content.isNotEmpty) {
          blocks.add(_AiBlock(type: _BlockType.table, text: content));
        }
        tableBuffer.clear();
        insideTable = false;
      }
    }

    void flushFormula() {
      if (insideFormulaBlock) {
        final content = formulaBuffer.toString().trim();
        if (content.isNotEmpty) {
          if (!_isGenuineMath(content)) {
            blocks.add(_AiBlock(type: _BlockType.paragraph, text: content));
          } else {
            blocks.add(_AiBlock(type: _BlockType.formula, text: content));
          }
        }
        formulaBuffer.clear();
        insideFormulaBlock = false;
      }
    }

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i];
      final line = rawLine.trim();

      // Code / Diagram Block Boundary (```)
      if (line.startsWith('```')) {
        flushCallout();
        flushTable();
        flushFormula();

        if (insideCodeBlock) {
          final content = codeBuffer.toString().trim();
          final lang = codeLanguage.toLowerCase().trim();

          if (['derivation', 'math-derivation', 'steps', 'proof', 'step-by-step'].contains(lang)) {
            blocks.addAll(_parseTextIntoBlocks(content));
          } else if (['graph', 'plot', 'curve', 'function-graph', 'coordinate-plot'].contains(lang)) {
            blocks.add(_AiBlock(
              type: _BlockType.graph,
              text: content,
              extra: 'Interactive Coordinate Plot',
            ));
          } else if (_isDiagramLanguageOrContent(lang, content)) {
            blocks.add(_AiBlock(
              type: _BlockType.diagram,
              text: content,
              extra: codeLanguage.isNotEmpty ? codeLanguage : null,
            ));
          } else if (['math', 'latex', 'equation', 'formula', 'tex'].contains(lang)) {
            blocks.add(_AiBlock(
              type: _BlockType.formula,
              text: content,
              extra: 'Mathematical Equation',
            ));
          } else {
            blocks.add(_AiBlock(
              type: _BlockType.code,
              text: content,
              extra: codeLanguage.isNotEmpty ? codeLanguage : null,
            ));
          }

          codeBuffer.clear();
          insideCodeBlock = false;
          codeLanguage = '';
        } else {
          insideCodeBlock = true;
          codeLanguage = line.substring(3).trim();
        }
        continue;
      }

      if (insideCodeBlock) {
        codeBuffer.writeln(rawLine);
        continue;
      }

      // Multi-Line Formula Block ($$ ... $$ or \[ ... \])
      if ((line.startsWith(r'$$') && !line.endsWith(r'$$')) ||
          (line.startsWith(r'\[') && !line.endsWith(r'\]'))) {
        flushCallout();
        flushTable();
        if (insideFormulaBlock) {
          flushFormula();
        } else {
          insideFormulaBlock = true;
          final startContent = line.startsWith(r'$$')
              ? line.substring(2).trim()
              : line.substring(2).trim();
          if (startContent.isNotEmpty) formulaBuffer.writeln(startContent);
          continue;
        }
      } else if (insideFormulaBlock) {
        if (line.endsWith(r'$$') || line.endsWith(r'\]')) {
          final endContent = line.endsWith(r'$$')
              ? line.substring(0, line.length - 2).trim()
              : line.substring(0, line.length - 2).trim();
          if (endContent.isNotEmpty) formulaBuffer.writeln(endContent);
          flushFormula();
          continue;
        } else {
          formulaBuffer.writeln(rawLine);
          continue;
        }
      }

      // Markdown Table Row Detection (| Col | Col |)
      if (line.startsWith('|') && line.endsWith('|') && line.length > 2) {
        flushCallout();
        flushFormula();
        insideTable = true;
        tableBuffer.writeln(line);
        continue;
      } else if (insideTable) {
        flushTable();
      }

      if (line.isEmpty) {
        if (insideCallout) {
          calloutBuffer.writeln();
          continue;
        }
        continue;
      }

      // Callout Boxes & Exam Tips (> ... or [!NOTE])
      final isCalloutStart = line.startsWith('> ') ||
          line.toLowerCase().startsWith('[!note]') ||
          line.toLowerCase().startsWith('[!tip]') ||
          line.toLowerCase().startsWith('[!warning]') ||
          line.toLowerCase().startsWith('[!important]') ||
          line.toLowerCase().startsWith('[!caution]');

      if (isCalloutStart) {
        String calloutType = 'tip';
        final lowerLine = line.toLowerCase();
        if (lowerLine.contains('🎯') || lowerLine.contains('exam') || lowerLine.contains('important') || lowerLine.contains('score')) {
          calloutType = 'exam';
        } else if (lowerLine.contains('⚠️') || lowerLine.contains('warning') || lowerLine.contains('pitfall') || lowerLine.contains('trap') || lowerLine.contains('caution')) {
          calloutType = 'warning';
        } else if (lowerLine.contains('🧠') || lowerLine.contains('feynman') || lowerLine.contains('hook')) {
          calloutType = 'feynman';
        } else if (lowerLine.contains('🔗') || lowerLine.contains('connected') || lowerLine.contains('link') || lowerLine.contains('next')) {
          calloutType = 'connected';
        } else if (lowerLine.contains('📐') || lowerLine.contains('derivation') || lowerLine.contains('step') || lowerLine.contains('proof')) {
          calloutType = 'derivation';
        } else if (lowerLine.contains('💡') || lowerLine.contains('intuition') || lowerLine.contains('analogy') || lowerLine.contains('insight')) {
          calloutType = 'intuition';
        }

        final cleanText = line
            .replaceFirst(_calloutPrefixRx, '')
            .replaceFirst(_calloutHeaderEmojiRx, '')
            .trim();

        if (insideCallout && calloutType == currentCalloutType) {
          calloutBuffer.writeln(cleanText);
        } else {
          flushCallout();
          insideCallout = true;
          currentCalloutType = calloutType;
          calloutBuffer.writeln(cleanText);
        }
        continue;
      } else if (insideCallout && line.startsWith('>')) {
        calloutBuffer.writeln(line.replaceFirst(_quotePrefixRx, ''));
        continue;
      } else {
        flushCallout();
      }

      // Comparison highlight (❌ Common Mistake / ✅ Correct Concept)
      final trimmedLine = line.trim();
      // Strip any leading bullet marker to also catch '- ❌ ...' lines
      final compLine = trimmedLine.replaceFirst(RegExp(r'^[-*•]\s*'), '');
      if (compLine.startsWith('❌') || compLine.toLowerCase().startsWith('mistake:') || compLine.toLowerCase().startsWith('common mistake:')) {
        flushCallout();
        flushTable();
        flushFormula();
        blocks.add(_AiBlock(type: _BlockType.comparison, text: compLine, extra: 'mistake'));
        continue;
      } else if (compLine.startsWith('✅') || compLine.toLowerCase().startsWith('correct:') || compLine.toLowerCase().startsWith('correct concept:')) {
        flushCallout();
        flushTable();
        flushFormula();
        blocks.add(_AiBlock(type: _BlockType.comparison, text: compLine, extra: 'correct'));
        continue;
      }

      // Standalone ASCII Art / Diagram in text (e.g. tree lines or box lines)
      if (_isStandaloneDiagramText(line)) {
        final diagBuffer = StringBuffer()..writeln(rawLine);
        while (i + 1 < lines.length && (_isStandaloneDiagramText(lines[i + 1].trim()) || lines[i + 1].trim().startsWith('|'))) {
          i++;
          diagBuffer.writeln(lines[i]);
        }
        blocks.add(_AiBlock(type: _BlockType.diagram, text: diagBuffer.toString().trim()));
        continue;
      }

      // Sequential Flow (e.g. Step 1 -> Step 2 -> Step 3)
      if (line.contains('-->') || line.contains('==>') || (line.contains('->') && !line.startsWith('- '))) {
        final count = _flowArrowCountRx.allMatches(line).length;
        if (count >= 2) {
          blocks.add(_AiBlock(type: _BlockType.visualFlow, text: line));
          continue;
        }
      }

      // Horizontal Divider Rules (---, ***, ___)
      if (_dividerRx.hasMatch(line)) {
        flushCallout();
        flushTable();
        flushFormula();
        blocks.add(const _AiBlock(type: _BlockType.divider, text: ''));
        continue;
      }

      // Headings (H1 - H6)
      if (line.startsWith('# ')) {
        blocks.add(_AiBlock(type: _BlockType.heading1, text: line.substring(2).trim()));
      } else if (line.startsWith('## ')) {
        final h2Text = line.substring(3).trim();
        final lowerH2 = h2Text.toLowerCase();
        if (lowerH2.contains('foundation') || lowerH2.contains('deep explanation') ||
            lowerH2.contains('exam tip') || lowerH2.contains('high-yield') ||
            lowerH2.contains('misconception') || lowerH2.contains('trap') ||
            lowerH2.contains('related concept') || lowerH2.contains('takeaway') ||
            lowerH2.contains('core concept') || lowerH2.contains('summary')) {
          blocks.add(_AiBlock(type: _BlockType.heading3, text: h2Text));
        } else {
          blocks.add(_AiBlock(type: _BlockType.heading2, text: h2Text));
        }
      } else if (line.startsWith('### ')) {
        blocks.add(_AiBlock(type: _BlockType.heading3, text: line.substring(4).trim()));
      } else if (_h4to6Rx.hasMatch(line)) {
        final cleanHeading = line.replaceFirst(_h4to6Rx, '').trim();
        blocks.add(_AiBlock(type: _BlockType.heading3, text: cleanHeading));
      }
      // Standalone Single-Line Equations / Formulas
      else if ((line.startsWith(r'$$') && line.endsWith(r'$$') && line.length > 4) ||
          (line.startsWith(r'\[') && line.endsWith(r'\]') && line.length > 4) ||
          line.toLowerCase().startsWith('formula:') ||
          line.toLowerCase().startsWith('equation:')) {
        final inner = line.startsWith(r'$$')
            ? line.substring(2, line.length - 2).trim()
            : (line.startsWith(r'\[') ? line.substring(2, line.length - 2).trim() : line);
        if ((line.startsWith(r'$$') || line.startsWith(r'\[')) && !_isGenuineMath(inner)) {
          blocks.add(_AiBlock(type: _BlockType.paragraph, text: inner));
        } else {
          blocks.add(_AiBlock(type: _BlockType.formula, text: line));
        }
      }
      // ⚡ Single match call per regex (no double-compile with hasMatch + firstMatch)
      // Checklists (- [ ] or - [x])
      else if (_checklistRx.firstMatch(line) case final clMatch?) {
        final isChecked = clMatch.group(1)?.toLowerCase() == 'x';
        blocks.add(_AiBlock(
          type: _BlockType.checklist,
          text: clMatch.group(2) ?? '',
          extra: isChecked ? 'true' : 'false',
        ));
      }
      // Numbered List
      else if (_numberedRx.firstMatch(line) case final nlMatch?) {
        blocks.add(_AiBlock(
          type: _BlockType.numbered,
          text: nlMatch.group(2) ?? '',
          extra: nlMatch.group(1),
        ));
      }
      // Bullet List (•, -, *)
      else if (_bulletRx.firstMatch(line) case final blMatch?) {
        blocks.add(_AiBlock(type: _BlockType.bullet, text: blMatch.group(1)?.trim() ?? ''));
      }
      // Standard Paragraph
      else {
        blocks.add(_AiBlock(type: _BlockType.paragraph, text: line));
      }
    }

    flushCallout();
    flushTable();
    flushFormula();

    if (insideCodeBlock && codeBuffer.isNotEmpty) {
      final content = codeBuffer.toString().trim();
      final lang = codeLanguage.toLowerCase().trim();
      if (['derivation', 'math-derivation', 'steps', 'proof', 'step-by-step'].contains(lang)) {
        blocks.add(_AiBlock(type: _BlockType.derivation, text: content, extra: 'Mathematical & Logical Derivation'));
      } else if (['graph', 'plot', 'curve', 'function-graph', 'coordinate-plot'].contains(lang)) {
        blocks.add(_AiBlock(type: _BlockType.graph, text: content, extra: 'Interactive Coordinate Plot'));
      } else if (_isDiagramLanguageOrContent(lang, content)) {
        // While streaming, render unclosed diagram blocks as code/text to avoid crashing on partial JSON.
        // Once the closing ``` arrives, it transforms instantly into the full interactive diagram!
        if (isStreaming) {
          blocks.add(_AiBlock(type: _BlockType.code, text: content, extra: codeLanguage.isNotEmpty ? codeLanguage : 'diagram'));
        } else {
          blocks.add(_AiBlock(type: _BlockType.diagram, text: content, extra: codeLanguage.isNotEmpty ? codeLanguage : null));
        }
      } else if (['math', 'latex', 'equation', 'formula', 'tex'].contains(lang)) {
        blocks.add(_AiBlock(type: _BlockType.formula, text: content, extra: 'Mathematical Equation'));
      } else {
        blocks.add(_AiBlock(type: _BlockType.code, text: content, extra: codeLanguage.isNotEmpty ? codeLanguage : null));
      }
    }

    return blocks;
  }

  // ⚡ Static regex constants for parser helpers
  static final RegExp _checklistRx = RegExp(r'^-\s+\[([ xX])\]\s+(.*)');
  static final RegExp _numberedRx = RegExp(r'^(\d+)\.\s+(.*)');
  static final RegExp _bulletRx = RegExp(r'^(?:[•\-\*])\s+(.*)');

  bool _isDiagramLanguageOrContent(String lang, String content) {
    final l = lang.toLowerCase();
    if (l.startsWith('diagram') ||
        l.startsWith('sketch') ||
        ['mermaid', 'flowchart', 'ascii', 'tree', 'schema', 'cycle', 'compare', 'mindmap', 'hub', 'stack', 'timeline', 'milestone', 'handdrawn', 'rough', 'whiteboard', 'excalidraw'].contains(l)) {
      return true;
    }
    // Check if content is structured JSON diagram with nodes
    if (content.contains('"nodes"') && (content.contains('"edges"') || content.contains('"relations"') || content.contains('"title"'))) {
      return true;
    }
    // Check if content is ASCII tree or box architecture
    if (content.contains('├──') || content.contains('└──') || content.contains('┌──') || content.contains('+--') || content.contains('-->')) {
      return true;
    }
    return false;
  }

  bool _isStandaloneDiagramText(String line) {
    return line.contains('├──') || line.contains('└──') || line.startsWith('┌') || line.startsWith('+---') || line.startsWith('|   |');
  }

  _TableData? _parseMarkdownTable(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.length < 2) return null;

    String cleanTableLine(String l) {
      var s = l.trim();
      if (s.startsWith('|')) s = s.substring(1);
      if (s.endsWith('|')) s = s.substring(0, s.length - 1);
      return s;
    }

    // Header line
    final headers = cleanTableLine(lines[0])
        .split('|')
        .map((s) => s.trim())
        .toList();
    if (headers.isEmpty) return null;

    // Skip separator line (e.g. |---|---|)
    int startIdx = 1;
    if (lines.length > 1 && lines[1].contains('---')) {
      startIdx = 2;
    }

    final List<List<String>> rows = [];
    for (int i = startIdx; i < lines.length; i++) {
      final cells = cleanTableLine(lines[i])
          .split('|')
          .map((s) => s.trim())
          .toList();
      if (cells.isNotEmpty) {
        rows.add(cells);
      }
    }

    return _TableData(headers: headers, rows: rows);
  }
}

enum _BlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  bullet,
  numbered,
  checklist,
  table,
  diagram,
  graph,
  visualFlow,
  formula,
  derivation,
  code,
  callout,
  comparison,
  divider,
}

class _AiBlock {
  final _BlockType type;
  final String text;
  final String? extra;

  const _AiBlock({
    required this.type,
    required this.text,
    this.extra,
  });
}

class _DeferredAiBlock extends StatefulWidget {
  final String label;
  final Widget Function() builder;

  const _DeferredAiBlock({
    required this.label,
    required this.builder,
  });

  @override
  State<_DeferredAiBlock> createState() => _DeferredAiBlockState();
}

class _DeferredAiBlockState extends State<_DeferredAiBlock> {
  bool _isRendered = false;

  @override
  Widget build(BuildContext context) {
    if (!_isRendered) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _isRendered = true),
          icon: const Icon(Icons.account_tree_outlined, size: 18),
          label: Text(widget.label),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.builder(),
        TextButton(
          onPressed: () => setState(() => _isRendered = false),
          child: const Text('Hide diagram'),
        ),
      ],
    );
  }
}

class _TableData {
  final List<String> headers;
  final List<List<String>> rows;

  const _TableData({
    required this.headers,
    required this.rows,
  });
}

/// Dynamic pulsing cursor indicator shown during live AI response streaming
class _StreamingPulseCursor extends StatefulWidget {
  const _StreamingPulseCursor();

  @override
  State<_StreamingPulseCursor> createState() => _StreamingPulseCursorState();
}

class _StreamingPulseCursorState extends State<_StreamingPulseCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF6366F1),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'Streaming response...',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6366F1),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Auto-scrolls the currently active spoken sentence/block into the student's viewport
class _AutoScrollBlockWrapper extends StatefulWidget {
  final Widget child;
  final bool isSpeakingActive;

  const _AutoScrollBlockWrapper({
    required this.child,
    required this.isSpeakingActive,
  });

  @override
  State<_AutoScrollBlockWrapper> createState() => _AutoScrollBlockWrapperState();
}

class _AutoScrollBlockWrapperState extends State<_AutoScrollBlockWrapper> {
  @override
  void initState() {
    super.initState();
    if (widget.isSpeakingActive) {
      _scrollToSelf();
    }
  }

  @override
  void didUpdateWidget(covariant _AutoScrollBlockWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeakingActive && !oldWidget.isSpeakingActive) {
      _scrollToSelf();
    }
  }

  void _scrollToSelf() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
          alignment: 0.35, // Smoothly centers in the upper-middle viewport
        );
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
