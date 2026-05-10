import 'package:app_taxi_invoice/src/pdf/invoice_pdf_builder.dart';
import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/ui/invoice_color_scheme.dart';
import 'package:app_taxi_invoice/src/ui/invoice_date_formats.dart';
import 'package:app_taxi_invoice/src/ui/invoice_detail_screen.dart';
import 'package:app_taxi_invoice/src/ui/service_recipients_list_screen.dart';
import 'package:app_taxi_invoice/src/util/invoice_output_save.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const String _routeDash = ' - ';

InputDecoration _invoiceEditorInputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
}) {
  final scheme = Theme.of(context).colorScheme;
  final r = BorderRadius.circular(14);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: scheme.surface,
    border: OutlineInputBorder(borderRadius: r),
    enabledBorder: OutlineInputBorder(
      borderRadius: r,
      borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: r,
      borderSide: BorderSide(color: scheme.invoiceAccent, width: 2),
    ),
  );
}

List<String> parsePutnaRelacija(String route) {
  return route
      .split(RegExp(r'\s*[–—\-]\s*'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

final class InvoiceEditorScreen extends StatefulWidget {
  const InvoiceEditorScreen({
    required this.store,
    required this.settings,
    this.existing,
    super.key,
  });

  final InvoiceStoreController store;
  final AppSettingsController settings;
  final StoredInvoice? existing;

  @override
  State<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

final class _InvoiceEditorScreenState extends State<InvoiceEditorScreen> {
  final _invoiceNo = TextEditingController();
  DateTime _issueDate = DateTime.now();
  final _lineKeys = <GlobalKey<_LineBlockState>>[];
  late final TextEditingController _recipientName;
  late final TextEditingController _recipientAddress;
  late final TextEditingController _recipientJib;
  String? _selectedRecipientId;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _invoiceNo.text = ex.invoiceNumber;
      _issueDate = ex.issueDate;
      _selectedRecipientId = ex.recipientId;
      _recipientName = TextEditingController(text: ex.recipientName);
      _recipientAddress = TextEditingController(text: ex.recipientAddress);
      _recipientJib = TextEditingController(text: ex.recipientJib);
      for (var i = 0; i < ex.lines.length; i++) {
        _lineKeys.add(GlobalKey<_LineBlockState>());
      }
    } else {
      _recipientName = TextEditingController();
      _recipientAddress = TextEditingController();
      _recipientJib = TextEditingController();
    }
    if (_lineKeys.isEmpty) {
      _lineKeys.add(GlobalKey<_LineBlockState>());
    }
  }

  @override
  void dispose() {
    _invoiceNo.dispose();
    _recipientName.dispose();
    _recipientAddress.dispose();
    _recipientJib.dispose();
    super.dispose();
  }

  String? _recipientIdForDropdown(List<ServiceRecipient> items) {
    final id = _selectedRecipientId;
    if (id == null) {
      return null;
    }
    return items.any((r) => r.id == id) ? id : null;
  }

  void _addLine() {
    setState(() => _lineKeys.add(GlobalKey<_LineBlockState>()));
  }

  void _removeLine(int i) {
    if (_lineKeys.length <= 1) {
      return;
    }
    setState(() => _lineKeys.removeAt(i));
  }

  DateTime? _lineInitialDatum(StoredInvoice? ex, int i) {
    if (ex == null || i >= ex.lines.length) {
      return null;
    }
    return ex.lines[i].datumRacuna;
  }

  String? _lineInitialPutna(StoredInvoice? ex, int i) {
    if (ex == null || i >= ex.lines.length) {
      return null;
    }
    return ex.lines[i].putnaRelacija;
  }

  String? _lineInitialName(StoredInvoice? ex, int i) {
    if (ex == null || i >= ex.lines.length) {
      return null;
    }
    return ex.lines[i].brojNarudzbe;
  }

  String? _lineInitialAmount(StoredInvoice? ex, int i) {
    if (ex == null || i >= ex.lines.length) {
      return null;
    }
    return ex.lines[i].iznosKm.toStringAsFixed(2);
  }

  Future<void> _saveAndPreview() async {
    final lines = <InvoiceLine>[];
    for (final key in _lineKeys) {
      final s = key.currentState;
      final line = s?.buildLine();
      if (line == null) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Provjerite stavke: putna relacija (min. 2 grada) i iznos.',
            ),
          ),
        );
        return;
      }
      lines.add(line);
    }

    final no = _invoiceNo.text.trim();
    if (no.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unesite broj računa.')));
      return;
    }

    if (_recipientName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unesite naziv naručioca (ili ga odaberite iz liste).'),
        ),
      );
      return;
    }

    for (final line in lines) {
      final segs = parsePutnaRelacija(line.putnaRelacija);
      for (final c in segs) {
        await widget.store.rememberCity(c);
      }
      await widget.store.rememberOrderName(line.brojNarudzbe);
    }

    final inv = StoredInvoice(
      id: widget.existing?.id ?? _uuid.v4(),
      invoiceNumber: no,
      issueDate: _issueDate,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      lines: lines,
      recipientId: _selectedRecipientId,
      recipientName: _recipientName.text.trim(),
      recipientAddress: _recipientAddress.text.trim(),
      recipientJib: _recipientJib.text.trim(),
      savedPdfPath: widget.existing?.savedPdfPath,
    );

    await widget.store.upsertInvoice(inv);

    if (!mounted) {
      return;
    }

    final bytes = await buildInvoicePdfBytes(inv);
    if (!mounted) {
      return;
    }

    var savedPath = inv.savedPdfPath;

    if (!kIsWeb) {
      final dir = widget.settings.pdfOutputDirectory;
      if (dir == null || dir.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'U Postavkama odaberite folder u koji se snimaju PDF računi, '
              'pa pokušajte ponovo.',
            ),
          ),
        );
        return;
      }
      final path = await saveInvoicePdfToOutputDirectory(
        context: context,
        directoryPath: dir,
        bytes: bytes,
        fileName: invoicePdfFileName(inv),
      );
      if (!mounted) {
        return;
      }
      if (path == null) {
        return;
      }
      await widget.store.setInvoiceSavedPdfPath(inv.id, path);
      savedPath = path;
    }

    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfPreviewScreen(
          invoice: inv,
          pdfBytes: bytes,
          initialSavedPdfPath: savedPath,
        ),
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
      if (widget.existing != null && context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cities = widget.store.cities;
    final names = widget.store.orderNames;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final ex = widget.existing;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          ex == null ? 'Novi račun' : 'Uredi račun',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _EditorSectionCard(
            icon: Icons.receipt_long_outlined,
            title: 'Osnovni podaci',
            subtitle: 'Broj i datum koji idu na PDF račun.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _invoiceNo,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _invoiceEditorInputDecoration(
                    context,
                    label: 'Broj računa',
                    hint: 'npr. 106/26',
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _issueDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) {
                        setState(() => _issueDate = d);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            color: scheme.invoiceAccent,
                            size: 26,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Datum izdavanja računa',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatInvoiceDateMedium(_issueDate),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _EditorSectionCard(
            icon: Icons.business_outlined,
            title: 'Naručilac usluga',
            subtitle: 'Odaberite sačuvanog ili unesite podatke ručno.',
            child: ListenableBuilder(
              listenable: widget.store,
              builder: (context, _) {
                final items = widget.store.serviceRecipientsSorted;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InputDecorator(
                      decoration: _invoiceEditorInputDecoration(
                        context,
                        label: 'Sačuvani naručilac',
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _recipientIdForDropdown(items),
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(12),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Ručno — nije sa liste'),
                            ),
                            ...items.map(
                              (r) => DropdownMenuItem<String?>(
                                value: r.id,
                                child: Text(
                                  r.name.isEmpty ? '(bez naziva)' : r.name,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (id) {
                            setState(() {
                              _selectedRecipientId = id;
                              if (id != null) {
                                final r = widget.store.recipientById(id);
                                if (r != null) {
                                  _recipientName.text = r.name;
                                  _recipientAddress.text = r.address;
                                  _recipientJib.text = r.jib;
                                }
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    if (_selectedRecipientId != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          avatar: Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: scheme.invoiceAccent,
                          ),
                          label: const Text(
                            'Podaci s liste · možete ih izmijeniti',
                          ),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                          backgroundColor: scheme.invoiceAccentContainer
                              .withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ServiceRecipientsListScreen(
                                store: widget.store,
                              ),
                            ),
                          );
                          if (mounted) {
                            setState(() {});
                          }
                        },
                        icon: const Icon(Icons.group_add_outlined, size: 22),
                        label: const Text('Uredi listu naručilaca'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _recipientName,
                      decoration: _invoiceEditorInputDecoration(
                        context,
                        label: 'Naziv na računu',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _recipientAddress,
                      decoration: _invoiceEditorInputDecoration(
                        context,
                        label: 'Adresa',
                        hint: 'Poštanski broj, grad, ulica…',
                      ),
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _recipientJib,
                      decoration: _invoiceEditorInputDecoration(
                        context,
                        label: 'JIB',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _EditorSectionCard(
            icon: Icons.route_outlined,
            title: 'Stavke',
            subtitle:
                'Svaka stavka je jedna vožnja: relacija, narudžba i iznos u KM.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _lineKeys.length; i++)
                  _LineBlock(
                    key: _lineKeys[i],
                    lineIndex: i + 1,
                    cities: cities,
                    orderNames: names,
                    canRemove: _lineKeys.length > 1,
                    onRemove: () => _removeLine(i),
                    initialDatum: _lineInitialDatum(ex, i),
                    initialPutna: _lineInitialPutna(ex, i),
                    initialName: _lineInitialName(ex, i),
                    initialAmount: _lineInitialAmount(ex, i),
                  ),
                const SizedBox(height: 4),
                FilledButton.tonalIcon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Dodaj stavku'),
                  style: FilledButton.styleFrom(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saveAndPreview,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 22),
            label: const Text('Sačuvaj i generiši PDF'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _EditorSectionCard extends StatelessWidget {
  const _EditorSectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.invoiceAccentContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 24, color: scheme.invoiceAccent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

final class _LineBlock extends StatefulWidget {
  const _LineBlock({
    super.key,
    required this.cities,
    required this.orderNames,
    required this.onRemove,
    required this.canRemove,
    required this.lineIndex,
    this.initialDatum,
    this.initialPutna,
    this.initialName,
    this.initialAmount,
  });

  final List<String> cities;
  final List<String> orderNames;
  final VoidCallback onRemove;
  final bool canRemove;
  final int lineIndex;
  final DateTime? initialDatum;
  final String? initialPutna;
  final String? initialName;
  final String? initialAmount;

  @override
  State<_LineBlock> createState() => _LineBlockState();
}

final class _LineBlockState extends State<_LineBlock> {
  late DateTime _datum;
  late List<TextEditingController> _segments;
  late List<FocusNode> _segFocus;
  late TextEditingController _name;
  late TextEditingController _amount;
  late FocusNode _nameFocus;

  @override
  void initState() {
    super.initState();
    _nameFocus = FocusNode();
    _datum = widget.initialDatum ?? DateTime.now();
    var parsed =
        widget.initialPutna != null && widget.initialPutna!.trim().isNotEmpty
        ? parsePutnaRelacija(widget.initialPutna!)
        : <String>[];
    if (parsed.length < 2) {
      parsed = <String>[
        if (parsed.isNotEmpty) parsed.first else '',
        if (parsed.length > 1) parsed[1] else '',
      ];
    }
    _segments = parsed.map((s) => TextEditingController(text: s)).toList();
    _segFocus = List.generate(_segments.length, (_) => FocusNode());
    _name = TextEditingController(text: widget.initialName ?? '');
    _amount = TextEditingController(text: widget.initialAmount ?? '');
  }

  @override
  void dispose() {
    for (final c in _segments) {
      c.dispose();
    }
    for (final f in _segFocus) {
      f.dispose();
    }
    _name.dispose();
    _amount.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _addSegment() {
    setState(() {
      _segments.add(TextEditingController());
      _segFocus.add(FocusNode());
    });
  }

  void _removeSegment(int i) {
    if (_segments.length <= 2) {
      return;
    }
    setState(() {
      _segments[i].dispose();
      _segFocus[i].dispose();
      _segments.removeAt(i);
      _segFocus.removeAt(i);
    });
  }

  InvoiceLine? buildLine() {
    final parts = _segments
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length < 2) {
      return null;
    }
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (amount == null) {
      return null;
    }
    final nm = _name.text.trim();
    if (nm.isEmpty) {
      return null;
    }
    return InvoiceLine(
      datumRacuna: _datum,
      putnaRelacija: parts.join(_routeDash),
      brojNarudzbe: nm,
      iznosKm: amount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    '${widget.lineIndex}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Stavka ${widget.lineIndex}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (widget.canRemove)
                  IconButton.filledTonal(
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: 'Ukloni stavku',
                    style: IconButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Material(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _datum,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _datum = picked);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_note_rounded,
                        size: 22,
                        color: scheme.invoiceAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Datum na stavci',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatInvoiceDateMedium(_datum),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Putna relacija',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _segments.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CityAutocomplete(
                      label: i == 0 ? 'Početna' : 'Naredna',
                      controller: _segments[i],
                      focusNode: _segFocus[i],
                      options: widget.cities,
                    ),
                  ),
                  if (_segments.length > 2)
                    IconButton(
                      onPressed: () => _removeSegment(i),
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addSegment,
                icon: const Icon(Icons.add_road_outlined, size: 20),
                label: const Text('Dodaj grad u relaciju'),
              ),
            ),
            const SizedBox(height: 12),
            _NameAutocomplete(
              controller: _name,
              focusNode: _nameFocus,
              options: widget.orderNames,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              decoration: _invoiceEditorInputDecoration(
                context,
                label: 'Iznos (KM)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _CityAutocomplete extends StatelessWidget {
  const _CityAutocomplete({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.options,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (s) => s,
      optionsBuilder: (tv) {
        final q = tv.text.trim().toLowerCase();
        if (q.isEmpty) {
          return options.take(16);
        }
        return options.where((o) => o.toLowerCase().contains(q));
      },
      optionsViewBuilder: (context, onSelected, opts) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, minWidth: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: opts.length,
                itemBuilder: (context, index) {
                  final o = opts.elementAt(index);
                  return ListTile(title: Text(o), onTap: () => onSelected(o));
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, textController, fNode, onSubmit) {
        return TextFormField(
          controller: textController,
          focusNode: fNode,
          decoration: _invoiceEditorInputDecoration(
            context,
            label: label,
            hint: 'Izaberi ili unesi grad',
          ),
          onFieldSubmitted: (_) => onSubmit(),
        );
      },
    );
  }
}

final class _NameAutocomplete extends StatelessWidget {
  const _NameAutocomplete({
    required this.controller,
    required this.focusNode,
    required this.options,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (s) => s,
      optionsBuilder: (tv) {
        final q = tv.text.toLowerCase();
        return options.where((n) => n.toLowerCase().contains(q));
      },
      optionsViewBuilder: (context, onSelected, opts) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, minWidth: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: opts.length,
                itemBuilder: (context, index) {
                  final o = opts.elementAt(index);
                  return ListTile(title: Text(o), onTap: () => onSelected(o));
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, textController, fNode, onSubmit) {
        return TextFormField(
          controller: textController,
          focusNode: fNode,
          decoration: _invoiceEditorInputDecoration(
            context,
            label: 'Br. narudžbe (ime)',
          ),
          onFieldSubmitted: (_) => onSubmit(),
        );
      },
    );
  }
}
