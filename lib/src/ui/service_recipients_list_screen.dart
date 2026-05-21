import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/ui/invoice_color_scheme.dart';
import 'package:app_taxi_invoice/src/ui/service_recipient_edit_screen.dart';
import 'package:app_taxi_invoice/src/ui/store_sync_status.dart';
import 'package:flutter/material.dart';

/// Lista sačuvanih naručilaca usluga (otvaranje / uređivanje).
final class ServiceRecipientsListScreen extends StatelessWidget {
  const ServiceRecipientsListScreen({required this.store, super.key});

  final InvoiceStoreController store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Naručioci usluga',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = store.serviceRecipientsSorted;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Još nema sačuvanih naručilaca.\n\nDodajte prvog zelenim '
                  'dugmetom.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final r = list[index];
              final scheme = theme.colorScheme;
              final detailLines = [
                if (r.address.isNotEmpty) r.address,
                if (r.jib.isNotEmpty) 'JIB: ${r.jib}',
              ];
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: scheme.outline.withValues(alpha: 0.65),
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    if (!store.canWrite) {
                      showInvoiceStoreReadOnlyMessage(context, store);
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ServiceRecipientEditScreen(
                          store: store,
                          existing: r,
                        ),
                      ),
                    );
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    title: Text(
                      r.name.isEmpty ? '(bez naziva)' : r.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: detailLines.isEmpty
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              detailLines.join('\n'),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.4,
                              ),
                            ),
                          ),
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 32,
                      color: scheme.invoiceAccent,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (!store.canWrite) {
            showInvoiceStoreReadOnlyMessage(context, store);
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ServiceRecipientEditScreen(store: store),
            ),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Novi naručilac'),
      ),
    );
  }
}
