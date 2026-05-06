import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _userId = FirebaseAuth.instance.currentUser!.uid;
  List<_HistoryRow>? _rows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await SessionService().getSessionsForUser(_userId);
    final rows = <_HistoryRow>[];
    for (final session in sessions) {
      for (final exercise in session.exercises) {
        for (final set in exercise.sets) {
          rows.add(_HistoryRow(
            date: session.date,
            dayName: session.dayName,
            exerciseName: exercise.name,
            setNumber: set.setNumber,
            repsDone: set.repsDone,
            weight: set.weight,
            weightUnit: set.weightUnit,
          ));
        }
      }
    }
    if (mounted) setState(() => _rows = rows);
  }

  static String _formatDate(DateTime d) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: switch (_rows) {
        null => const Center(child: CircularProgressIndicator()),
        [] => const Center(
            child: Text('No hay sesiones registradas aún.'),
          ),
        final rows => _buildTable(rows),
      },
    );
  }

  Widget _buildTable(List<_HistoryRow> rows) {
    final colorScheme = Theme.of(context).colorScheme;

    // Colorea filas alternando por sesión (cambio de fecha+día)
    String? lastKey;
    int sessionIdx = 0;
    final sessionIndices = rows.map((row) {
      final key = '${row.date.year}-${row.date.dayOfYear}-${row.dayName}';
      if (key != lastKey) { lastKey = key; sessionIdx++; }
      return sessionIdx;
    }).toList();

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            colorScheme.primaryContainer,
          ),
          dividerThickness: 0.5,
          columnSpacing: 20,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 40,
          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold),
          columns: const [
            DataColumn(label: Text('Fecha')),
            DataColumn(label: Text('Día')),
            DataColumn(label: Text('Ejercicio')),
            DataColumn(label: Text('Serie'), numeric: true),
            DataColumn(label: Text('Reps'), numeric: true),
            DataColumn(label: Text('Peso'), numeric: true),
          ],
          rows: List.generate(rows.length, (i) {
            final row = rows[i];
            final isOdd = sessionIndices[i] % 2 == 1;
            return DataRow(
              color: WidgetStatePropertyAll(
                isOdd
                    ? Colors.transparent
                    : colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
              ),
              cells: [
                DataCell(Text(_formatDate(row.date),
                    style: const TextStyle(fontSize: 13))),
                DataCell(Text(row.dayName,
                    style: const TextStyle(fontSize: 13))),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      row.exerciseName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                DataCell(Text('${row.setNumber}')),
                DataCell(Text('${row.repsDone}')),
                DataCell(Text(
                  row.weight > 0
                      ? '${row.weight} ${row.weightUnit}'
                      : '—',
                )),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _HistoryRow {
  final DateTime date;
  final String dayName;
  final String exerciseName;
  final int setNumber;
  final int repsDone;
  final double weight;
  final String weightUnit;

  const _HistoryRow({
    required this.date,
    required this.dayName,
    required this.exerciseName,
    required this.setNumber,
    required this.repsDone,
    required this.weight,
    required this.weightUnit,
  });
}

extension on DateTime {
  int get dayOfYear =>
      difference(DateTime(year, 1, 1)).inDays;
}
