import 'package:flutter/material.dart';

import '../../gym/models/billing.dart';
import '../../gym/models/gym.dart';
import '../../gym/services/billing_service.dart';
import '../widgets/portal_scaffold.dart';
import 'gym_billing_section.dart';

/// Cobros (solo admin de TrainApp): facturas de un mes de todos los
/// gimnasios, registro de pagos y suspensión de gimnasios en mora.
class AdminBillingSection extends StatefulWidget {
  const AdminBillingSection({super.key});

  @override
  State<AdminBillingSection> createState() => _AdminBillingSectionState();
}

class _AdminBillingSectionState extends State<AdminBillingSection> {
  /// Últimos 12 meses ya cerrados (el actual aún no tiene factura).
  late final List<({int year, int month})> _months = () {
    final now = Billing.bogotaMonthOf(DateTime.now());
    return [
      for (var i = 1; i <= 12; i++)
        () {
          final d = DateTime.utc(now.year, now.month - i);
          return (year: d.year, month: d.month);
        }(),
    ];
  }();

  late ({int year, int month}) _month = _months.first;
  List<(Gym, GymInvoice?)>? _rows;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _load() async {
    setState(() => _rows = null);
    try {
      final service = BillingService();
      final gyms = await service.getAllGyms();
      final id = Billing.monthId(_month.year, _month.month);
      final invoices =
          await Future.wait(gyms.map((g) => service.getInvoice(g.id, id)));
      if (!mounted) return;
      setState(() => _rows = [
            for (var i = 0; i < gyms.length; i++) (gyms[i], invoices[i]),
          ]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _rows = []);
      _showMessage('No se pudieron cargar los cobros: $e');
    }
  }

