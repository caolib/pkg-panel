import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef LinkTapCallback = Future<void> Function(String url);

final RegExp _detectedUrlPattern = RegExp(
  r"""((?:https?:\/\/|www\.)[^\s<>"'`]+)""",
  caseSensitive: false,
);

class LinkifiedSelectableText extends StatefulWidget {
  const LinkifiedSelectableText({
    super.key,
    required this.text,
    this.style,
    this.onOpenLink,
  });

  final String text;
  final TextStyle? style;
  final LinkTapCallback? onOpenLink;

  @override
  State<LinkifiedSelectableText> createState() =>
      _LinkifiedSelectableTextState();
}

class _LinkifiedSelectableTextState extends State<LinkifiedSelectableText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final linkColor = theme.colorScheme.primary;
    final linkStyle = baseStyle.copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );

    return SelectableText.rich(
      TextSpan(
        style: baseStyle,
        children: _buildTextSpans(linkStyle: linkStyle),
      ),
    );
  }

  List<InlineSpan> _buildTextSpans({required TextStyle linkStyle}) {
    _disposeRecognizers();

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in _detectedUrlPattern.allMatches(widget.text)) {
      final rawMatch = match.group(0);
      if (rawMatch == null || rawMatch.isEmpty) {
        continue;
      }

      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }

      final normalized = _normalizeLink(rawMatch);
      if (normalized.linkText.isEmpty) {
        spans.add(TextSpan(text: rawMatch));
        cursor = match.end;
        continue;
      }

      final onOpenLink = widget.onOpenLink;
      if (onOpenLink == null) {
        spans.add(TextSpan(text: rawMatch));
      } else {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            unawaited(onOpenLink(normalized.targetUrl));
          };
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: normalized.linkText,
            style: linkStyle,
            recognizer: recognizer,
            mouseCursor: SystemMouseCursors.click,
          ),
        );
        if (normalized.trailingText.isNotEmpty) {
          spans.add(TextSpan(text: normalized.trailingText));
        }
      }

      cursor = match.end;
    }

    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: widget.text));
    }

    return spans;
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }
}

_NormalizedLink _normalizeLink(String rawMatch) {
  var linkText = rawMatch;
  var trailingText = '';

  while (linkText.isNotEmpty) {
    final lastCharacter = linkText[linkText.length - 1];
    if (_shouldTrimTrailingCharacter(linkText, lastCharacter)) {
      trailingText = '$lastCharacter$trailingText';
      linkText = linkText.substring(0, linkText.length - 1);
      continue;
    }
    break;
  }

  final targetUrl = linkText.startsWith('www.')
      ? 'https://$linkText'
      : linkText;
  return _NormalizedLink(
    linkText: linkText,
    targetUrl: targetUrl,
    trailingText: trailingText,
  );
}

bool _shouldTrimTrailingCharacter(String value, String trailingCharacter) {
  if ('.;,:!?'.contains(trailingCharacter)) {
    return true;
  }
  return switch (trailingCharacter) {
    ')' => _countCharacter(value, ')') > _countCharacter(value, '('),
    ']' => _countCharacter(value, ']') > _countCharacter(value, '['),
    '}' => _countCharacter(value, '}') > _countCharacter(value, '{'),
    _ => false,
  };
}

int _countCharacter(String value, String character) {
  return value.split(character).length - 1;
}

class _NormalizedLink {
  const _NormalizedLink({
    required this.linkText,
    required this.targetUrl,
    required this.trailingText,
  });

  final String linkText;
  final String targetUrl;
  final String trailingText;
}
