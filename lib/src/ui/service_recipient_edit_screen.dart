import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/ui/store_sync_status.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Formular za novog ili postojećeg naručioca usluga.
final class ServiceRecipientEditScreen extends StatefulWidget {
  const ServiceRecipientEditScreen({
    required this.store,
    this.existing,
    super.key,
  });

  final InvoiceStoreController store;
  final ServiceRecipient? existing;

  @override
  State<ServiceRecipientEditScreen> createState() =>
      _ServiceRecipientEditScreenState();
}

final class _ServiceRecipientEditScreenState
    extends State<ServiceRecipientEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _jib;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _name = TextEditingController(text: ex?.name ?? '');
    _address = TextEditingController(text: ex?.address ?? '');
    _jib = TextEditingController(text: ex?.jib ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _jib.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!widget.store.canWrite) {
      showInvoiceStoreReadOnlyMessage(context, widget.store);
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unesite naziv naručioca.')));
      return;
    }
    final recipient = ServiceRecipient(
      id: widget.existing?.id ?? _uuid.v4(),
      name: name,
      address: _address.text.trim(),
      jib: _jib.text.trim(),
    );
    try {
      await widget.store.upsertServiceRecipient(recipient);
    } catch (e) {
      if (mounted) {
        showInvoiceStoreMutationError(context, e);
      }
      return;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final ex = widget.existing;
    if (ex == null) {
      return;
    }
    if (!widget.store.canWrite) {
      showInvoiceStoreReadOnlyMessage(context, widget.store);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Obrisati naručioca iz liste?'),
        content: Text(
          '${ex.name} će nestati iz brzog odabira za nove račune.\n\n'
          'Računi koji su već sačuvani ostaju isti i zadržavaju podatke na PDF-u.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Zadrži u listi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši iz liste'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await widget.store.deleteServiceRecipient(ex.id);
      } catch (e) {
        if (mounted) {
          showInvoiceStoreMutationError(context, e);
        }
        return;
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.existing;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(ex == null ? 'Novi naručilac' : 'Uredi naručioca'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Naziv (npr. Primjer d.o.o.)',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            decoration: const InputDecoration(
              labelText: 'Adresa (jedna ili više linija)',
              border: OutlineInputBorder(),
              hintText: 'npr. 10000 Primjergrad, Primjer ulica 1',
            ),
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _jib,
            decoration: const InputDecoration(
              labelText: 'JIB',
              border: OutlineInputBorder(),
              hintText: 'npr. 1234567890123',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Sačuvaj')),
          if (ex != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _delete,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Obriši naručioca'),
            ),
          ],
        ],
      ),
    );
  }
}
