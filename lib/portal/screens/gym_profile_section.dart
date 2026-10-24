import 'package:flutter/material.dart';

import '../../gym/models/gym.dart';
import '../../gym/services/gym_service.dart';
import '../../gym/widgets/gym_logo.dart';
import '../widgets/portal_scaffold.dart';

/// Perfil del gimnasio: logo, nombre, datos de contacto y la ventana de
/// cancelación de las clases grupales.
class GymProfileSection extends StatefulWidget {
  final Gym gym;
  final ValueChanged<Gym> onSaved;

  const GymProfileSection({required this.gym, required this.onSaved, super.key});

  @override
  State<GymProfileSection> createState() => _GymProfileSectionState();
}

class _GymProfileSectionState extends State<GymProfileSection> {
  static const _cancelWindowOptions = [0, 1, 2, 3, 4, 6, 12, 24];

  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.gym.name);
  late final _cityCtrl = TextEditingController(text: widget.gym.city);
  late final _addressCtrl = TextEditingController(text: widget.gym.address);
  late final _phoneCtrl = TextEditingController(text: widget.gym.phone);
  late int _cancelWindowHours = widget.gym.cancelWindowHours;
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _cityCtrl, _addressCtrl, _phoneCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _changeLogo() async {
    setState(() => _uploading = true);
    try {
      final url = await GymService().pickAndUploadLogo(widget.gym);
      if (url != null) {
        widget.onSaved(widget.gym.copyWith(logoUrl: url));
        if (mounted) _showMessage('Logo actualizado.');
      }
    } catch (e) {
      if (mounted) _showMessage('No se pudo subir el logo: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final updated = widget.gym.copyWith(
      name: _nameCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      cancelWindowHours: _cancelWindowHours,
    );
    setState(() => _saving = true);
    try {
      await GymService().updateProfile(updated);
      widget.onSaved(updated);
      if (mounted) _showMessage('Cambios guardados.');
    } catch (e) {
      if (mounted) _showMessage('No se pudieron guardar los cambios: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final windowOptions = {..._cancelWindowOptions, _cancelWindowHours}.toList()
      ..sort();
    return PortalPage(
      maxWidth: 560,
      children: [
        const Text('Perfil del gimnasio',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Row(
          children: [
            GymLogo(url: widget.gym.logoUrl, size: 96),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _changeLogo,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.image_outlined),
                    label: const Text('Cambiar logo'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Se muestra en el inicio de la app de tus atletas. '
                    'Mejor si es cuadrado, en PNG o JPG.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ciudad'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                initialValue: _cancelWindowHours,
                decoration: const InputDecoration(
                  labelText: 'Cancelación de clases grupales',
                  helperText:
                      'Hasta cuántas horas antes de la clase un atleta puede cancelar su cupo.',
                  helperMaxLines: 2,
                ),
                items: [
                  for (final h in windowOptions)
                    DropdownMenuItem(
                      value: h,
                      child: Text(h == 0
                          ? 'Hasta que empiece la clase'
                          : '$h hora${h == 1 ? '' : 's'} antes'),
                    ),
                ],
                onChanged: (v) => setState(() => _cancelWindowHours = v!),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Guardar cambios'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
