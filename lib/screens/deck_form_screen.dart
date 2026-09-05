import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deck.dart';
import '../state/memo_controller.dart';
import '../widgets/page_frame.dart';

class DeckFormScreen extends StatefulWidget {
  const DeckFormScreen({super.key, this.existing});

  final Deck? existing;

  @override
  State<DeckFormScreen> createState() => _DeckFormScreenState();
}

class _DeckFormScreenState extends State<DeckFormScreen> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _description = TextEditingController(text: widget.existing?.description);
  late DeckDomain _domain = widget.existing?.domain ?? DeckDomain.info;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final controller = context.read<MemoController>();
    final existing = widget.existing;
    if (existing == null) {
      await controller.createDeck(
        name: name,
        description: _description.text,
        domain: _domain,
      );
    } else {
      await controller.updateDeck(
        existing.copyWith(
          name: name,
          description: _description.text,
          domain: _domain,
        ),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar mazo' : 'Nuevo mazo')),
      body: PageFrame(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'LPACAP · Título III',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<DeckDomain>(
              value: _domain,
              decoration: const InputDecoration(labelText: 'Dominio'),
              items: [
                for (final domain in DeckDomain.values)
                  DropdownMenuItem(value: domain, child: Text(domain.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _domain = value);
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(editing ? 'Guardar' : 'Crear mazo'),
            ),
          ],
        ),
      ),
    );
  }
}
