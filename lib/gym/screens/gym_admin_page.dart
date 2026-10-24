import 'package:flutter/material.dart';

import '../models/gym.dart';
import '../services/gym_service.dart';
import '../widgets/gym_logo.dart';
import '../widgets/gym_members_panel.dart';

/// Pantalla del dueño del gimnasio en la app: logo y nombre, y los
/// entrenadores de planta y atletas (el resto se administra en el portal web).
class GymAdminPage extends StatefulWidget {
  final Gym gym;

  const GymAdminPage({required this.gym, super.key});

  @override
  State<GymAdminPage> createState() => _GymAdminPageState();
}

class _GymAdminPageState extends State<GymAdminPage> {
  late Gym _gym = widget.gym;
  bool _busy = false;

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _changeLogo() async {
    setState(() => _busy = true);
    try {
      final url = await GymService().pickAndUploadLogo(_gym);
      if (url != null && mounted) {
        setState(() => _gym = _gym.copyWith(logoUrl: url));
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
      if (mounted) setState(() => _gym = _gym.copyWith(name: name));
    } catch (e) {
      if (mounted) _showMessage('No se pudo cambiar el nombre: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi gimnasio')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
          GymMembersPanel(gym: _gym),
        ],
      ),
    );
  }
}