  Future<void> _markPaid(GymInvoice inv) async {
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Registrar pago de ${inv.gymName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${inv.monthLabel}: ${Billing.formatCop(inv.total)}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Referencia (opcional)',
                hintText: 'Transferencia, comprobante…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Marcar pagada'),
          ),
        ],
      ),
    );
    if (note == null) return;
    await _run(() => BillingService().setPaid(inv, paid: true, note: note));
  }

  Future<void> _toggleSuspended(Gym gym) async {
    final suspend = gym.status != 'suspended';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(suspend ? 'Suspender gimnasio' : 'Reactivar gimnasio'),
        content: Text(suspend
            ? 'Nadie de ${gym.name} tendrá premium (dueño, entrenadores ni '
                'atletas) hasta que lo reactives. Mientras esté suspendido no '
                'se factura.'
            : 'Se le devuelve el premium al dueño, a los entrenadores y a los '
                'atletas que lo tenían activado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: suspend
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(suspend ? 'Suspender' : 'Reactivar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => BillingService().setGymSuspended(gym.id, suspend));
  }

  Future<void> _toggleExempt(Gym gym) async {
    final exempt = !gym.billingExempt;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(exempt ? 'Eximir de cobro' : 'Quitar exención'),
        content: Text(exempt
            ? '${gym.name} no recibirá facturas: sus atletas pueden tener '
                'premium sin costo (aliados, pruebas gratuitas).'
            : '${gym.name} pagará por sus atletas premium que ya tuvieron su '
                'mes gratis, incluido el mes en curso (por los días con '
                'premium). La factura se genera el día 1 del mes siguiente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(exempt ? 'Eximir' : 'Quitar exención'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => BillingService().setBillingExempt(gym.id, exempt));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) _showMessage('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final invoices = rows?.map((r) => r.$2).whereType<GymInvoice>().toList();
    final billed = invoices?.fold<int>(0, (acc, i) => acc + i.total) ?? 0;
    final paid = invoices
            ?.where((i) => i.isPaid)
            .fold<int>(0, (acc, i) => acc + i.total) ??
        0;

    return PortalPage(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Cobros',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<({int year, int month})>(
          initialValue: _month,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Mes facturado',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (m) {
            if (m == null) return;
            setState(() => _month = m);
            _load();
          },
          items: [
            for (final m in _months)
              DropdownMenuItem(
                value: m,
                child: Text(Billing.monthLabel(m.year, m.month)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows != null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BillingStat(label: 'Facturado', value: billed),
              BillingStat(label: 'Recibido', value: paid, color: Colors.green),
              BillingStat(
                  label: 'Por cobrar', value: billed - paid, color: Colors.orange),
            ],
          ),
        if (_busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 16),
        if (rows == null)
          const Center(child: CircularProgressIndicator())
        else if (rows.isEmpty)
          const Text('No hay gimnasios.', style: TextStyle(color: Colors.grey))
        else
          for (final (gym, inv) in rows)
            AdminGymBillingCard(
              gym: gym,
              invoice: inv,
              busy: _busy,
              onMarkPaid: inv == null ? null : () => _markPaid(inv),
              onUndoPaid: inv == null
                  ? null
                  : () => _run(() => BillingService().setPaid(inv, paid: false)),
              onToggleExempt: () => _toggleExempt(gym),
              onToggleSuspended: () => _toggleSuspended(gym),
            ),
      ],
    );
  }
}

/// Cifra del resumen del mes (facturado, recibido, por cobrar).
class BillingStat extends StatelessWidget {
  final String label;
  final int value;
  final Color? color;

  const BillingStat({required this.label, required this.value, this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            Billing.formatCop(value),
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

/// Un gimnasio en "Cobros": su factura del mes (si tiene), su estado y las
/// acciones del admin, apiladas para que quepan en el celular.
class AdminGymBillingCard extends StatelessWidget {
  final Gym gym;
  final GymInvoice? invoice;
  final bool busy;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onUndoPaid;
  final VoidCallback onToggleExempt;
  final VoidCallback onToggleSuspended;

  const AdminGymBillingCard({
    required this.gym,
    required this.invoice,
    required this.busy,
    required this.onMarkPaid,
    required this.onUndoPaid,
    required this.onToggleExempt,
    required this.onToggleSuspended,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final suspended = gym.status == 'suspended';
    final small = Theme.of(context).textTheme.bodySmall;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    gym.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (inv != null) ...[
                  const SizedBox(width: 8),
                  InvoiceStatusChip(invoice: inv),
                ],
              ],
            ),
            if (suspended || gym.billingExempt) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (suspended) const _Tag('Suspendido', Colors.red),
                  if (gym.billingExempt) const _Tag('Exento de cobro', Colors.green),
                ],
              ),
            ],
            const SizedBox(height: 6),
            if (inv == null)
              Text('Sin factura este mes', style: small)
            else ...[
              Text(
                '${Billing.formatCop(inv.total)} · ${inv.count} atletas',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              Text(
                inv.isPaid
                    ? 'Pagada${inv.paidAt != null ? ' el ${Billing.formatDay(inv.paidAt!)}' : ''}'
                        '${inv.paidNote.isNotEmpty ? ' · ${inv.paidNote}' : ''}'
                    : 'Vence el ${Billing.formatDay(inv.dueAt)}',
                style: small,
              ),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  dense: true,
                  title: const Text('Ver detalle', style: TextStyle(fontSize: 13)),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final l in inv.lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.email, overflow: TextOverflow.ellipsis),
                            Text(
                              '${l.days} de ${inv.daysInMonth} días · '
                              '${Billing.formatCop(l.amount)}',
                              style: small,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const Divider(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 0,
              children: [
                if (inv != null && !inv.isPaid)
                  TextButton.icon(
                    onPressed: busy ? null : onMarkPaid,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Marcar pagada'),
                  ),
                if (inv != null && inv.isPaid)
                  TextButton.icon(
                    onPressed: busy ? null : onUndoPaid,
                    icon: const Icon(Icons.undo),
                    label: const Text('Deshacer pago'),
                  ),
                TextButton.icon(
                  onPressed: busy ? null : onToggleExempt,
                  icon: Icon(gym.billingExempt
                      ? Icons.money_off
                      : Icons.verified_outlined),
                  label: Text(gym.billingExempt ? 'Quitar exención' : 'Eximir'),
                ),
                TextButton.icon(
                  onPressed: busy ? null : onToggleSuspended,
                  icon: Icon(suspended ? Icons.play_arrow : Icons.block,
                      color: suspended ? null : Colors.red),
                  label: Text(
                    suspended ? 'Reactivar' : 'Suspender',
                    style: TextStyle(color: suspended ? null : Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
