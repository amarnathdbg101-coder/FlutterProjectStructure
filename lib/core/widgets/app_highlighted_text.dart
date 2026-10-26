import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Reusable Keyword Match Highlighting Widget for Search Results.
/// Highlights matching search query tokens within product names, SKUs, or categories.
/// Zero-dependency, lightweight, 100% native Flutter TextSpan architecture.
class AppHighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow overflow;

  const AppHighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty || text.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final tokens = cleanQuery
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final lowerText = text.toLowerCase();
    final List<_MatchInterval> intervals = [];

    // Find all matches for each token
    for (final token in tokens) {
      int start = 0;
      while (start < lowerText.length) {
        final index = lowerText.indexOf(token, start);
        if (index == -1) break;
        intervals.add(_MatchInterval(index, index + token.length));
        start = index + 1; // Slide forward
      }
    }

    if (intervals.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // Sort and merge overlapping intervals
    intervals.sort((a, b) => a.start.compareTo(b.start));
    final List<_MatchInterval> merged = [];
    _MatchInterval current = intervals.first;

    for (int i = 1; i < intervals.length; i++) {
      final next = intervals[i];
      if (next.start <= current.end) {
        current = _MatchInterval(
          current.start,
          next.end > current.end ? next.end : current.end,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);

    // Build TextSpans
    final defaultStyle = style ?? const TextStyle(fontSize: 13, color: Colors.black87);
    final activeHighlightStyle = highlightStyle ??
        defaultStyle.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        );

    final List<TextSpan> spans = [];
    int lastPos = 0;

    for (final interval in merged) {
      if (interval.start > lastPos) {
        spans.add(TextSpan(
          text: text.substring(lastPos, interval.start),
          style: defaultStyle,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(interval.start, interval.end),
        style: activeHighlightStyle,
      ));
      lastPos = interval.end;
    }

    if (lastPos < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastPos),
        style: defaultStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class _MatchInterval {
  final int start;
  final int end;
  const _MatchInterval(this.start, this.end);
}
