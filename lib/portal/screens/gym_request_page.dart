import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../gym/models/gym_request.dart';
import '../../gym/services/gym_request_service.dart';
import '../widgets/portal_scaffold.dart';

/// Formulario "Inscribe tu gimnasio" y estado de la solicitud. Mientras está
/// en revisión se puede editar; si se rechaza, muestra el motivo y permite
/// corregirla y reenviarla.
class GymRequestPage extends StatefulWidget {
  final User user;
  final GymRequest? existing;
  final VoidCallback onSubmitted;

  /// Volver sin enviar (solo cuando todavía no hay solicitud).
  final VoidCallback? onCancel;

  const GymRequestPage({
    required this.user,
    required this.existing,
    required this.onSubmitted,
    this.onCancel,
    super.key,
  });

  @override
  State<GymRequestPage> createState() => _GymRequestPageState();
}

class _GymRequestPageState extends State<GymRequestPage> {
  final _formKey = GlobalKey<FormState>();
  late final _gymNameCtrl = TextEditingController(text: widget.existing?.gymName);
  late final _contactCtrl = TextEditingController(text: widget.existing?.contactName);
  late final _cityCtrl = TextEditingController(text: widget.existing?.city);
  late final _addressCtrl = TextEditingController(text: widget.existing?.address);
  late final _phoneCtrl = TextEditingController(text: widget.existing?.phone);

  /// Con una solicitud pendiente se muestra el resumen; "Editar" abre el form.
  late bool _editing = widget.existing == null ||
      widget.existing!.status == GymRequestStatus.rejected;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_gymNameCtrl, _contactCtrl, _cityCtrl, _addressCtrl, _phoneCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await GymRequestService().submit(GymRequest(
        uid: widget.user.uid,
        gymName: _gymNameCtrl.text.trim(),
        contactName: _contactCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: widget.user.email ?? '',
        status: GymRequestStatus.pending,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      ));
      widget.onSubmitted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar la solicitud: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return PortalScaffold(
      body: PortalPage(
        maxWidth: 560,
        children: [
          if (existing != null) ...[
            _StatusBanner(request: existing),
            const SizedBox(height: 24),
          ],
          if (_editing) _buildForm() else _buildSummary(existing!),
        ],
      ),
    );
  }

  Widget _buildSummary(GymRequest r) {
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(label, style: const TextStyle(color: Colors.grey)),
              ),
              Expanded(child: Text(value)),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row('Gimnasio', r.gymName),
            row('Contacto', r.contactName),
            row('Ciudad', r.city),
            row('Dirección', r.address),
            row('Teléfono', r.phone),
            row('Email', r.email),
            if (r.status == GymRequestStatus.pending) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar solicitud'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final isResubmit = widget.existing != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Inscribe tu gimnasio',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Revisaremos tus datos y activaremos tu gimnasio. Luego podrás '
                'invitar a tus entrenadores y atletas desde aquí.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _gymNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre del gimnasio'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre de contacto'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ciudad'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              Text('Email de la cuenta: ${widget.user.email ?? ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),
              Row(
                children: [
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: Text(isResubmit ? 'Reenviar solicitud' : 'Enviar solicitud'),
                  ),
                  const SizedBox(width: 8),
                  if (widget.onCancel != null)
                    TextButton(
                      onPressed: _saving ? null : widget.onCancel,
                      child: const Text('Volver'),
                    )
                  else if (widget.existing?.status == GymRequestStatus.pending)
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _editing = false),
                      child: const Text('Cancelar'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final GymRequest request;

  const _StatusBanner({required this.request});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String title, String body) =
        switch (request.status) {
      GymRequestStatus.pending => (
          Icons.hourglass_top,
          Colors.orange,
          'Solicitud en revisión',
          'Cuando la aprobemos, al volver a entrar al portal verás el panel de tu gimnasio.',
        ),
      GymRequestStatus.rejected => (
          Icons.info_outline,
          Colors.red,
          'Solicitud no aprobada',
          request.rejectionReason?.isNotEmpty == true
              ? 'Motivo: ${request.rejectionReason}. Puedes corregirla y reenviarla.'
              : 'Puedes corregirla y reenviarla.',
        ),
      GymRequestStatus.approved => (
          Icons.check_circle_outline,
          Colors.green,
          'Solicitud aprobada',
          'Tu gimnasio está activo. Recarga la página para entrar al panel.',
        ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
