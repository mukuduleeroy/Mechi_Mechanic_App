import 'package:material_ui/material_ui.dart';
import '../../core/design_system/design_system.dart';
import 'domain.dart';

class CostPanel extends StatelessWidget {
  const CostPanel(this.quote, {super.key});
  final Quote quote;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      children: [
        InfoRow('Labour', usd(quote.labour)),
        InfoRow('Parts', usd(quote.parts)),
        InfoRow('Call-out fee', usd(quote.callout)),
        const Divider(color: Mechi.line),
        InfoRow('Total (USD)', usd(quote.total), bold: true),
      ],
    ),
  );
}

/// Approved payment selector. A null callback disables all choices.
class PaymentMethodPicker extends StatelessWidget {
  const PaymentMethodPicker({
    super.key,
    required this.method,
    required this.onChanged,
  });

  final PaymentMethod method;
  final ValueChanged<PaymentMethod>? onChanged;

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: RadioGroup<PaymentMethod>(
      groupValue: method,
      onChanged: (value) {
        if (value != null) onChanged?.call(value);
      },
      child: Column(
        children: [
          for (final option in PaymentMethod.values)
            RadioListTile<PaymentMethod>(
              enabled: onChanged != null,
              value: option,
              secondary: Icon(
                switch (option) {
                  PaymentMethod.ecoCash => LucideIcons.smartphone,
                  PaymentMethod.card => LucideIcons.creditCard,
                  PaymentMethod.zimswitch => LucideIcons.landmark,
                  PaymentMethod.cash => LucideIcons.banknote,
                },
                size: 21,
                color: Mechi.navy,
              ),
              title: Text(option.label),
              controlAffinity: ListTileControlAffinity.trailing,
              subtitle: Text(
                option == PaymentMethod.cash
                    ? 'Confirm after handing over cash'
                    : 'Demo payment',
              ),
            ),
        ],
      ),
    ),
  );
}

/// Receipt paper and reduced-motion-aware printer reveal for a paid job.
class ServiceReceipt extends StatelessWidget {
  const ServiceReceipt({
    super.key,
    required this.job,
    required this.mechanicName,
    required this.date,
    required this.printCount,
  });

  final Job job;
  final String mechanicName;
  final String date;
  final int printCount;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        children: [
          Container(
            height: 16,
            decoration: BoxDecoration(
              color: Mechi.pale,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: Mechi.muted,
            ),
          ),
          TweenAnimationBuilder<double>(
            key: ValueKey(printCount),
            tween: Tween(begin: 0, end: 1),
            duration: Mechi.animate(context, Mechi.printMotion),
            curve: Mechi.curve,
            builder: (_, value, child) => ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: value,
                child: child,
              ),
            ),
            child: Container(
              color: Mechi.paper,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(16),
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontFamily: Mechi.mono, fontSize: 11),
                child: Column(
                  children: [
                    const MechiLogo(height: 44),
                    const Text('DEMONSTRATION SERVICE RECEIPT'),
                    const SizedBox(height: 8),
                    const Divider(color: Mechi.line),
                    InfoRow('Receipt', job.receiptId),
                    InfoRow('Job', job.id),
                    InfoRow('Date (Harare)', date),
                    InfoRow('Mechanic', mechanicName),
                    InfoRow('Vehicle', job.request.vehicle.name),
                    InfoRow('Service', job.request.problem),
                    const Divider(color: Mechi.line),
                    InfoRow('Labour', usd(job.quote!.labour)),
                    InfoRow('Parts', usd(job.quote!.parts)),
                    InfoRow('Call-out', usd(job.quote!.callout)),
                    const Divider(color: Mechi.line),
                    InfoRow('TOTAL USD', usd(job.quote!.total), bold: true),
                    InfoRow('Method', job.method!.label),
                    const InfoRow('Status', 'DEMO PAID', bold: true),
                    const SizedBox(height: 10),
                    ExcludeSemantics(
                      child: SizedBox(
                        height: 22,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < 42; i++)
                              Container(
                                width: i % 4 == 0 ? 3 : 1.8,
                                margin: EdgeInsets.only(
                                  right: i % 3 == 0 ? 2.4 : 1.4,
                                ),
                                color: Mechi.navy,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class PaymentResultDialog extends StatefulWidget {
  const PaymentResultDialog({
    super.key,
    required this.process,
    required this.amount,
    required this.method,
    required this.onReceipt,
  });
  final Future<bool?> Function() process;
  final String amount;
  final PaymentMethod method;
  final VoidCallback onReceipt;
  @override
  State<PaymentResultDialog> createState() => _PaymentResultDialogState();
}

class _PaymentResultDialogState extends State<PaymentResultDialog> {
  late final result = Future<bool?>.microtask(widget.process);
  @override
  Widget build(BuildContext context) => FutureBuilder<bool?>(
    future: result,
    builder: (context, snapshot) {
      final done = snapshot.connectionState == ConnectionState.done;
      final paid = snapshot.data == true;
      return PopScope(
        canPop: done,
        child: AlertDialog(
          title: Text(
            !done
                ? 'Processing payment'
                : paid
                ? 'Payment successful'
                : 'Payment failed',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!done)
                const CircularProgressIndicator()
              else
                Icon(
                  paid ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
                  color: paid ? Mechi.navy : Mechi.error,
                  size: 48,
                ),
              const SizedBox(height: 12),
              Text(
                '${widget.amount} USD · ${widget.method.label}',
                textAlign: TextAlign.center,
              ),
              if (paid)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Your receipt is ready.'),
                ),
            ],
          ),
          actions: done
              ? [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(paid ? 'Done' : 'Back to payment'),
                  ),
                  if (paid)
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onReceipt();
                      },
                      child: const Text('Print receipt'),
                    ),
                ]
              : null,
        ),
      );
    },
  );
}
