import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fact.dart';
import '../state/memo_controller.dart';
import '../widgets/page_frame.dart';

class FactFormScreen extends StatefulWidget {
  const FactFormScreen({super.key, required this.deckId, this.existing});

  final String deckId;
  final Fact? existing;

  @override
  State<FactFormScreen> createState() => _FactFormScreenState();
}

class _FactFormScreenState extends State<FactFormScreen> {
  late final _prompt = TextEditingController(text: widget.existing?.prompt);
  late final _answer = TextEditingController(text: widget.existing?.answer);
  late final _source = TextEditingController(text: widget.existing?.source);
  var _saving = false;

  @override
  void dispose() {
    _prompt.dispose();
    _answer.dispose();
    _source.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prompt = _prompt.text.trim();
    final answer = _answer.text.trim();
    if (prompt.isEmpty || answer.isEmpty) return;
    setState(() => _saving = true);
    final controller = context.read<MemoController>();
    final existing = widget.existing;
    if (existing == null) {
      await controller.createFact(
        deckId: widget.deckId,
        prompt: prompt,
        answer: answer,
        source: _source.text,
      );
    } else {
      await controller.updateFact(
        existing.copyWith(
          prompt: prompt,
          answer: answer,
          source: _source.text,
        ),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar carta'),
        content: const Text('Esta carta desaparecerá del mazo y del repaso.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<MemoController>().deleteFact(existing.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar carta' : 'Nueva carta'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Eliminar',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: PageFrame(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _prompt,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Frente (pregunta)',
                hintText: 'Puerto HTTPS',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _answer,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Dorso (respuesta)',
                hintText: '443',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _source,
              decoration: const InputDecoration(
                labelText: 'Fuente (opcional)',
                hintText: 'LPACAP art. 122 · IANA',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(editing ? 'Guardar' : 'Añadir carta'),
            ),
          ],
        ),
      ),
    );
  }
}
