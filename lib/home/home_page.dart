import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_service.dart';
import '../auth/auth_gate.dart';
import '../core/utils/iso_week.dart';
import '../core/widgets/trainapp_brand.dart';
import '../workout/data/macrocycle_forjado.dart';
import '../workout/models/macrocycle_progress.dart';
import '../workout/models/routine.dart';
import '../workout/services/macrocycle_service.dart';
import '../workout/services/progression_service.dart';
import '../workout/services/routine_service.dart';
import '../workout/services/session_service.dart';
import '../gym/models/gym.dart';
import '../gym/models/gym_member.dart';
import '../gym/screens/gym_admin_page.dart';
import '../gym/screens/gym_classes_page.dart';
import '../gym/services/gym_service.dart';
import '../gym/widgets/gym_logo.dart';
import '../onboarding/tutorial/coach_marks.dart';
import '../onboarding/tutorial/tutorial_service.dart';
import '../premium/duty_picker.dart';
import '../premium/free_tier.dart';
import '../premium/premium_service.dart';
import '../profile/profile_service.dart';
import '../profile/screens/profile_page.dart';
import '../trainer/screens/my_athletes_page.dart';
import '../trainer/services/user_directory_service.dart';
import '../workout/screens/edit_routine_page.dart';
import '../workout/screens/workout_session_page.dart';
import '../workout/screens/history_page.dart';
import '../workout/widgets/exercise_demo.dart';
import '../workout/screens/routine_catalog_page.dart';
import 'weekly_progress_chart.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Routine? _routine;
  MacrocycleProgress? _macro;
  bool _loading = true;
  bool _isTrainer = false;
  GymMember? _gymMembership; // solo si está aceptada
  Gym? _gym; // gimnasio al que pertenece (logo en el home)
  Gym? _ownedGym; // gimnasio que administra
  int _chartKey = 0;
  bool _pickingDuty = false;

  // Tutorial del primer uso: elementos que se resaltan.
  final _kProfile = GlobalKey();
  final _kGymAdmin = GlobalKey();
  final _kAthletes = GlobalKey();
  final _kHistory = GlobalKey();
  final _kCatalog = GlobalKey();
  final _kEdit = GlobalKey();
  final _kLogout = GlobalKey();
  final _kFirstDay = GlobalKey();
  final _kChart = GlobalKey();
  final _kGym = GlobalKey();
  bool _tutorialRunning = false;
  final _user = FirebaseAuth.instance.currentUser;
  final _premium = PremiumService.instance.isPremium;

  @override
  void initState() {
    super.initState();
    _premium.addListener(_onPremiumChanged);
    _loadRoutine();
    _loadIsTrainer();
    _loadGym();
    // Backfill del directorio email->uid para cuentas que se registraron
    // antes de que existiera (no bloquea la carga de la pantalla).
    if (_user != null) {
      PremiumService.instance.start(_user.uid);
      UserDirectoryService()
          .ensureDirectoryEntry(_user.uid, _user.email)
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    _premium.removeListener(_onPremiumChanged);
    super.dispose();
  }

  void _onPremiumChanged() {
    if (!mounted) return;
    setState(() {}); // íconos y gráfica dependen del premium
    if (!_premium.value) _enforceFreeTier();
  }

  /// Sin premium solo se entrena con las rutinas Recomendadas: si la activa es
  /// otra (usuarios de antes, o el gimnasio le quitó el premium), se le pide
  /// elegir una. Consulta el premium al servidor antes de decidir.
  Future<void> _enforceFreeTier() async {
    final routine = _routine;
    if (_pickingDuty || routine == null) return;
    _pickingDuty = true;
    Routine? chosen;
    try {
      if (await FreeTier.isFreeRoutine(routine)) return;
      final premium = await PremiumService.instance.fetch(_user!.uid);
      if (premium || !mounted) return;
      chosen = await showDutyPicker(context, _user.uid);
    } catch (_) {
      return; // sin conexión: se revisa la próxima vez
    } finally {
      _pickingDuty = false;
    }
    if (chosen != null && mounted) {
      setState(() {
        _routine = chosen;
        _macro = null;
        _chartKey++;
      });
    }
  }

  /// La primera vez que se entra al inicio (o tras "Ver el tutorial de
  /// nuevo" en el perfil) recorre los botones y menús principales.
  Future<void> _maybeStartTutorial() async {
    final user = _user;
    if (user == null || _tutorialRunning || _pickingDuty || _routine == null) {
      return;
    }
    _tutorialRunning = true;
    final premium = _premium.value;
    // Espera a que el gimnasio y los íconos terminen de cargar.
    await TutorialService.runOnce(context, TutorialScreen.home,
        delay: const Duration(milliseconds: 600), () => [
      CoachMarkStep(
        target: _kFirstDay,
        title: 'Tus días de entrenamiento',
        body: 'Esta es tu rutina, organizada por días. Toca un día para ver '
            'sus ejercicios y pesos, y pulsa "Iniciar sesión" para entrenar: '
            'la app te guía serie por serie, con temporizador de descanso.',
      ),
      CoachMarkStep(
        target: _kGym,
        title: 'Tu gimnasio',
        body: 'Toca el logo para ir a la página de tu gimnasio y "Clases" '
            'para ver e inscribirte a sus clases grupales.',
      ),
      CoachMarkStep(
        target: _kChart,
        title: 'Tu progreso semanal',
        body: premium
            ? 'Cada barra es una semana: cuántos días entrenaste frente a los '
                'que planeaste. Una barra dorada es una semana con muchas '
                'progresiones; arriba ves tu racha.'
            : 'Aquí verás cuántos días entrenas cada semana, tu racha y tus '
                'semanas de progresión. Es una función premium: puedes '
                'probarla gratis 7 días desde tu perfil.',
      ),
      CoachMarkStep(
        target: _kCatalog,
        circle: true,
        title: 'Catálogo de rutinas',
        body: 'Cambia de rutina cuando quieras: recomendadas, por deporte, '
            'macro ciclos, ediciones limitadas o las tuyas personalizadas.',
      ),
      CoachMarkStep(
        target: _kEdit,
        circle: true,
        title: 'Editar rutina',
        body: 'Ajusta tus días y ejercicios: agrega, quita o reemplaza, y '
            'define cómo progresa cada ejercicio.',
      ),
      CoachMarkStep(
        target: _kHistory,
        circle: true,
        title: 'Historial',
        body: 'Todas tus sesiones registradas: fechas, ejercicios, series y '
            'pesos que levantaste.',
      ),
      CoachMarkStep(
        target: _kAthletes,
        circle: true,
        title: 'Mis atletas',
        body: 'Como entrenador, aquí ves a tus atletas: editas sus rutinas, '
            'revisas su historial y registras sus sesiones.',
      ),
      CoachMarkStep(
        target: _kGymAdmin,
        circle: true,
        title: 'Mi gimnasio',
        body: 'Administra tu gimnasio: miembros y su premium, clases, '
            'facturación y el perfil del gimnasio.',
      ),
      CoachMarkStep(
        target: _kProfile,
        circle: true,
        title: 'Tu perfil',
        body: 'Tus datos, tu plan (y la prueba premium gratis), la progresión '
            'automática, los extras de entrenamiento, tu gimnasio y tu '
            'entrenador. Desde aquí puedes volver a ver este tutorial.',
      ),
      CoachMarkStep(
        target: _kLogout,
        circle: true,
        title: 'Cerrar sesión',
        body: 'Sales de tu cuenta en este dispositivo. Tus datos quedan '
            'guardados en la nube.',
      ),
    ]);
    _tutorialRunning = false;
  }

  Future<void> _loadRoutine() async {
    final routine = await RoutineService().getRoutine(_user!.uid);
    MacrocycleProgress? macro;
    try {
      macro = await MacrocycleService().get(_user.uid);
    } catch (_) {
      macro = null;
    }
    if (mounted) {
      setState(() { _routine = routine; _macro = macro; _loading = false; });
      await _enforceFreeTier();
      _maybeStartTutorial();
    }
  }

  Future<void> _loadIsTrainer() async {
    try {
      final profile = await ProfileService().getProfile(_user!.uid);
      if (mounted) setState(() => _isTrainer = profile?.isTrainer ?? false);
    } catch (_) {
      // silencioso: el ícono de entrenador simplemente no aparece
    }
  }

  /// Pertenencia aceptada a un gimnasio (para el logo y el acceso de los
  /// entrenadores de planta a "Mis atletas") y el gimnasio que administra.
  Future<void> _loadGym() async {
    try {
      final service = GymService();
      final results = await Future.wait([
        service.getMembership(_user!.uid),
        service.getOwnedGym(_user.uid),
      ]);
      var membership = results[0] as GymMember?;
      if (membership != null && !membership.isAccepted) membership = null;
      final gym =
          membership == null ? null : await service.getGym(membership.gymId);
      if (mounted) {
        setState(() {
          _gymMembership = membership;
          _gym = gym;
          _ownedGym = results[1] as Gym?;
        });
      }
    } catch (_) {
      // silencioso: sin logo ni íconos del gimnasio
    }
  }

  Future<void> _openEdit() async {
    if (_routine == null) return;
    final updated = await Navigator.push<Routine>(
      context,
      MaterialPageRoute(builder: (_) => EditRoutinePage(routine: _routine!)),
    );
    if (updated != null) setState(() => _routine = updated);
  }

  Future<void> _onSessionCompleted() async {
    setState(() => _chartKey++);
    await _loadRoutine(); // refresca pesos actualizados por progresión

    // Los hitos (Séneca / Yeah Buddy) no deben romper el flujo si Firestore
    // falla puntualmente: se reintentan al terminar la próxima sesión.
    try {
      final now = DateTime.now();
      // Misma semana ISO que la gráfica de consistencia.
      final currentWeek = IsoWeek.weekNumber(now);
      final isoYear = IsoWeek.year(now);

      final totalExercises = _routine?.days
              .fold(0, (sum, d) => sum + d.exercises.length) ??
          0;
      final showSeneca = await ProgressionService().checkAndMarkSenecaMilestone(
        _user!.uid, isoYear, currentWeek, totalExercises,
      );
      if (mounted && showSeneca) {
        _showSenecaDialog();
        return;
      }

      if (_routine == null) return;
      final sessions = await SessionService().getSessionsForUser(_user.uid);
      final sessionsThisWeek = sessions
          .where((s) =>
              IsoWeek.year(s.date) == isoYear &&
              IsoWeek.weekNumber(s.date) == currentWeek)
          .length;

      if (sessionsThisWeek >= _routine!.days.length) {
        final showYeahBuddy = await ProgressionService()
            .checkAndMarkYeahBuddyMilestone(_user.uid, currentWeek);
        if (mounted && showYeahBuddy) _showYeahBuddyDialog(currentWeek);
      }
    } catch (_) {
      // silencioso: los hitos se recalculan la próxima vez
    }
  }

  void _showYeahBuddyDialog(int weekNumber) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TrainAppBrand(),
              const SizedBox(height: 20),
              const Text('🔥', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'YEAHHHH\nBUDDY!!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Semana $weekNumber COMPLETADA 💪',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Ain't nothing but a peanut!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'LIGHT WEIGHT BABY! 🏋️',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSenecaDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TrainAppBrand(),
              const SizedBox(height: 20),
              const Text('🏆', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                '¡MÁS DEL 30%\nDE PROGRESOS!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '"Una gema no puede ser pulida\nsin fricción, ni un hombre\nperfeccionado sin pruebas"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '— Séneca',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'SEGUIR PULIENDO 💎',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TrainApp'),
        actions: [
          IconButton(
            key: _kProfile,
            icon: const Icon(Icons.person_outline),
            tooltip: 'Mi perfil',
            onPressed: () async {
              final regenerated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
              if (regenerated == true) {
                setState(() { _loading = true; _chartKey++; });
                await _loadRoutine();
              }
              // El toggle "Modo entrenador" o la pertenencia a un gimnasio
              // pudieron cambiar en ProfilePage.
              await Future.wait([_loadIsTrainer(), _loadGym()]);
              // Pudo pedir "Ver el tutorial de nuevo".
              _maybeStartTutorial();
            },
          ),
          if (_ownedGym != null)
            IconButton(
              key: _kGymAdmin,
              icon: const Icon(Icons.store_outlined),
              tooltip: 'Mi gimnasio',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GymAdminPage(gym: _ownedGym!),
                  ),
                );
                await _loadGym(); // pudo cambiar el logo o el nombre
              },
            ),
          // El modo entrenador es premium (los de planta siempre lo tienen).
          if ((_isTrainer && _premium.value) ||
              (_gymMembership?.isTrainer ?? false))
            IconButton(
              key: _kAthletes,
              icon: const Icon(Icons.groups),
              tooltip: 'Mis atletas',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyAthletesPage()),
              ),
            ),
          IconButton(
            key: _kHistory,
            icon: const Icon(Icons.history),
            tooltip: 'Historial',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            ),
          ),
          IconButton(
            key: _kCatalog,
            icon: const Icon(Icons.menu_book),
            tooltip: 'Catálogo de rutinas',
            onPressed: () async {
              final activated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const RoutineCatalogPage()),
              );
              if (activated == true) {
                setState(() => _loading = true);
                await _loadRoutine();
              }
            },
          ),
          if (_routine != null)
            IconButton(
              key: _kEdit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar rutina',
              onPressed: _openEdit,
            ),
          IconButton(
            key: _kLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              PremiumService.instance.stop();
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _routine == null
              ? const Center(child: Text('No tienes una rutina asignada aún.'))
              : _RoutineView(
                  routine: _routine!,
                  gym: _gym,
                  gymAthlete: !(_gymMembership?.isTrainer ?? true),
                  premium: _premium.value,
                  macro: _macro,
                  chartKey: _chartKey,
                  onSessionCompleted: _onSessionCompleted,
                  firstDayKey: _kFirstDay,
                  chartTargetKey: _kChart,
                  gymKey: _kGym,
                ),
    );
  }
}

