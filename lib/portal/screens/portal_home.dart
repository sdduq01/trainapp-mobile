import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../gym/models/gym.dart';
import '../../gym/models/gym_member.dart';
import '../../gym/models/gym_request.dart';
import '../../gym/services/gym_request_service.dart';
import '../../gym/services/gym_service.dart';
import '../widgets/portal_scaffold.dart';
import 'gym_dashboard.dart';
import 'gym_request_page.dart';

const _kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.ariete.trainapp';

/// Decide qué ve quien entra al portal:
/// - dueño de un gimnasio o admin → panel
/// - entrenador de planta → aviso (las clases llegan en la fase 2)
/// - con solicitud de alta → estado de la solicitud
/// - atleta o sin gimnasio → "este portal es para gimnasios" + inscribir uno
class PortalHome extends StatefulWidget {
  final User user;

  const PortalHome({required this.user, super.key});

  @override
  State<PortalHome> createState() => _PortalHomeState();
}

class _PortalHomeState extends State<PortalHome> {
  bool _loading = true;
  String? _error;
  bool _isAdmin = false;
  Gym? _ownedGym;
  GymMember? _membership;
  GymRequest? _request;
  bool _showRequestForm = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final uid = widget.user.uid;
      final results = await Future.wait([
        // forceRefresh: el claim admin recién asignado aplica sin re-login.
        widget.user.getIdTokenResult(true),
        GymService().getOwnedGym(uid),
        GymService().getMembership(uid),
        GymRequestService().getMyRequest(uid),
      ]);
      if (!mounted) return;
      setState(() {
        _isAdmin = (results[0] as IdTokenResult).claims?['admin'] == true;
        _ownedGym = results[1] as Gym?;
        _membership = results[2] as GymMember?;
        _request = results[3] as GymRequest?;
        _showRequestForm = false;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PortalScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return PortalScaffold(
        body: PortalPage(children: [
          const Text('No se pudo cargar tu información.'),
          Text(_error!, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(onPressed: _load, child: const Text('Reintentar')),
          ),
        ]),
      );
    }

    if (_ownedGym != null || _isAdmin) {
      return GymDashboard(
        gym: _ownedGym,
        isAdmin: _isAdmin,
        onGymChanged: (gym) => setState(() => _ownedGym = gym),
      );
    }

    final request = _request;
    if (_showRequestForm ||
        (request != null && request.status != GymRequestStatus.approved)) {
      return GymRequestPage(
        user: widget.user,
        existing: request,
        onSubmitted: _load,
        onCancel: request == null
            ? () => setState(() => _showRequestForm = false)
            : null,
      );
    }

    return _NoGymPage(
      membership: _membership,
      onRegisterGym: () => setState(() => _showRequestForm = true),
      onRefresh: _load,
    );
  }
}

class _NoGymPage extends StatelessWidget {
  final GymMember? membership;
  final VoidCallback onRegisterGym;
  final VoidCallback onRefresh;

  const _NoGymPage({
    required this.membership,
    required this.onRegisterGym,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final m = membership;
    final isGymTrainer = m != null && m.isAccepted && m.isTrainer;

    final String title;
    final String body;
    if (isGymTrainer) {
      title = 'Entrenador de ${m.gymName}';
      body = 'Muy pronto podrás crear y administrar las clases grupales de tu '
          'gimnasio desde aquí. Mientras tanto, entrena a tus atletas desde '
          '"Mis atletas" en la app.';
    } else if (m != null && m.isAccepted) {
      title = 'Atleta de ${m.gymName}';
      body = 'Este portal es para la administración de gimnasios. Tu '
          'entrenamiento sigue en la app TrainApp.';
    } else {
      title = 'Este portal es para gimnasios';
      body = 'Aquí los gimnasios administran a sus entrenadores y atletas. '
          'Si entrenas con TrainApp, tu entrenamiento sigue en la app.';
    }

    return PortalScaffold(
      body: PortalPage(
        maxWidth: 560,
        children: [
          const SizedBox(height: 24),
          Icon(isGymTrainer ? Icons.sports : Icons.fitness_center,
              size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(body,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], height: 1.4)),
          const SizedBox(height: 24),
          if (!isGymTrainer)
            Center(
              child: FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse(_kPlayStoreUrl)),
                icon: const Icon(Icons.shop),
                label: const Text('Abrir TrainApp en Google Play'),
              ),
            ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text('¿Tienes un gimnasio?',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton.icon(
              onPressed: onRegisterGym,
              icon: const Icon(Icons.store_outlined),
              label: const Text('Inscribir mi gimnasio'),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: onRefresh,
              child: const Text('Actualizar'),
            ),
          ),
        ],
      ),
    );
  }
}
