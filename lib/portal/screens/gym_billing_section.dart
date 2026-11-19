import 'package:flutter/material.dart';

import '../../gym/models/billing.dart';
import '../../gym/models/gym.dart';
import '../../gym/services/billing_service.dart';
import '../widgets/portal_scaffold.dart';

/// Cómo paga el gimnasio. Por ahora el pago es manual (transferencia) y el
/// admin lo registra en "Cobros".
const String kBillingPaymentInstructions =
    'Paga por transferencia dentro de los primeros ${Billing.dueDay} días del '
    'mes y envía el comprobante a trainappdev@gmail.com indicando el nombre '
    'de tu gimnasio y el mes. Una factura vencida puede llevar a suspender el '
    'premium de tus atletas.';

/// Facturación del dueño del gimnasio: proyección del mes en curso y
/// facturas generadas.
class GymBillingSection extends StatefulWidget {
  final Gym gym;

  const GymBillingSection({required this.gym, super.key});

  @override
  State<GymBillingSection> createState() => _GymBillingSectionState();
}

class _GymBillingSectionState extends State<GymBillingSection> {
  List<BillingAthlete>? _athletes;
  List<GymInvoice>? _invoices;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final service = BillingService();
      final results = await Future.wait([
        service.getBillingAthletes(widget.gym.id),
        service.getInvoices(widget.gym.id),
      ]);
      if (!mounted) return;
      setState(() {
        _athletes = results[0] as List<BillingAthlete>;
        _invoices = results[1] as List<GymInvoice>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final athletes = _athletes;
    final invoices = _invoices;
    return PortalPage(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Facturación',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${Billing.formatCop(Billing.pricePerAthlete)} al mes por cada atleta '
          'con premium, proporcional a los días que lo tenga. El mes en que se '
          'le activa por primera vez es gratis.',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Text('No se pudo cargar la facturación: $_error',
              style: const TextStyle(color: Colors.red))
        else if (athletes == null || invoices == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (widget.gym.billingExempt)
            const Card(
              child: ListTile(
                leading: Icon(Icons.verified_outlined, color: Colors.green),
                title: Text('Exento de cobro'),
                subtitle: Text(
                  'Tu gimnasio no paga por el premium de sus atletas: puedes '
                  'activárselo a todos los que quieras sin costo.',
                ),
              ),
            )
          else ...[
            _ProjectionCard(athletes: athletes),
            const SizedBox(height: 16),
            const Card(
              child: ListTile(
                leading: Icon(Icons.account_balance_outlined),
                title: Text('Cómo pagar'),
                subtitle: Text(kBillingPaymentInstructions),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text('Facturas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (invoices.isEmpty)
            const Text(
              'Todavía no hay facturas. La primera se genera el día 1 del mes '
              'siguiente al primero en que tengas atletas que se cobran.',
              style: TextStyle(color: Colors.grey),
            )
          else
            for (final inv in invoices) InvoiceCard(invoice: inv),
        ],
      ],
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  final List<BillingAthlete> athletes;

  const _ProjectionCard({required this.athletes});

  @override
  Widget build(BuildContext context) {
    final now = Billing.bogotaMonthOf(DateTime.now());
    final p = BillingProjection.forMonth(athletes, now.year, now.month);
    final theme = Theme.of(context);
    final nextMonthStart = Billing.monthStart(now.year, now.month + 1);

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Factura proyectada de ${Billing.monthLabel(now.year, now.month)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              Billing.formatCop(p.total),
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            Text(
              '${p.billable.length} atletas · '
              '${Billing.formatCop(Billing.pricePerAthlete)} por mes completo',
            ),
            const SizedBox(height: 8),
            Text(
              'Se factura el ${Billing.formatDay(nextMonthStart)} y se paga '
              'hasta el ${Billing.formatDay(p.dueAt)}. Es una proyección que '
              'supone que el premium sigue activo hasta fin de mes: si lo '
              'quitas antes, solo se cobran los días que lo tuvo.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            if (p.billable.isNotEmpty) ...[
              const Divider(height: 28),
              const Text('Se cobran este mes',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              for (final a in p.billable)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(a.email)),
                      Text(
                        '${a.billableDaysIn(now.year, now.month)} días'
                        '${a.active ? '' : ' (retirado)'} · '
                        '${Billing.formatCop(a.amountIn(now.year, now.month))}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
            if (p.freeMonth.isNotEmpty) ...[
              const Divider(height: 28),
              const Text('En su mes gratis',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              for (final a in p.freeMonth)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(a.email)),
                      Text(
                        'se cobra desde el ${Billing.formatDay(a.freeFrom)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Factura generada: mes, total, estado y detalle de atletas. [trailing]
/// permite al admin agregar acciones.
class InvoiceCard extends StatelessWidget {
  final GymInvoice invoice;
  final Widget? actions;
  final bool showGymName;

  const InvoiceCard({
    required this.invoice,
    this.actions,
    this.showGymName = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final title = showGymName ? inv.gymName : inv.monthLabel;
    return Card(
      child: ExpansionTile(
        title: Text(title[0].toUpperCase() + title.substring(1)),
        subtitle: Text(
          '${inv.count} atletas · ${Billing.formatCop(inv.total)} · '
          '${inv.isPaid ? 'pagada${inv.paidAt != null ? ' el ${Billing.formatDay(inv.paidAt!)}' : ''}' : 'vence el ${Billing.formatDay(inv.dueAt)}'}',
        ),
        trailing: InvoiceStatusChip(invoice: inv),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in inv.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(l.email)),
                  Text(
                    '${l.days} de ${inv.daysInMonth} días · '
                    '${Billing.formatCop(l.amount)}',
                  ),
                ],
              ),
            ),
          if (inv.paidNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Pago: ${inv.paidNote}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          if (actions != null) ...[
            const SizedBox(height: 12),
            actions!,
          ],
        ],
      ),
    );
  }
}

class InvoiceStatusChip extends StatelessWidget {
  final GymInvoice invoice;

  const InvoiceStatusChip({required this.invoice, super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color) = invoice.isPaid
        ? ('Pagada', Colors.green)
        : invoice.isOverdue()
            ? ('Vencida', Colors.red)
            : ('Pendiente', Colors.orange);
    return Chip(
      label: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      side: BorderSide(color: color),
      backgroundColor: color.withValues(alpha: 0.08),
      visualDensity: VisualDensity.compact,
    );
  }
}