class _RoutineView extends StatelessWidget {
  final Routine routine;
  final Gym? gym;
  /// true si es atleta del gimnasio (se inscribe a clases); false si es
  /// entrenador de planta (solo las ve).
  final bool gymAthlete;
  final bool premium;
  final MacrocycleProgress? macro;
  final int chartKey;
  final VoidCallback onSessionCompleted;

  // Elementos que resalta el tutorial.
  final GlobalKey firstDayKey;
  final GlobalKey chartTargetKey;
  final GlobalKey gymKey;

  const _RoutineView({
    required this.firstDayKey,
    required this.chartTargetKey,
    required this.gymKey,
    required this.routine,
    required this.gym,
    required this.gymAthlete,
    required this.premium,
    required this.macro,
    required this.chartKey,
    required this.onSessionCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routine.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Semana ${routine.weekNumber} · ${routine.days.length} días',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (gym != null) ...[
              const SizedBox(width: 12),
              Column(
                key: gymKey,
                children: [
                  Tooltip(
                    message: gym!.websiteUrl?.trim().isNotEmpty == true
                        ? '${gym!.name} · Página web'
                        : '${gym!.name} · Clases grupales',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final websiteUrl = gym!.websiteUrl?.trim()            ;
            
                        // Si tiene página web, abrirla en el navegador externo.
                        if (websiteUrl != null && websiteUrl.isNotEmpty) {
                          final uri = Uri.tryParse(websiteUrl)            ;
            
                          if (uri != null &&
                              (uri.scheme == 'https' || uri.scheme == 'http') &&
                              uri.host.isNotEmpty) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                          return;
                                    }
            
                        // Si no tiene página web, conservar el comportamiento anterior.
                        if (!context.mounted) return            ;
            
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GymClassesPage(
                              gym: gym!,
                              canEnroll: gymAthlete,
                            ),
                          ),
                        );
                      },
                      child: GymLogo(
                        url: gym!.logoUrl,
                        size: 56,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GymClassesPage(
                          gym: gym!,
                          canEnroll: gymAthlete,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        'Clases',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),

        if (macro != null && !macro!.completed) ...[
          _MacrocycleBanner(macro: macro!),
          const SizedBox(height: 16),
        ],

        for (final (i, day) in routine.days.indexed) ...[
          KeyedSubtree(
            key: i == 0 ? firstDayKey : null,
            child: _DayCard(day: day, onSessionCompleted: onSessionCompleted),
          ),
          const SizedBox(height: 12),
        ],

        const Divider(height: 32),
        KeyedSubtree(
          key: chartTargetKey,
          child: WeeklyProgressChart(
            // El premium cambia la key: la gráfica se recarga con datos reales.
            key: ValueKey('$chartKey-$premium'),
            plannedDaysPerWeek: routine.days.length,
            totalRoutineExercises:
                routine.days.fold(0, (sum, d) => sum + d.exercises.length),
            locked: !premium,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Banner del macro ciclo activo: fase, énfasis y progreso por día.
class _MacrocycleBanner extends StatelessWidget {
  final MacrocycleProgress macro;
  const _MacrocycleBanner({required this.macro});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Color(0xFFC41E3A), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  macro.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'Fase ${macro.currentPhaseNumber}/${macro.totalPhases}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Día 4 · Énfasis ${macro.currentEmphasis}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final d in ForjadoPorElHierro.trackedDays)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: d == ForjadoPorElHierro.trackedDays.last ? 0 : 6),
                    child: Column(
                      children: [
                        Text('D$d',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10)),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: macro.countFor(d) /
                                ForjadoPorElHierro.sessionsPerDay,
                            minHeight: 5,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation(
                                Color(0xFFC41E3A)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${macro.countFor(d)}/${ForjadoPorElHierro.sessionsPerDay}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final RoutineDay day;
  final VoidCallback onSessionCompleted;

  const _DayCard({required this.day, required this.onSessionCompleted});

  static String _trimDouble(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

  IconData get _icon {
    return switch (day.focus) {
      'push'  => Icons.fitness_center,
      'pull'  => Icons.sports_gymnastics,
      'legs'  => Icons.directions_run,
      'upper' => Icons.accessibility_new,
      'lower' => Icons.directions_walk,
      'core'  => Icons.self_improvement,
      _       => Icons.fitness_center,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(_icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(
          'Día ${day.dayNumber} · ${day.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${day.exercises.length} ejercicios'),
        children: [
          for (final ex in day.exercises)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(ex.name),
              subtitle: Text(
                '${ex.sets} series · ${ex.repsMin}–${ex.repsMax} reps · ${ex.restSeconds}s descanso',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ex.currentWeight > 0
                      ? Text(
                          '${_trimDouble(ex.currentWeight)} ${ex.weightUnit}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : Text('— ${ex.weightUnit}',
                          style: const TextStyle(color: Colors.grey)),
                  ExerciseDemoButton(
                      exerciseId: ex.exerciseId, exerciseName: ex.name),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar sesión'),
                onPressed: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    int today = 0;
                    try {
                      today = await SessionService()
                          .countSessionsOnDay(uid, DateTime.now());
                    } catch (_) {}
                    if (today >= 1 && context.mounted) {
                      final proceed = await _showRestAdvisory(context);
                      if (proceed != true) return;
                    }
                  }
                  if (!context.mounted) return;
                  final completed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkoutSessionPage(day: day),
                    ),
                  );
                  if (completed == true) onSessionCompleted();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso al iniciar una 2ª (o más) sesión el mismo día. No bloquea: el usuario
/// puede entrenar igual, pero se le recuerda que el descanso es progreso.
/// Devuelve `true` si decide entrenar de todas formas.
Future<bool?> _showRestAdvisory(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('El descanso también forja'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se recomienda una sola sesión por día. El descanso no es una '
              'pausa del progreso: es cuando el músculo se reconstruye más '
              'fuerte.',
            ),
            SizedBox(height: 16),
            Text(
              '"Ninguna cosa grande se crea de repente, como tampoco un '
              'racimo de uvas o un higo."',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              '— Epicteto',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 12,
                color: Color(0xFFC41E3A),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Mejor descanso'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Entrenar igual'),
        ),
      ],
    ),
  );
}
