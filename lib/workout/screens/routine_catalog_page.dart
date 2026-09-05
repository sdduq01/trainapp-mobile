import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../profile/profile_service.dart';
import '../data/macrocycle_forjado.dart';
import '../models/custom_routine.dart';
import '../models/macrocycle_progress.dart';
import '../models/routine.dart';
import '../models/routine_template.dart';
import '../services/custom_routine_service.dart';
import '../services/macrocycle_service.dart';
import '../services/routine_service.dart';
import '../services/routine_template_service.dart';
import 'custom_routine_builder_page.dart';

/// Catálogo de rutinas: Recomendadas, Deportes, Personalizadas.
///
/// Pop con `true` si el usuario activó una rutina (para que HomePage refresque).
class RoutineCatalogPage extends StatelessWidget {
  const RoutineCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catálogo de rutinas'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.star_outline),         text: 'Recomendadas'),
              Tab(icon: Icon(Icons.sports_soccer),        text: 'Deportes'),
              Tab(icon: Icon(Icons.lock_outline),         text: 'Top Secret'),
              Tab(icon: Icon(Icons.timeline),             text: 'Macro ciclos'),
              Tab(icon: Icon(Icons.diamond_outlined),     text: 'Edición limitada'),
              Tab(icon: Icon(Icons.tune),                 text: 'Personalizadas'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TemplateListTab(category: 'recommended', emptyMsg: 'Aún no hay rutinas recomendadas.'),
            _TemplateListTab(category: 'sport',       emptyMsg: 'Aún no hay rutinas por deporte.'),
            _TopSecretTab(),
            _MacroTab(),
            _TemplateListTab(category: 'limited',     emptyMsg: 'Aún no hay rutinas de edición limitada.'),
            _CustomTab(),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Tab genérico que lista plantillas de una categoría
// ═══════════════════════════════════════════════════════════════════════════

class _TemplateListTab extends StatefulWidget {
  final String category;
  final String emptyMsg;
  const _TemplateListTab({required this.category, required this.emptyMsg});

  @override
  State<_TemplateListTab> createState() => _TemplateListTabState();
}

class _TemplateListTabState extends State<_TemplateListTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<RoutineTemplate>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = RoutineTemplateService().getByCategory(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<RoutineTemplate>>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(widget.emptyMsg, textAlign: TextAlign.center),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (_, i) => _TemplateCard(template: items[i]),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Card de plantilla
// ═══════════════════════════════════════════════════════════════════════════

class _TemplateCard extends StatelessWidget {
  final RoutineTemplate template;
  const _TemplateCard({required this.template});

  int get _totalExercises =>
      template.days.fold(0, (sum, d) => sum + d.exercises.length);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              template.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${template.days.length} días · $_totalExercises ejercicios',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(template.description, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final d in template.days)
                  Chip(
                    label: Text(d.name, style: const TextStyle(fontSize: 11)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Usar esta rutina'),
                onPressed: () => _activateTemplate(context, template),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Tab Top Secret · bloqueada hasta completar "Forjado por el Hierro"
// ═══════════════════════════════════════════════════════════════════════════

class _TopSecretTab extends StatefulWidget {
  const _TopSecretTab();

  @override
  State<_TopSecretTab> createState() => _TopSecretTabState();
}

class _TopSecretTabState extends State<_TopSecretTab>
    with AutomaticKeepAliveClientMixin {
  late Future<({bool unlocked, MacrocycleProgress? macro})> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({bool unlocked, MacrocycleProgress? macro})> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return (unlocked: false, macro: null);
    final profile = await ProfileService().getProfile(uid);
    final macro = await MacrocycleService().get(uid);
    return (unlocked: profile?.forjadoHierroCompletado ?? false, macro: macro);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<({bool unlocked, MacrocycleProgress? macro})>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFC41E3A)),
            ),
          );
        }
        final data = snap.data;
        if (data?.unlocked == true) return const _SecretRoutinesView();
        return _LockedTopSecretView(macro: data?.macro);
      },
    );
  }
}

