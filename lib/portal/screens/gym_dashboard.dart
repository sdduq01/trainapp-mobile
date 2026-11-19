import 'package:flutter/material.dart';

import '../../gym/models/gym.dart';
import '../../gym/models/gym_member.dart';
import '../../gym/widgets/gym_logo.dart';
import '../../gym/widgets/gym_members_panel.dart';
import '../widgets/portal_scaffold.dart';
import 'admin_billing_section.dart';
import 'admin_requests_section.dart';
import 'gym_billing_section.dart';
import 'gym_classes_section.dart';
import 'gym_profile_section.dart';

/// Panel del dueño del gimnasio (Miembros, Clases, Facturación, Perfil), del
/// entrenador de planta (solo Clases) y, para el admin de TrainApp, las
/// solicitudes de alta y los cobros. Menú lateral en pantallas anchas e
/// inferior en el celular.
class GymDashboard extends StatefulWidget {
  final Gym? gym;
  final bool isAdmin;

  /// false para el entrenador de planta: solo ve Clases.
  final bool isOwner;
  final ValueChanged<Gym> onGymChanged;

  /// Abierto desde la app (Inicio → Mi gimnasio): barra normal con "volver"
  /// en lugar de la barra del portal con "Salir".
  final bool inApp;

  const GymDashboard({
    required this.gym,
    required this.isAdmin,
    this.isOwner = true,
    required this.onGymChanged,
    this.inApp = false,
    super.key,
  });

  @override
  State<GymDashboard> createState() => _GymDashboardState();
}

enum _Section { members, classes, billing, profile, requests, adminBilling }

class _GymDashboardState extends State<GymDashboard> {
  int _index = 0;

  List<_Section> get _sections => [
        if (widget.gym != null && widget.isOwner) _Section.members,
        if (widget.gym != null) _Section.classes,
        if (widget.gym != null && widget.isOwner) _Section.billing,
        if (widget.gym != null && widget.isOwner) _Section.profile,
        if (widget.isAdmin) _Section.requests,
        if (widget.isAdmin) _Section.adminBilling,
      ];

  static const _icons = {
    _Section.members: Icons.groups_outlined,
    _Section.classes: Icons.event_note_outlined,
    _Section.billing: Icons.receipt_long_outlined,
    _Section.profile: Icons.store_outlined,
    _Section.requests: Icons.admin_panel_settings_outlined,
    _Section.adminBilling: Icons.payments_outlined,
  };
  static const _labels = {
    _Section.members: 'Miembros',
    _Section.classes: 'Clases',
    _Section.billing: 'Facturación',
    _Section.profile: 'Perfil',
    _Section.requests: 'Solicitudes',
    _Section.adminBilling: 'Cobros',
  };

  Widget _content(_Section section) {
    final gym = widget.gym;
    switch (section) {
      case _Section.members:
        return _MembersSection(key: ValueKey(gym!.id), gym: gym);
      case _Section.classes:
        return GymClassesSection(key: ValueKey('classes_${gym!.id}'), gym: gym);
      case _Section.billing:
        return GymBillingSection(key: ValueKey('billing_${gym!.id}'), gym: gym);
      case _Section.profile:
        return GymProfileSection(gym: gym!, onSaved: widget.onGymChanged);
      case _Section.requests:
        return const AdminRequestsSection();
      case _Section.adminBilling:
        return const AdminBillingSection();
    }
  }

  Widget _scaffold({required Widget body}) => widget.inApp
      ? Scaffold(
          appBar: AppBar(title: Text(widget.gym?.name ?? 'Mi gimnasio')),
          body: body,
        )
      : PortalScaffold(body: body);

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    final index = _index.clamp(0, sections.length - 1);
    final content = _content(sections[index]);

    if (sections.length == 1) return _scaffold(body: content);

    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      return _scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final s in sections)
                  NavigationRailDestination(
                    icon: Icon(_icons[s]),
                    label: Text(_labels[s]!),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }
    return _scaffold(
      body: Column(
        children: [
          Expanded(child: content),
          NavigationBar(
            selectedIndex: index,
            // Con muchas secciones los nombres no caben en el celular.
            labelBehavior: sections.length > 4
                ? NavigationDestinationLabelBehavior.onlyShowSelected
                : NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (final s in sections)
                NavigationDestination(
                  icon: Icon(_icons[s]),
                  label: _labels[s]!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MembersSection extends StatefulWidget {
  final Gym gym;

  const _MembersSection({required this.gym, super.key});

  @override
  State<_MembersSection> createState() => _MembersSectionState();
}

class _MembersSectionState extends State<_MembersSection> {
  List<GymMember>? _members;

  @override
  Widget build(BuildContext context) {
    final members = _members;
    int count(bool trainer) => members
            ?.where((m) => m.isAccepted && m.isTrainer == trainer)
            .length ??
        0;
    final pending = members?.where((m) => !m.isAccepted).length ?? 0;

    return PortalPage(
      children: [
        Row(
          children: [
            GymLogo(url: widget.gym.logoUrl, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.gym.name,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  if (widget.gym.city.isNotEmpty)
                    Text(widget.gym.city,
                        style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.sports, size: 18),
              label: Text('${count(true)} entrenadores'),
            ),
            Chip(
              avatar: const Icon(Icons.person, size: 18),
              label: Text('${count(false)} atletas'),
            ),
            Chip(
              avatar: const Icon(Icons.workspace_premium, size: 18),
              label: Text(
                  '${members?.where((m) => m.hasPremium).length ?? 0} con premium'),
            ),
            if (pending > 0)
              Chip(
                avatar: const Icon(Icons.hourglass_top, size: 18),
                label: Text('$pending invitaciones pendientes'),
              ),
          ],
        ),
        const SizedBox(height: 24),
        GymMembersPanel(
          gym: widget.gym,
          onChanged: (m) => setState(() => _members = m),
        ),
      ],
    );
  }
}
