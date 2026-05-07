import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/routine_template.dart';
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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catálogo de rutinas'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.star_outline),       text: 'Recomendadas'),
              Tab(icon: Icon(Icons.sports_soccer),      text: 'Deportes'),
              Tab(icon: Icon(Icons.tune),               text: 'Personalizadas'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TemplateListTab(category: 'recommended', emptyMsg: 'Aún no hay rutinas recomendadas.'),
            _TemplateListTab(category: 'sport',       emptyMsg: 'Aún no hay rutinas por deporte.'),
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
//   Tab Personalizadas (botones de acción + ClaudIA)
// ═══════════════════════════════════════════════════════════════════════════

class _CustomTab extends StatelessWidget {
  const _CustomTab();

  @override
  Widget build(BuildContext context) {
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
              if (activated == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
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

Future<void> _activateTemplate(BuildContext context, RoutineTemplate t) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Activar rutina'),
      content: Text(
        '¿Reemplazar tu rutina actual por "${t.name}"?\n\n'
        'Tus marcas (pesos) actuales se reiniciarán.',
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
    await RoutineService().saveRoutine(t.toRoutine(user.uid));
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
