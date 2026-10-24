import 'package:flutter/material.dart';

import '../../gym/models/gym_request.dart';
import '../../gym/services/gym_request_service.dart';
import '../widgets/portal_scaffold.dart';

/// Solicitudes de alta pendientes (solo admin de TrainApp): aprobar crea el
/// gimnasio con el solicitante como dueño; rechazar pide un motivo.
class AdminRequestsSection extends StatefulWidget {
  const AdminRequestsSection({super.key});

  @override
  State<AdminRequestsSection> createState() => _AdminRequestsSectionState();
}

class _AdminRequestsSectionState extends State<AdminRequestsSection> {
  List<GymRequest>? _requests;
  String? _busyUid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final requests = await GymRequestService().getPending();
      if (mounted) setState(() => _requests = requests);
    } catch (e) {
      if (mounted) {
        setState(() => _requests = []);
        _showMessage('No se pudieron cargar las solicitudes: $e');
      }
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _approve(GymRequest r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aprobar solicitud'),
        content: Text('Se creará "${r.gymName}" con ${r.email} como dueño.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyUid = r.uid);
    try {
      await GymRequestService().approve(r);
      if (mounted) _showMessage('"${r.gymName}" está activo.');
      await _load();
    } on Exception catch (e) {
      if (mounted) _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  Future<void> _reject(GymRequest r) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo (lo verá el solicitante)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (reason == null) return;

    setState(() => _busyUid = r.uid);
    try {
      await GymRequestService().reject(r, reason);
      await _load();
    } catch (e) {
      if (mounted) _showMessage('Error: $e');
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = _requests;
    return PortalPage(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Solicitudes de gimnasios',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (requests == null)
          const Center(child: CircularProgressIndicator())
        else if (requests.isEmpty)
          const Text('No hay solicitudes pendientes.',
              style: TextStyle(color: Colors.grey))
        else
          for (final r in requests)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.gymName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${r.contactName} · ${r.email} · ${r.phone}'),
                    Text('${r.address}, ${r.city}',
                        style: const TextStyle(color: Colors.grey)),
                    Text(
                      'Enviada el ${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: _busyUid == null ? () => _approve(r) : null,
                          child: const Text('Aprobar'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _busyUid == null ? () => _reject(r) : null,
                          child: const Text('Rechazar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
