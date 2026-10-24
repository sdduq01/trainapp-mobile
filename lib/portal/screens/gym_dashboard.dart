import 'package:flutter/material.dart';

import '../../gym/models/gym.dart';
import '../../gym/models/gym_member.dart';
import '../../gym/widgets/gym_logo.dart';
import '../../gym/widgets/gym_members_panel.dart';
import '../widgets/portal_scaffold.dart';
import 'admin_requests_section.dart';
import 'gym_profile_section.dart';

/// Panel del dueño del gimnasio (Miembros, Perfil) y, para el admin de
/// TrainApp, las solicitudes de alta. Menú lateral en pantallas anchas e
/// inferior en el celular.
class GymDashboard extends StatefulWidget {
  final Gym? gym;
  final bool isAdmin;
  final ValueChanged<Gym> onGymChanged;

  const GymDashboard({
    required this.gym,
    required this.isAdmin,
    required this.onGymChanged,
    super.key,
  });

  @override
  State<GymDashboard> createState() => _GymDashboardState();
}

enum _Section { members, profile, requests }

class _GymDashboardState extends State<GymDashboard> {
  int _index = 0;

  List<_Section> get _sections => [
        if (widget.gym != null) ...[_Section.members, _Section.profile],
        if (widget.isAdmin) _Section.requests,
      ];

  static const _icons = {
    _Section.members: Icons.groups_outlined,
    _Section.profile: Icons.store_outlined,
    _Section.requests: Icons.admin_panel_settings_outlined,
  };
  static const _labels = {
    _Section.members: 'Miembros',
    _Section.profile: 'Perfil',
    _Section.requests: 'Solicitudes',
  };

  Widget _content(_Section section) {
    final gym = widget.gym;
    switch (section) {
      case _Section.members:
        return _MembersSection(key: ValueKey(gym!.id), gym: gym);
      case _Section.profile:
        return GymProfileSection(gym: gym!, onSaved: widget.onGymChanged);
      case _Section.requests:
        return const AdminRequestsSection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    final index = _index.clamp(0, sections.length - 1);
    final content = _content(sections[index]);

    if (sections.length == 1) return PortalScaffold(body: content);

    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      return PortalScaffold(
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
    return PortalScaffold(
      body: Column(
        children: [
          Expanded(child: content),
          NavigationBar(
            selectedIndex: index,
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
