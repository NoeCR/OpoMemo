import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/deck.dart';
import '../state/memo_controller.dart';
import '../widgets/page_frame.dart';

class DeckFormScreen extends StatefulWidget {
  const DeckFormScreen({super.key, this.existing, this.initialGroup});

  final Deck? existing;
  final String? initialGroup;

  @override
  State<DeckFormScreen> createState() => _DeckFormScreenState();
}

class _DeckFormScreenState extends State<DeckFormScreen> {
  static const _newSection = '__new_section__';

  late final _name = TextEditingController(text: widget.existing?.name);
  late final _description = TextEditingController(text: widget.existing?.description);
  late final _newGroup = TextEditingController();
  late DeckDomain _domain = widget.existing?.domain ?? DeckDomain.info;
  late String _groupChoice;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final fromExisting = widget.existing?.groupName.trim();
    if (fromExisting != null && fromExisting.isNotEmpty) {
      _groupChoice = fromExisting;
      return;
    }
    final initial = widget.initialGroup?.trim();
    _groupChoice = (initial != null && initial.isNotEmpty) ? initial : Deck.defaultGroup;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _newGroup.dispose();
    super.dispose();
  }

  String? _resolvedGroup() {
    if (_groupChoice == _newSection) {
      final custom = _newGroup.text.trim();
      if (custom.isEmpty) return null;
      return custom;
    }
    final name = _groupChoice.trim();
    return name.isEmpty ? Deck.defaultGroup : name;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final groupName = _resolvedGroup();
    if (name.isEmpty || groupName == null) return;
    setState(() => _saving = true);
    final controller = context.read<MemoController>();
    final existing = widget.existing;
    if (existing == null) {
      await controller.createDeck(
        name: name,
        description: _description.text,
        domain: _domain,
        groupName: groupName,
      );
    } else {
      await controller.updateDeck(
        existing.copyWith(
          name: name,
          description: _description.text,
          domain: _domain,
          groupName: groupName,
        ),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final names = [
      ...context.watch<MemoController>().groupNames,
    ];
    if (_groupChoice != _newSection && !names.contains(_groupChoice)) {
      names.add(_groupChoice);
    }
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
            DropdownButtonFormField<String>(
              value: _groupChoice,
              decoration: const InputDecoration(labelText: 'Sección'),
              items: [
                for (final name in names)
                  DropdownMenuItem(value: name, child: Text(name)),
                const DropdownMenuItem(
                  value: _newSection,
                  child: Text('Nueva sección…'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _groupChoice = value);
              },
            ),
            if (_groupChoice == _newSection) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _newGroup,
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la sección',
                  hintText: 'Plazos · Recursos',
                ),
              ),
            ],
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
