import 'package:app_taxi_invoice/src/pdf/invoice_pdf_builder.dart';
import 'package:app_taxi_invoice/src/ui/invoice_color_scheme.dart';
import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/ui/invoice_date_formats.dart';
import 'package:app_taxi_invoice/src/ui/invoice_detail_screen.dart';
import 'package:app_taxi_invoice/src/ui/invoice_editor_screen.dart';
import 'package:app_taxi_invoice/src/ui/service_recipients_list_screen.dart';
import 'package:app_taxi_invoice/src/ui/settings_screen.dart';
import 'package:flutter/material.dart';

final class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.store, required this.settings, super.key});

  final InvoiceStoreController store;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    if (!store.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final list = store.invoicesSortedByIssueDate;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Računi',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_outlined, size: 26),
            tooltip: 'Naručioci usluga',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ServiceRecipientsListScreen(store: store),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 26),
            tooltip: 'Postavke',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      SettingsScreen(settings: settings, store: store),
                ),
              );
            },
          ),
        ],
      ),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nema sačuvanih računa.\n\nDodajte prvi pritiskom na '
                  'zeleno dugme „Novi račun” dolje.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.5),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final inv = list[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.65),
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => InvoiceDetailScreen(
                            store: store,
                            settings: settings,
                            invoice: inv,
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
                        invoiceDocumentTitle(inv),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Izdavanje: '
                          '${formatInvoiceDateMedium(inv.issueDate)} '
                          '· broj stavki: ${inv.lines.length}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(height: 1.4),
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        size: 32,
                        color: Theme.of(context).colorScheme.invoiceAccent,
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  InvoiceEditorScreen(store: store, settings: settings),
            ),
          );
        },
        icon: const Icon(Icons.add, size: 26),
        label: const Text('Novi račun'),
      ),
    );
  }
}
