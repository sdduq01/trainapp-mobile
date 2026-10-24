import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../gym/models/gym_member.dart';
import '../../gym/services/gym_service.dart';
import '../models/trainer_link.dart';
import '../services/trainer_link_service.dart';
import 'athlete_detail_page.dart';

/// Pantalla del lado entrenador: atletas aceptados + solicitudes enviadas
/// pendientes, y el botón para agregar un atleta nuevo por email. Si además
/// es entrenador de planta de un gimnasio, también lista a los atletas del
/// gimnasio (acceso por pertenencia, sin solicitud).
class MyAthletesPage extends StatefulWidget {
  const MyAthletesPage({super.key});

  @override
  State<MyAthletesPage> createState() => _MyAthletesPageState();
}

class _MyAthletesPageState extends State<MyAthletesPage> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  List<TrainerLink>? _accepted;
  List<TrainerLink>? _pending;
  GymMember? _gymMembership;
  List<GymMember> _gymAthletes = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      TrainerLinkService().getMyLinks(_uid),
      _loadGymAthletes(),
    ]);
    final links = results[0]
        as ({List<TrainerLink> accepted, List<TrainerLink> pending});
    if (mounted) {
      setState(() {
        _accepted = links.accepted;
        _pending = links.pending;
      });
    }
  }

  /// Atletas del gimnasio si soy entrenador de planta aceptado. Los que ya
  /// son mis atletas personales no se repiten.
  Future<void> _loadGymAthletes() async {
    try {
      final membership = await GymService().getMembership(_uid);
      var athletes = <GymMember>[];
      if (membership != null && membership.isAccepted && membership.isTrainer) {
        athletes = await GymService().getAcceptedAthletes(membership.gymId);
        athletes.removeWhere((a) => a.uid == _uid);
      }
      if (mounted) {
        setState(() {
          _gymMembership = membership;
          _gymAthletes = athletes;
        });
      }
    } catch (_) {
      // silencioso: la sección del gimnasio simplemente no aparece
    }
  }

  Future<void> _openAthlete(
    String athleteUid,
    String athleteEmail, {
    bool viaGym = false,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AthleteDetailPage(
          athleteUid: athleteUid,
          athleteEmail: athleteEmail,
          viaGym: viaGym,
        ),
      ),
    );
    _load(); // pudo haber revocado el acceso desde ahí
  }

  Future<void> _addAthlete() async {
    final emailCtrl = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar atleta'),
        content: TextField(
          controller: emailCtrl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email del atleta',
            hintText: 'atleta@ejemplo.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, emailCtrl.text.trim()),
            child: const Text('Enviar solicitud'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;

    setState(() => _sending = true);
    try {
      final trainerEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      await TrainerLinkService().sendRequest(
        trainerUid: _uid,
        trainerEmail: trainerEmail,
        athleteEmailInput: email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud enviada.')),
        );
      }
      await _load();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _cancelRequest(TrainerLink link) async {
    await TrainerLinkService().deleteLink(link.athleteUid);
    await _load();
  }

  List<Widget> _buildGymAthletes() {
    final personal = _accepted!.map((l) => l.athleteUid).toSet();
    final athletes =
        _gymAthletes.where((a) => !personal.contains(a.uid)).toList();
    if (athletes.isEmpty) {
      return const [
        Text('El gimnasio todavía no tiene otros atletas.',
            style: TextStyle(color: Colors.grey)),
      ];
    }
    return [
      for (final athlete in athletes)
        Card(
          child: ListTile(
            leading: const Icon(Icons.fitness_center),
            title: Text(athlete.email),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                _openAthlete(athlete.uid, athlete.email, viaGym: true),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final loading = _accepted == null || _pending == null;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis atletas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sending ? null : _addAthlete,
        icon: const Icon(Icons.person_add),
        label: const Text('Agregar atleta'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Mis atletas',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_accepted!.isEmpty)
                  const Text('Todavía no tenés atletas aceptados.',
                      style: TextStyle(color: Colors.grey)),
                for (final link in _accepted!)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(link.athleteEmail),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          _openAthlete(link.athleteUid, link.athleteEmail),
                    ),
                  ),
                if (_gymMembership != null &&
                    _gymMembership!.isAccepted &&
                    _gymMembership!.isTrainer) ...[
                  const SizedBox(height: 24),
                  Text('Atletas de ${_gymMembership!.gymName}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._buildGymAthletes(),
                ],
                const SizedBox(height: 24),
                const Text('Solicitudes enviadas',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_pending!.isEmpty)
                  const Text('No tenés solicitudes pendientes.',
                      style: TextStyle(color: Colors.grey)),
                for (final link in _pending!)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.hourglass_top),
                      title: Text(link.athleteEmail),
                      subtitle: const Text('Esperando respuesta'),
                      trailing: TextButton(
                        onPressed: () => _cancelRequest(link),
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
