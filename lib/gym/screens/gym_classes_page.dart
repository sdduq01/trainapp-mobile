import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/gym.dart';
import '../models/gym_class.dart';
import '../services/gym_class_service.dart';
import '../widgets/gym_logo.dart';

/// Clases grupales del gimnasio para los próximos 14 días (se abre tocando el
/// logo en el home). Los atletas se inscriben y cancelan; los entrenadores de
/// planta solo las ven (las administran en el portal).
class GymClassesPage extends StatefulWidget {
  final Gym gym;
  final bool canEnroll;

  const GymClassesPage({required this.gym, required this.canEnroll, super.key});

  @override
  State<GymClassesPage> createState() => _GymClassesPageState();
}

class _GymClassesPageState extends State<GymClassesPage> {
  final _service = GymClassService();
  late final Stream<List<GymClass>> _classes;
  late final Stream<Set<String>> _mine;
  bool _onlyMine = false;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _classes = _service.watchClasses(widget.gym.id);
    _mine = widget.canEnroll
        ? _service.watchMyEnrolledClassIds(
            FirebaseAuth.instance.currentUser!.uid)
        : Stream.value(const <String>{});
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggle(GymClass c, bool enrolled) async {
    if (enrolled) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('Cancelar inscripción'),
          content: Text('¿Liberar tu cupo en ${c.name} '
              '(${BogotaTime.dayLabel(c.startsAtBogota)}, ${c.timeRange})?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Sí, cancelar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _busy.add(c.id));
    try {
      if (enrolled) {
        await _service.unenroll(c);
        if (mounted) _showMessage('Inscripción cancelada.');
      } else {
        await _service.enroll(c);
        if (mounted) _showMessage('¡Listo! Quedaste inscrito en ${c.name}.');
      }
    } on Exception catch (e) {
      if (mounted) _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy.remove(c.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            GymLogo(url: widget.gym.logoUrl, size: 32),
            const SizedBox(width: 12),
            const Expanded(child: Text('Clases grupales')),
          ],
        ),
      ),
      body: StreamBuilder<List<GymClass>>(
        stream: _classes,
        builder: (context, classesSnap) => StreamBuilder<Set<String>>(
          stream: _mine,
          builder: (context, mineSnap) {
            if (classesSnap.hasError || mineSnap.hasError) {
              return _Message(
                'No se pudieron cargar las clases.\n'
                '${classesSnap.error ?? mineSnap.error}',
              );
            }
            if (!classesSnap.hasData || !mineSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildList(classesSnap.data!, mineSnap.data!);
          },
        ),
      ),
    );
  }

  Widget _buildList(List<GymClass> all, Set<String> mine) {
    final now = DateTime.now().toUtc();
    // Se dejan las que están en curso; las terminadas no.
    var classes = all.where((c) => c.endsAt.isAfter(now)).toList();
    if (_onlyMine) classes = classes.where((c) => mine.contains(c.id)).toList();

    final byDay = <String, List<GymClass>>{};
    for (final c in classes) {
      byDay.putIfAbsent(BogotaTime.dayLabel(c.startsAtBogota), () => []).add(c);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (widget.canEnroll)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: !_onlyMine,
                  onSelected: (_) => setState(() => _onlyMine = false),
                ),
                ChoiceChip(
                  label: Text('Mis clases (${mine.length})'),
                  selected: _onlyMine,
                  onSelected: (_) => setState(() => _onlyMine = true),
                ),
              ],
            ),
          ),
        Text(
          'Horarios en hora de Colombia. Puedes cancelar hasta '
          '${widget.gym.cancelWindowHours} h antes de cada clase.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        if (byDay.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Text(
              _onlyMine
                  ? 'No estás inscrito en ninguna clase.'
                  : 'El gimnasio aún no tiene clases programadas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        for (final entry in byDay.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: Text(entry.key,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          for (final c in entry.value)
            _ClassCard(
              gymClass: c,
              enrolled: mine.contains(c.id),
              canEnroll: widget.canEnroll,
              cancelWindowHours: widget.gym.cancelWindowHours,
              busy: _busy.contains(c.id),
              onToggle: () => _toggle(c, mine.contains(c.id)),
            ),
        ],
      ],
    );
  }
}

class _ClassCard extends StatelessWidget {
  final GymClass gymClass;
  final bool enrolled;
  final bool canEnroll;
  final int cancelWindowHours;
  final bool busy;
  final VoidCallback onToggle;

  const _ClassCard({
    required this.gymClass,
    required this.enrolled,
    required this.canEnroll,
    required this.cancelWindowHours,
    required this.busy,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = gymClass;
    final now = DateTime.now().toUtc();
    final started = !c.startsAt.isAfter(now);
    final canCancel = now.isBefore(c.cancelDeadline(cancelWindowHours));
    final scheme = Theme.of(context).colorScheme;

    final String spots;
    final Color spotsColor;
    if (c.isCancelled) {
      spots = 'Cancelada';
      spotsColor = Colors.red;
    } else if (c.isFull) {
      spots = 'Llena (${c.capacity})';
      spotsColor = Colors.orange[800]!;
    } else {
      spots = '${c.freeSpots} de ${c.capacity} cupos libres';
      spotsColor = Colors.green[700]!;
    }

    Widget? action;
    if (canEnroll && !c.isCancelled && !started) {
      if (enrolled) {
        action = canCancel
            ? OutlinedButton(
                onPressed: busy ? null : onToggle,
                child: const Text('Cancelar'),
              )
            : Text('No cancelable\n(menos de $cancelWindowHours h)',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]));
      } else if (!c.isFull) {
        action = FilledButton(
          onPressed: busy ? null : onToggle,
          child: const Text('Inscribirme'),
        );
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: enrolled
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.primary, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration:
                          c.isCancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      c.timeRange,
                      if (c.instructor.isNotEmpty) c.instructor,
                    ].join(' · '),
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  if (c.description.isNotEmpty)
                    Text(c.description,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (enrolled) ...[
                        Icon(Icons.check_circle,
                            size: 16, color: scheme.primary),
                        const SizedBox(width: 4),
                        Text('Inscrito · ',
                            style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600)),
                      ],
                      Flexible(
                        child: Text(spots,
                            style: TextStyle(
                                color: spotsColor,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 12),
              busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : action,
            ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;

  const _Message(this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}