/// Vista enigmática estoica mientras Top Secret sigue bloqueado. Si hay un
/// macro ciclo en curso muestra cuánto camino lleva forjado.
class _LockedTopSecretView extends StatelessWidget {
  final MacrocycleProgress? macro;
  const _LockedTopSecretView({this.macro});

  @override
  Widget build(BuildContext context) {
    final m = macro;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Color(0xFF8B0000), size: 72),
              const SizedBox(height: 28),
              const Text(
                'TOP SECRET',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFC41E3A),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No todas las puertas se abren con curiosidad.\n'
                'Algunas rutinas no se exhiben: aguardan al que ya '
                'ha forjado el cuerpo y la voluntad para recibirlas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 28),
              Container(width: 60, height: 1, color: Colors.white24),
              const SizedBox(height: 28),
              const Text(
                '"La fortuna favorece al que se prepara,\n'
                'no al que la implora."',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '— Séneca',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFC41E3A),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 36),
              if (m != null && !m.completed) ...[
                Text(
                  'Has forjado ${m.totalSessionsDone} de ${m.totalSessionsGoal} '
                  'sesiones del camino.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.6,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: m.totalSessionsGoal == 0
                        ? 0
                        : m.totalSessionsDone / m.totalSessionsGoal,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFC41E3A)),
                  ),
                ),
              ] else
                const Text(
                  'Vuelve cuando hayas sido forjado por el hierro.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    height: 1.6,
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top Secret desbloqueado: lista las rutinas ocultas (category 'secret').
class _SecretRoutinesView extends StatefulWidget {
  const _SecretRoutinesView();

  @override
  State<_SecretRoutinesView> createState() => _SecretRoutinesViewState();
}

class _SecretRoutinesViewState extends State<_SecretRoutinesView> {
  late Future<List<RoutineTemplate>> _future;

  @override
  void initState() {
    super.initState();
    _future = RoutineTemplateService().getByCategory('secret');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: FutureBuilder<List<RoutineTemplate>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFC41E3A)),
            );
          }
          final items = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 8, 4, 16),
                child: Text(
                  'ACCESO CONCEDIDO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFC41E3A),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Las rutinas secretas se revelarán pronto.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              else
                for (final t in items) _TemplateCard(template: t),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Tab Macro ciclos · "Forjado por el Hierro" (card fija en código)
// ═══════════════════════════════════════════════════════════════════════════

class _MacroTab extends StatefulWidget {
  const _MacroTab();

  @override
  State<_MacroTab> createState() => _MacroTabState();
}

class _MacroTabState extends State<_MacroTab> with AutomaticKeepAliveClientMixin {
  late Future<MacrocycleProgress?> _future;
  bool _activating = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<MacrocycleProgress?> _load() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Future.value(null);
    return MacrocycleService().get(uid);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _start() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Iniciar la forja'),
        content: Text(
          'Empiezas un año bajo el hierro. Tu rutina actual queda reemplazada '
          'por la base de la forja: cuatro días, de los cuales los tres '
          'primeros no cambian nunca y el cuarto rota su énfasis a lo largo de '
          '${ForjadoPorElHierro.totalPhases} fases '
          '(${ForjadoPorElHierro.emphases.join(' → ')}).\n\n'
          'Una fase se cierra solo cuando completas '
          '${ForjadoPorElHierro.sessionsPerDay} sesiones de cada uno de los '
          'cuatro días — sin atajos. Al cerrar la última, el año está hecho y '
          'Top Secret se abre.\n\n'
          'Puedes editar los ejercicios sin salir del macro ciclo. '
          'Tus pesos registrados se mantienen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Iniciar la forja'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _activating = true);
    try {
      final routine = await RoutineService()
          .hydrateWithPRs(ForjadoPorElHierro.routineForPhase(uid, 0));
      await RoutineService().saveRoutine(routine);
      await MacrocycleService().start(uid);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _activating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo empezar el macro ciclo: $e')),
        );
      }
    }
  }

  Future<void> _abandon() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Abandonar el macro ciclo?'),
        content: const Text(
          'Perderás el avance de fases de "Forjado por el Hierro". La rutina '
          'actual se conserva como rutina normal (podrás editarla sin '
          'restricciones) y tus pesos no se tocan.\n\n'
          'Top Secret seguirá bloqueado hasta completar un macro ciclo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abandonar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _activating = true);
    try {
      await MacrocycleService().abandon(uid);
      // Normaliza la rutina para que deje de estar bloqueada por el macro ciclo.
      final routine = await RoutineService().getRoutine(uid);
      if (routine != null && routine.type == ForjadoPorElHierro.routineType) {
        await RoutineService().saveRoutine(Routine(
          userId: routine.userId,
          type: 'PPL',
          name: routine.name,
          weekNumber: routine.weekNumber,
          createdAt: routine.createdAt,
          days: routine.days,
        ));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _activating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abandonar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return FutureBuilder<MacrocycleProgress?>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final macro = snap.data;
        final inProgress = macro != null && !macro.completed;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.black,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🔥  MACRO CICLO',
                            style: TextStyle(
                              color: Color(0xFFC41E3A),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            )),
                        const SizedBox(height: 6),
                        Text(ForjadoPorElHierro.routineName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            )),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Un año bajo el hierro. No es una rutina... es una '
                          'Odisea.\n\n'
                          'Tres días de la semana son roca inamovible sobre la '
                          'que se construye todo. El cuarto día es el calor del '
                          'horno, que cambia según el énfasis de la fase.\n\n'
                          'Cada fase se cierra cuando la has dominado, y al '
                          'cerrar la última fase las puertas de Top Secret '
                          'serán abiertas para quien lo resista.',
                          style: TextStyle(fontSize: 14, height: 1.5),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '«No es que no nos atrevamos porque las cosas sean '
                          'difíciles; el no atrevernos es lo que las hace '
                          'difíciles.»  — Séneca',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFFC41E3A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Las ${ForjadoPorElHierro.totalPhases} fases:',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (var i = 0;
                            i < ForjadoPorElHierro.emphases.length;
                            i++)
                          _PhaseRow(
                            phase: i + 1,
                            emphasis: ForjadoPorElHierro.emphases[i],
                            done: macro != null && i < macro.phaseIndex,
                            current: inProgress && i == macro.phaseIndex,
                          ),
                        const SizedBox(height: 16),
                        if (macro != null && macro.completed)
                          Row(
                            children: [
                              const Icon(Icons.verified,
                                  color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text('Completado · Top Secret desbloqueado',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold)),
                            ],
                          )
                        else if (inProgress)
                          Text(
                            'En curso · Fase ${macro.currentPhaseNumber}/'
                            '${macro.totalPhases} · Énfasis '
                            '${macro.currentEmphasis} · '
                            '${macro.sessionsThisPhase}/'
                            '${macro.sessionsGoalPerPhase} sesiones',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          )
                        else
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              icon: _activating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.local_fire_department),
                              label: const Text('Iniciar la forja'),
                              onPressed: _activating ? null : _start,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (inProgress)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _activating ? null : _reload,
                      child: const Text('Actualizar'),
                    ),
                    TextButton(
                      onPressed: _activating ? null : _abandon,
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Abandonar macro ciclo'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PhaseRow extends StatelessWidget {
  final int phase;
  final String emphasis;
  final bool done;
  final bool current;
  const _PhaseRow({
    required this.phase,
    required this.emphasis,
    required this.done,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final icon = done
        ? Icons.check_circle
        : current
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked;
    final color = done
        ? Colors.green
        : current
            ? Theme.of(context).colorScheme.primary
            : Colors.grey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text('Fase $phase',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('· Énfasis $emphasis',
              style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Tab Personalizadas (botones de acción + ClaudIA)
// ═══════════════════════════════════════════════════════════════════════════

class _CustomTab extends StatefulWidget {
  const _CustomTab();

  @override
  State<_CustomTab> createState() => _CustomTabState();
}

class _CustomTabState extends State<_CustomTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<CustomRoutine>> _saved;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _saved = _load();
  }

  Future<List<CustomRoutine>> _load() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Future.value(const []);
    return CustomRoutineService().list(uid);
  }

  void _reload() => setState(() => _saved = _load());

  Future<void> _deleteSaved(CustomRoutine cr) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar rutina?'),
        content: Text(
          '"${cr.name}" se borrará de Mis rutinas. Si es tu rutina activa, '
          'seguirá activa hasta que actives otra.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await CustomRoutineService().delete(uid, cr.id);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Crea tu propia rutina',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Define tus días, elige los ejercicios por grupo muscular y arma la rutina exacta que quieres.',
          style: TextStyle(color: Colors.grey[700]),
        ),
        const SizedBox(height: 20),

        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.add, color: theme.colorScheme.primary),
            ),
            title: const Text(
              'Crear rutina personalizada',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Empieza desde cero. Define días y ejercicios.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final activated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const CustomRoutineBuilderPage()),
              );
              if (!context.mounted) return;
              if (activated == true) {
                Navigator.pop(context, true);
              } else {
                _reload();
              }
            },
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'Mis rutinas',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<CustomRoutine>>(
          future: _saved,
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return Text(
                'Las rutinas que crees se guardarán aquí.',
                style: TextStyle(color: Colors.grey[600]),
              );
            }
            return Column(
              children: [
                for (final cr in items)
                  Card(
                    child: ListTile(
                      title: Text(
                        cr.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${cr.days.length} días · ${cr.totalExercises} ejercicios',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => _activateCustomRoutine(context, cr),
                            child: const Text('Usar'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            tooltip: 'Eliminar',
                            onPressed: () => _deleteSaved(cr),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        const SizedBox(height: 12),

        // ─── ClaudIA · placeholder no funcional ────────────────────────
        Card(
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.secondary,
              child: const Icon(Icons.auto_awesome, color: Colors.white),
            ),
            title: const Text(
              'ClaudIA · Asistente IA',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Genera una rutina automática a partir de tu peso, estatura, % de grasa, objetivo y días.',
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Próximamente',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ClaudIA llegará pronto 🤖'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   Activación: confirma + sobreescribe routines/{uid} + pop con true
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _activateTemplate(BuildContext context, RoutineTemplate t) =>
    _activateRoutine(context, name: t.name, build: (uid) => t.toRoutine(uid));

Future<void> _activateCustomRoutine(BuildContext context, CustomRoutine cr) =>
    _activateRoutine(context, name: cr.name, build: (uid) => cr.toRoutine(uid));

Future<void> _activateRoutine(
  BuildContext context, {
  required String name,
  required Routine Function(String uid) build,
}) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Activar rutina'),
      content: Text(
        '¿Reemplazar tu rutina actual por "$name"?\n\n'
        'Los pesos de los ejercicios que ya tienes registrados se mantendrán.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true),  child: const Text('Activar')),
      ],
    ),
  );
  if (confirm != true || !context.mounted) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  bool saved = false;
  try {
    final hydrated =
        await RoutineService().hydrateWithPRs(build(user.uid));
    await RoutineService().saveRoutine(hydrated);
    // Activar una rutina normal abandona el macro ciclo en curso (si lo hay).
    await MacrocycleService().abandon(user.uid);
    saved = true;
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context); // cierra spinner
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al activar: $e')),
      );
    }
  }

  if (saved && context.mounted) {
    Navigator.pop(context); // cierra spinner
    Navigator.pop(context, true); // cierra catálogo con result
  }
}
