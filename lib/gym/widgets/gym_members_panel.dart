import 'package:flutter/material.dart';

import '../models/gym.dart';
import '../models/gym_member.dart';
import '../services/gym_service.dart';

/// Entrenadores de planta y atletas de un gimnasio (aceptados e invitaciones
/// pendientes), con invitar por email y retirar. Lo usan la pantalla
/// "Mi gimnasio" de la app y el portal web. No hace scroll propio: va dentro
/// del ListView de quien lo contiene.
class GymMembersPanel extends StatefulWidget {
  final Gym gym;

  /// Avisa cada vez que cambia la lista (para contadores del contenedor).
  final ValueChanged<List<GymMember>>? onChanged;

  const GymMembersPanel({required this.gym, this.onChanged, super.key});

  @override
  State<GymMembersPanel> createState() => _GymMembersPanelState();
}

class _GymMembersPanelState extends State<GymMembersPanel> {
  List<GymMember>? _members;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await GymService().getMembers(widget.gym.id);
      if (!mounted) return;
      setState(() => _members = members);
      widget.onChanged?.call(members);
    } catch (e) {
      if (!mounted) return;
      setState(() => _members = []);
      _showMessage('No se pudieron cargar los miembros: $e');
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _invite() async {
    final result = await showDialog<(String, GymRole)>(
      context: context,
      builder: (_) => const _InviteDialog(),
    );
    if (result == null) return;
    final (email, role) = result;

    setState(() => _busy = true);
    try {
      await GymService().invite(gym: widget.gym, emailInput: email, role: role);
      if (mounted) _showMessage('Invitación enviada.');
      await _load();
    } on Exception catch (e) {
      if (mounted) _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(GymMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(member.isAccepted ? 'Retirar del gimnasio' : 'Cancelar invitación'),
        content: Text(
          member.isAccepted
              ? '${member.email} dejará de pertenecer a ${widget.gym.name}. ¿Continuar?'
              : '¿Cancelar la invitación a ${member.email}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await GymService().deleteMembership(member.uid);
      await _load();
    } catch (e) {
      if (mounted) _showMessage('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;
    if (members == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _invite,
              icon: const Icon(Icons.person_add),
              label: const Text('Invitar'),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
            ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(),
        const SizedBox(height: 16),
        _MemberSection(
          title: 'Entrenadores de planta',
          emptyText: 'Todavía no hay entrenadores.',
          members: members.where((m) => m.isTrainer).toList(),
          onRemove: _remove,
        ),
        const SizedBox(height: 24),
        _MemberSection(
          title: 'Atletas',
          emptyText: 'Todavía no hay atletas.',
          members: members.where((m) => !m.isTrainer).toList(),
          onRemove: _remove,
        ),
      ],
    );
  }
}

class _MemberSection extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<GymMember> members;
  final ValueChanged<GymMember> onRemove;

  const _MemberSection({
    required this.title,
    required this.emptyText,
    required this.members,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${members.where((m) => m.isAccepted).length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (members.isEmpty)
          Text(emptyText, style: const TextStyle(color: Colors.grey)),
        for (final m in members)
          Card(
            child: ListTile(
              leading: Icon(
                m.isAccepted
                    ? (m.isTrainer ? Icons.sports : Icons.person)
                    : Icons.hourglass_top,
              ),
              title: Text(m.email),
              subtitle: m.isAccepted ? null : const Text('Invitación pendiente'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                tooltip: m.isAccepted ? 'Retirar' : 'Cancelar invitación',
                onPressed: () => onRemove(m),
              ),
            ),
          ),
      ],
    );
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog();

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _emailCtrl = TextEditingController();
  GymRole _role = GymRole.athlete;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    Navigator.pop(context, (email, _role));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invitar al gimnasio'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<GymRole>(
            segments: const [
              ButtonSegment(
                value: GymRole.athlete,
                label: Text('Atleta'),
                icon: Icon(Icons.person),
              ),
              ButtonSegment(
                value: GymRole.trainer,
                label: Text('Entrenador'),
                icon: Icon(Icons.sports),
              ),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailCtrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'persona@ejemplo.com',
              helperText: 'La persona debe tener cuenta en TrainApp.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Enviar invitación'),
        ),
      ],
    );
  }
}
