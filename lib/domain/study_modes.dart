import 'package:flutter/material.dart';

enum StudyModeStatus { ready, coming }

class StudyMode {
  const StudyMode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.status,
    required this.tint,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final StudyModeStatus status;
  final Color tint;

  bool get isReady => status == StudyModeStatus.ready;
}

/// Catálogo de modos. Añadir un juego nuevo es una entrada aquí.
abstract final class StudyModes {
  static const flip = 'flip';
  static const match = 'match';
  static const cloze = 'cloze';
  static const trueFalse = 'trueFalse';

  static const catalog = <StudyMode>[
    StudyMode(
      id: flip,
      title: 'Tarjetas',
      subtitle: 'Voltea la carta y di si la sabías. Mazos por ley y por tema.',
      icon: Icons.style_outlined,
      status: StudyModeStatus.ready,
      tint: Color(0xFF0F766E),
    ),
    StudyMode(
      id: cloze,
      title: 'Huecos',
      subtitle: 'Elige las palabras y completa la frase. Si fallas, vuelve a salir.',
      icon: Icons.space_bar,
      status: StudyModeStatus.ready,
      tint: Color(0xFFB45309),
    ),
    StudyMode(
      id: match,
      title: 'Relacionar',
      subtitle: 'Empareja término y definición del mismo mazo. Toque-toque, sin flechas.',
      icon: Icons.hub_outlined,
      status: StudyModeStatus.ready,
      tint: Color(0xFF1D4ED8),
    ),
    StudyMode(
      id: trueFalse,
      title: 'Verdadero o falso',
      subtitle: 'Afirmaciones precisas para cazar trampas de examen.',
      icon: Icons.rule,
      status: StudyModeStatus.coming,
      tint: Color(0xFF7C3AED),
    ),
  ];
}
