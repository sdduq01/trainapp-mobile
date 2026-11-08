import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../gym/models/gym_class.dart';
import '../../gym/models/gym_schedule.dart';

String _hhmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _parseTime(String hhmm) {
  final parts = hhmm.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

/// Campos comunes de horario y clase: nombre, instructor, descripción,
/// duración y cupo.
class _CommonFields extends StatelessWidget {
  final TextEditingController name;
  final TextEditingController instructor;
  final TextEditingController description;
  final TextEditingController duration;
  final TextEditingController capacity;
  final int minCapacity;

  const _CommonFields({
    required this.name,
    required this.instructor,
    required this.description,
    required this.duration,
    required this.capacity,
    this.minCapacity = 1,
  });

  static String? _intIn(String? v, int min, int max, String label) {
    final n = int.tryParse(v ?? '');
    if (n == null || n < min || n > max) return '$label entre $min y $max';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Column(
      children: [
        TextFormField(
          controller: name,
          decoration: const InputDecoration(
              labelText: 'Nombre de la clase', hintText: 'Spinning, Yoga…'),
          maxLength: 80,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Escribe un nombre' : null,
        ),
        TextFormField(
          controller: instructor,
          decoration: const InputDecoration(labelText: 'Instructor (opcional)'),
        ),
        TextFormField(
          controller: description,
          decoration: const InputDecoration(
              labelText: 'Descripción (opcional)', hintText: 'Salón 2, traer toalla…'),
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: duration,
                decoration: const InputDecoration(
                    labelText: 'Duración', suffixText: 'min'),
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                validator: (v) => _intIn(v, 5, 600, 'Duración'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: capacity,
                decoration: const InputDecoration(labelText: 'Cupos'),
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                validator: (v) => _intIn(v, minCapacity, 500, 'Cupos'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Crear o editar un horario semanal. Devuelve el horario o null.
class ScheduleDialog extends StatefulWidget {
  final GymSchedule? existing;

  const ScheduleDialog({this.existing, super.key});

  @override
  State<ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<ScheduleDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _instructor =
      TextEditingController(text: widget.existing?.instructor);
  late final _description =
      TextEditingController(text: widget.existing?.description);
  late final _duration = TextEditingController(
      text: '${widget.existing?.durationMin ?? 60}');
  late final _capacity =
      TextEditingController(text: '${widget.existing?.capacity ?? 20}');
  late final Set<int> _weekdays = {...?widget.existing?.weekdays};
  late TimeOfDay _time = _parseTime(widget.existing?.startTime ?? '06:00');
  late bool _active = widget.existing?.active ?? true;
  bool _showDaysError = false;

  @override
  void dispose() {
    for (final c in [_name, _instructor, _description, _duration, _capacity]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final validForm = _form.currentState!.validate();
    setState(() => _showDaysError = _weekdays.isEmpty);
    if (!validForm || _weekdays.isEmpty) return;
    Navigator.pop(
      context,
      GymSchedule(
        id: widget.existing?.id ?? '',
        name: _name.text,
        instructor: _instructor.text,
        description: _description.text,
        weekdays: _weekdays.toList()..sort(),
        startTime: _hhmm(_time),
        durationMin: int.parse(_duration.text),
        capacity: int.parse(_capacity.text),
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuevo horario' : 'Editar horario'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CommonFields(
                  name: _name,
                  instructor: _instructor,
                  description: _description,
                  duration: _duration,
                  capacity: _capacity,
                ),
                const SizedBox(height: 16),
                const Text('Se repite los días'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        label: Text(GymSchedule.weekdayLabels[d - 1]),
                        selected: _weekdays.contains(d),
                        onSelected: (on) => setState(() {
                          on ? _weekdays.add(d) : _weekdays.remove(d);
                          if (on) _showDaysError = false;
                        }),
                      ),
                  ],
                ),
                if (_showDaysError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Elige al menos un día',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12)),
                  ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text('Hora de inicio: ${_hhmm(_time)}'),
                  subtitle: const Text('Hora de Colombia'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: _time);
                    if (t != null) setState(() => _time = t);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  subtitle: const Text(
                      'Si lo desactivas, sus próximas clases se quitan '
                      '(o se cancelan si ya tienen inscritos).'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

/// Crear una clase suelta o editar una clase puntual. Devuelve la clase o
/// null.
class GymClassDialog extends StatefulWidget {
  final String gymId;
  final GymClass? existing;

  const GymClassDialog({required this.gymId, this.existing, super.key});

  @override
  State<GymClassDialog> createState() => _GymClassDialogState();
}

class _GymClassDialogState extends State<GymClassDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _instructor =
      TextEditingController(text: widget.existing?.instructor);
  late final _description =
      TextEditingController(text: widget.existing?.description);
  late final _duration = TextEditingController(
      text: '${widget.existing?.durationMin ?? 60}');
  late final _capacity =
      TextEditingController(text: '${widget.existing?.capacity ?? 20}');

  // Fecha y hora en Bogotá (campos de un DateTime UTC "de pared").
  late DateTime _date;
  late TimeOfDay _time;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    final start = widget.existing?.startsAtBogota ??
        BogotaTime.now().add(const Duration(days: 1));
    _date = DateTime(start.year, start.month, start.day);
    _time = widget.existing != null
        ? TimeOfDay(hour: start.hour, minute: start.minute)
        : const TimeOfDay(hour: 6, minute: 0);
  }

  @override
  void dispose() {
    for (final c in [_name, _instructor, _description, _duration, _capacity]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime get _startsAtUtc => BogotaTime.toUtc(
      _date.year, _date.month, _date.day, _time.hour, _time.minute);

  void _save() {
    final validForm = _form.currentState!.validate();
    final inPast = _startsAtUtc.isBefore(DateTime.now().toUtc());
    setState(() => _dateError = inPast ? 'La clase debe ser en el futuro' : null);
    if (!validForm || inPast) return;

    final base = widget.existing ??
        GymClass(
          id: '',
          gymId: widget.gymId,
          name: '',
          startsAt: _startsAtUtc,
          durationMin: 60,
          capacity: 1,
        );
    Navigator.pop(
      context,
      base.copyWith(
        name: _name.text,
        instructor: _instructor.text,
        description: _description.text,
        startsAt: _startsAtUtc,
        durationMin: int.parse(_duration.text),
        capacity: int.parse(_capacity.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return AlertDialog(
      title: Text(existing == null ? 'Nueva clase suelta' : 'Editar clase'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (existing?.scheduleId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Solo cambia esta fecha. Los cambios posteriores del '
                      'horario ya no la modificarán.',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ),
                _CommonFields(
                  name: _name,
                  instructor: _instructor,
                  description: _description,
                  duration: _duration,
                  capacity: _capacity,
                  minCapacity: (existing?.enrolledCount ?? 0).clamp(1, 500),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(BogotaTime.dayLabel(_date)),
                  subtitle: _dateError != null
                      ? Text(_dateError!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))
                      : null,
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final today = BogotaTime.now();
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(today.year, today.month, today.day),
                      lastDate: DateTime(today.year, today.month, today.day)
                          .add(const Duration(days: 90)),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text('Hora de inicio: ${_hhmm(_time)}'),
                  subtitle: const Text('Hora de Colombia'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: _time);
                    if (t != null) setState(() => _time = t);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
