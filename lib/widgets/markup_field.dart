import 'package:flutter/material.dart';

import '../domain/memo_markup.dart';

class MarkupField extends StatefulWidget {
  const MarkupField({
    super.key,
    required this.controller,
    required this.decoration,
    this.maxLines = 4,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final int maxLines;
  final TextCapitalization textCapitalization;

  @override
  State<MarkupField> createState() => _MarkupFieldState();
}

class _MarkupFieldState extends State<MarkupField> {
  TextSelection _saved = const TextSelection.collapsed(offset: 0);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_remember);
  }

  @override
  void didUpdateWidget(MarkupField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_remember);
    widget.controller.addListener(_remember);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_remember);
    super.dispose();
  }

  void _remember() {
    final selection = widget.controller.selection;
    if (selection.isValid && !selection.isCollapsed) {
      _saved = selection;
    }
  }

  void _apply(String marker) {
    final current = widget.controller.selection;
    if (!current.isValid || current.isCollapsed) {
      final fallback = _saved;
      if (fallback.isValid && !fallback.isCollapsed && fallback.end <= widget.controller.text.length) {
        widget.controller.selection = fallback;
      }
    }
    MemoMarkup.wrap(widget.controller, marker);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          maxLines: widget.maxLines,
          textCapitalization: widget.textCapitalization,
          decoration: widget.decoration,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            ExcludeFocus(
              child: IconButton(
                tooltip: 'Negrita',
                visualDensity: VisualDensity.compact,
                onPressed: () => _apply('**'),
                icon: const Icon(Icons.format_bold),
              ),
            ),
            ExcludeFocus(
              child: IconButton(
                tooltip: 'Cursiva',
                visualDensity: VisualDensity.compact,
                onPressed: () => _apply('*'),
                icon: const Icon(Icons.format_italic),
              ),
            ),
            Expanded(
              child: Text(
                'Selecciona una palabra y márcala. **negrita** o *cursiva*.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
