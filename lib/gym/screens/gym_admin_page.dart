import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/gym.dart';
import '../models/gym_member.dart';
import '../services/gym_service.dart';
import '../widgets/gym_logo.dart';

/// Pantalla del dueño del gimnasio: logo y nombre, entrenadores de planta y
/// atletas (aceptados e invitaciones pendientes), invitar por email y
/// retirar miembros.
class GymAdminPage extends StatefulWidget {
  final Gym gym;

  const GymAdminPage({required this.gym, super.key});

  @override
  State<GymAdminPage> createState() => _GymAdminPageState();
}

class _GymAdminPageState extends State<GymAdminPage> {
  late Gym _gym = widget.gym;
  List<GymMember>? _members;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await GymService().getMembers(_gym.id);
      if (mounted) setState(() => _members = members);
    } catch (e) {
      if (mounted) {
        setState(() => _members = []);
        _showMessage('No se pudieron cargar los miembros: $e');
      }
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _changeLogo() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _busy = true);
    try {
      final url = await GymService().uploadLogo(_gym, image);
      if (mounted) {
        setState(() => _gym = Gym(
              id: _gym.id,
              name: _gym.name,
              ownerUid: _gym.ownerUid,
              logoUrl: url,
            ));
        _showMessage('Logo actualizado.');
      }
    } catch (e) {
      if (mounted) _showMessage('No se pudo subir el logo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: _gym.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nombre del gimnasio'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == _gym.name) return;

    setState(() => _busy = true);
    try {
      await GymService().renameGym(_gym.id, name);
      if (mounted) {
        setState(() => _gym = Gym(
              id: _gym.id,
              name: name,
              ownerUid: _gym.ownerUid,
              logoUrl: _gym.logoUrl,
            ));
      }
    } catch (e) {
      if (mounted) _showMessage('No se pudo cambiar el nombre: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      await GymService().invite(gym: _gym, emailInput: email, role: role);
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
              ? '${member.email} dejará de pertenecer a ${_gym.name}. ¿Continuar?'
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
    return Scaffold(
      appBar: AppBar(title: const Text('Mi gimnasio')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _invite,
        icon: const Icon(Icons.person_add),
        label: const Text('Invitar'),
      ),
      body: members == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Row(
                    children: [
                      GymLogo(url: _gym.logoUrl, size: 72),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _gym.name,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Wrap(
                              children: [
                                TextButton.icon(
                                  onPressed: _busy ? null : _changeLogo,
                                  icon: const Icon(Icons.image_outlined, size: 18),
                                  label: const Text('Cambiar logo'),
                                ),
                                TextButton.icon(
                                  onPressed: _busy ? null : _rename,
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  label: const Text('Renombrar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  const SizedBox(height: 24),
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
              ),
            ),
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
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'persona@ejemplo.com',
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
          onPressed: () {
            final email = _emailCtrl.text.trim();
            if (email.isEmpty) return;
            Navigator.pop(context, (email, _role));
          },
          child: const Text('Enviar invitación'),
        ),
      ],
    );
  }
}
