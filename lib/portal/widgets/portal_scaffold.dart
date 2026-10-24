import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/trainapp_brand.dart';

/// Esqueleto común del portal: barra negra con la marca, el email de la
/// sesión y "Salir", y el contenido centrado con un ancho máximo legible.
class PortalScaffold extends StatelessWidget {
  final Widget body;

  const PortalScaffold({required this.body, super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final wide = MediaQuery.sizeOf(context).width >= 600;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        titleSpacing: 16,
        title: Row(
          children: [
            const TrainAppBrand(markSize: 28),
            if (wide) ...[
              const SizedBox(width: 12),
              const Text(
                'Gimnasios',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ],
        ),
        actions: [
          if (user != null) ...[
            if (wide)
              Center(
                child: Text(
                  user.email ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Salir',
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: body,
    );
  }
}

/// Contenido desplazable y centrado con ancho máximo.
class PortalPage extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;

  const PortalPage({required this.children, this.maxWidth = 760, super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}
