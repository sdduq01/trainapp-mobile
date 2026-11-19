import 'package:flutter/material.dart';

import '../../portal/screens/gym_dashboard.dart';
import '../models/gym.dart';

/// Pantalla del dueño del gimnasio en la app: las mismas secciones del portal
/// web (Miembros, Clases, Facturación y Perfil).
class GymAdminPage extends StatefulWidget {
  final Gym gym;

  const GymAdminPage({required this.gym, super.key});

  @override
  State<GymAdminPage> createState() => _GymAdminPageState();
}

class _GymAdminPageState extends State<GymAdminPage> {
  late Gym _gym = widget.gym;

  @override
  Widget build(BuildContext context) {
    return GymDashboard(
      gym: _gym,
      isAdmin: false,
      inApp: true,
      onGymChanged: (g) => setState(() => _gym = g),
    );
  }
}
