import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/study_modes.dart';
import '../state/memo_controller.dart';
import '../state/session_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/page_frame.dart';
import 'flip_session_screen.dart';
import 'hub_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final due = context.watch<MemoController>().summaries.fold<int>(
          0,
          (sum, item) => sum + item.dueCount,
        );
    final sessionSize = context.watch<SessionSettings>().size;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/branding/opomemo_icon.png',
                width: 32,
                height: 32,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(width: 10),
            const Text('OpoMemo'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => showSessionSizePicker(context),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: PageFrame(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _TodayCard(due: due, sessionSize: sessionSize),
            const SizedBox(height: 20),
            Text(
              'Modos',
              style: TextStyle(
                color: AppTheme.muted(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cada modo usa los mismos mazos. Empieza por tarjetas; el resto se irá abriendo.',
              style: TextStyle(fontSize: 16, height: 1.35),
            ),
            const SizedBox(height: 16),
            for (final mode in StudyModes.catalog) ...[
              _ModeCard(mode: mode),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.due, required this.sessionSize});

  final int due;
  final int sessionSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card(context),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hoy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    due == 0
                        ? 'Nada pendiente. Vuelve mañana o abre un mazo nuevo.'
                        : '$due pendientes · sesión de $sessionSize',
                    style: TextStyle(color: AppTheme.muted(context)),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: due == 0 ? null : () => FlipSessionScreen.open(context),
              child: const Text('Estudiar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode});

  final StudyMode mode;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: AppTheme.card(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (mode.isReady) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HubScreen()),
            );
            return;
          }
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (context) => Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mode.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(mode.subtitle),
                  const SizedBox(height: 12),
                  const Text(
                    'Cuando lo implementemos, reutilizará los mazos que ya estás repasando. No hay que crear el contenido otra vez.',
                  ),
                ],
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: mode.tint.withValues(alpha: mode.isReady ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(mode.icon, color: mode.isReady ? mode.tint : onSurface.withValues(alpha: 0.38)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mode.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: mode.isReady ? onSurface : onSurface.withValues(alpha: 0.54),
                            ),
                          ),
                        ),
                        if (!mode.isReady)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: onSurface.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Próximamente',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode.subtitle,
                      style: TextStyle(color: AppTheme.muted(context)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
