import 'package:flutter/material.dart';

import '../../gym/models/gym.dart';
import '../../gym/models/gym_class.dart';
import '../../gym/models/gym_schedule.dart';
import '../../gym/services/gym_class_service.dart';
import 'gym_class_dialogs.dart';

/// Clases grupales en el portal (dueño y entrenadores de planta): próximas
/// clases con sus inscritos, y horarios semanales.
class GymClassesSection extends StatelessWidget {
  final Gym gym;

  const GymClassesSection({required this.gym, super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.event_note), text: 'Próximas clases'),
              Tab(icon: Icon(Icons.repeat), text: 'Horarios'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _UpcomingClasses(gym: gym),
                _Schedules(gym: gym),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> _confirm(BuildContext context, String title, String body,
    {String action = 'Confirmar'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dctx, false),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Contenido centrado con ancho máximo y un botón de acción arriba.
class _Page extends StatelessWidget {
  final Widget header;
  final List<Widget> children;

  const _Page({required this.header, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, const SizedBox(height: 8), ...children],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Próximas clases ──────────────────────────────────────────────────────

class _UpcomingClasses extends StatefulWidget {
  final Gym gym;

  const _UpcomingClasses({required this.gym});

  @override
  State<_UpcomingClasses> createState() => _UpcomingClassesState();
}

class _UpcomingClassesState extends State<_UpcomingClasses>
    with AutomaticKeepAliveClientMixin {
  late final Stream<List<GymClass>> _classes =
      GymClassService().watchClasses(widget.gym.id);

  @override
  bool get wantKeepAlive => true;

  Future<void> _create() async {
    final c = await showDialog<GymClass>(
      context: context,
      builder: (_) => GymClassDialog(gymId: widget.gym.id),
    );
    if (c == null) return;
    try {
      await GymClassService().createClass(c);
      if (mounted) _showMessage(context, 'Clase creada.');
    } catch (e) {
      if (mounted) _showMessage(context, 'No se pudo crear la clase: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<GymClass>>(
      stream: _classes,
      builder: (context, snap) {
        final header = Row(
          children: [
            Expanded(
              child: Text(
                'Próximos ${GymClassService.daysAhead} días · hora de Colombia',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Clase suelta'),
            ),
          ],
        );
        if (snap.hasError) {
          return _Page(header: header, children: [
            Text('No se pudieron cargar las clases: ${snap.error}'),
          ]);
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final now = DateTime.now().toUtc();
        final classes = snap.data!.where((c) => c.endsAt.isAfter(now));
        final byDay = <String, List<GymClass>>{};
        for (final c in classes) {
          byDay
              .putIfAbsent(BogotaTime.dayLabel(c.startsAtBogota), () => [])
              .add(c);
        }

        return _Page(header: header, children: [
          if (byDay.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                'No hay clases programadas. Crea un horario en la pestaña '
                '"Horarios" (las clases aparecen en unos segundos) o una '
                'clase suelta.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          for (final entry in byDay.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Text(entry.key,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            for (final c in entry.value)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: Text(BogotaTime.hhmm(c.startsAtBogota),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  title: Text(
                    c.name,
                    style: TextStyle(
                      decoration:
                          c.isCancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text([
                    c.timeRange,
                    if (c.instructor.isNotEmpty) c.instructor,
                    if (c.scheduleId == null) 'suelta',
                    if (c.edited && c.scheduleId != null) 'editada',
                  ].join(' · ')),
                  trailing: c.isCancelled
                      ? const Chip(label: Text('Cancelada'))
                      : Text('${c.enrolledCount}/${c.capacity}',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: c.isFull
                                  ? Colors.orange[800]
                                  : Colors.green[700])),
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) =>
                        _ClassDetailDialog(gym: widget.gym, gymClass: c),
                  ),
                ),
              ),
          ],
        ]);
      },
    );
  }
}

/// Detalle de una clase: inscritos (con retirar) y acciones del staff.
class _ClassDetailDialog extends StatefulWidget {
  final Gym gym;
  final GymClass gymClass;

  const _ClassDetailDialog({required this.gym, required this.gymClass});

  @override
  State<_ClassDetailDialog> createState() => _ClassDetailDialogState();
}

class _ClassDetailDialogState extends State<_ClassDetailDialog> {
  final _service = GymClassService();
  late final Stream<List<GymEnrollment>> _enrollments =
      _service.watchEnrollments(widget.gym.id, widget.gymClass.id);
  bool _busy = false;

  GymClass get c => widget.gymClass;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        _showMessage(context, done);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showMessage(context, 'No se pudo completar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final edited = await showDialog<GymClass>(
      context: context,
      builder: (_) => GymClassDialog(gymId: widget.gym.id, existing: c),
    );
    if (edited == null) return;
    await _run(() => _service.updateClass(edited), 'Clase actualizada.');
  }

  Future<void> _toggleCancel() async {
    final cancelling = !c.isCancelled;
    if (cancelling &&
        !await _confirm(
          context,
          'Cancelar clase',
          c.enrolledCount > 0
              ? 'Los ${c.enrolledCount} inscritos la verán como cancelada en la app.'
              : '¿Cancelar ${c.name}?',
          action: 'Cancelar clase',
        )) {
      return;
    }
    await _run(() => _service.setCancelled(c, cancelling),
        cancelling ? 'Clase cancelada.' : 'Clase reactivada.');
  }

  Future<void> _delete() async {
    if (!await _confirm(context, 'Eliminar clase', '¿Eliminar ${c.name}?',
        action: 'Eliminar')) {
      return;
    }
    await _run(() => _service.deleteClass(c), 'Clase eliminada.');
  }

  Future<void> _remove(GymEnrollment e) async {
    if (!await _confirm(context, 'Retirar de la clase',
        '¿Retirar a ${e.email} de ${c.name}? Su cupo queda libre.',
        action: 'Retirar')) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.removeEnrollment(c, e.uid);
    } catch (err) {
      if (mounted) _showMessage(context, 'No se pudo retirar: $err');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final started = !c.startsAt.isAfter(DateTime.now().toUtc());
    return AlertDialog(
      title: Text(c.name),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${BogotaTime.dayLabel(c.startsAtBogota)} · ${c.timeRange}'),
            if (c.instructor.isNotEmpty) Text('Instructor: ${c.instructor}'),
            if (c.description.isNotEmpty)
              Text(c.description, style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 16),
            Text('Inscritos',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Flexible(
              child: StreamBuilder<List<GymEnrollment>>(
                stream: _enrollments,
                builder: (context, snap) {
                  if (snap.hasError) return Text('Error: ${snap.error}');
                  if (!snap.hasData) return const LinearProgressIndicator();
                  final list = snap.data!;
                  if (list.isEmpty) {
                    return Text('Nadie inscrito todavía.',
                        style: TextStyle(color: Colors.grey[600]));
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      Text('${list.length} de ${c.capacity} cupos',
                          style: TextStyle(color: Colors.grey[700])),
                      for (final (i, e) in list.indexed)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                              radius: 14,
                              child: Text('${i + 1}',
                                  style: const TextStyle(fontSize: 12))),
                          title: Text(e.email),
                          trailing: started
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.person_remove_outlined),
                                  tooltip: 'Retirar',
                                  onPressed: _busy ? null : () => _remove(e),
                                ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!started) ...[
          if (c.enrolledCount == 0)
            TextButton(
              onPressed: _busy ? null : _delete,
              child: const Text('Eliminar'),
            ),
          TextButton(
            onPressed: _busy ? null : _toggleCancel,
            child: Text(c.isCancelled ? 'Reactivar' : 'Cancelar clase'),
          ),
          TextButton(
            onPressed: _busy ? null : _edit,
            child: const Text('Editar'),
          ),
        ],
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

// ── Horarios ─────────────────────────────────────────────────────────────

class _Schedules extends StatefulWidget {
  final Gym gym;

  const _Schedules({required this.gym});

  @override
  State<_Schedules> createState() => _SchedulesState();
}

class _SchedulesState extends State<_Schedules>
    with AutomaticKeepAliveClientMixin {
  final _service = GymClassService();
  late final Stream<List<GymSchedule>> _schedules =
      _service.watchSchedules(widget.gym.id);

  @override
  bool get wantKeepAlive => true;

  Future<void> _edit([GymSchedule? existing]) async {
    final s = await showDialog<GymSchedule>(
      context: context,
      builder: (_) => ScheduleDialog(existing: existing),
    );
    if (s == null) return;
    try {
      await _service.saveSchedule(widget.gym.id, s);
      if (mounted) {
        _showMessage(context,
            'Horario guardado. Las clases se actualizan en unos segundos.');
      }
    } catch (e) {
      if (mounted) _showMessage(context, 'No se pudo guardar: $e');
    }
  }

  Future<void> _delete(GymSchedule s) async {
    if (!await _confirm(
      context,
      'Eliminar horario',
      'Se quitan las próximas clases de "${s.name}" sin inscritos y se '
          'cancelan las que ya tienen inscritos. Las clases que editaste a '
          'mano se mantienen.',
      action: 'Eliminar',
    )) {
      return;
    }
    try {
      await _service.deleteSchedule(widget.gym.id, s.id);
    } catch (e) {
      if (mounted) _showMessage(context, 'No se pudo eliminar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<GymSchedule>>(
      stream: _schedules,
      builder: (context, snap) {
        final header = Row(
          children: [
            Expanded(
              child: Text(
                'Las clases de cada horario se generan para los próximos '
                '${GymClassService.daysAhead} días.',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Horario'),
            ),
          ],
        );
        if (snap.hasError) {
          return _Page(header: header, children: [
            Text('No se pudieron cargar los horarios: ${snap.error}'),
          ]);
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        return _Page(header: header, children: [
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                'Aún no hay horarios. Ejemplo: Spinning, lunes, miércoles y '
                'viernes a las 6:00, 45 min, 20 cupos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          for (final s in list)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: Text(s.startTime,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: s.active ? null : Colors.grey)),
                title: Text(s.name,
                    style: TextStyle(color: s.active ? null : Colors.grey)),
                subtitle: Text([
                  s.weekdaysLabel,
                  '${s.durationMin} min',
                  '${s.capacity} cupos',
                  if (s.instructor.isNotEmpty) s.instructor,
                  if (!s.active) 'inactivo',
                ].join(' · ')),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar',
                  onPressed: () => _delete(s),
                ),
                onTap: () => _edit(s),
              ),
            ),
        ]);
      },
    );
  }
}
