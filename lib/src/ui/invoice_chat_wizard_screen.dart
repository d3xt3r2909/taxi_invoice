import 'dart:async';

import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/ui/invoice_chat_suggestions.dart';
import 'package:app_taxi_invoice/src/ui/invoice_color_scheme.dart';
import 'package:app_taxi_invoice/src/ui/invoice_date_formats.dart';
import 'package:app_taxi_invoice/src/ui/invoice_number.dart';
import 'package:app_taxi_invoice/src/ui/invoice_route_helpers.dart';
import 'package:app_taxi_invoice/src/ui/invoice_save_preview_flow.dart';
import 'package:app_taxi_invoice/src/ui/store_sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const _assistantAvatarAsset = 'assets/branding/assistant_fab.png';
const _assistantAvatarSize = 32.0;
const _assistantAvatarGap = 8.0;

final class InvoiceChatWizardScreen extends StatefulWidget {
  const InvoiceChatWizardScreen({
    required this.store,
    required this.settings,
    this.draft,
    super.key,
  });

  final InvoiceStoreController store;
  final AppSettingsController settings;
  final InvoiceChatDraft? draft;

  @override
  State<InvoiceChatWizardScreen> createState() =>
      _InvoiceChatWizardScreenState();
}

final class _InvoiceChatWizardScreenState
    extends State<InvoiceChatWizardScreen> {
  final _messagesController = ScrollController();
  final _manualRecipientName = TextEditingController();
  final _manualRecipientAddress = TextEditingController();
  final _manualRecipientJib = TextEditingController();
  final _invoiceNumber = TextEditingController();
  final _route = TextEditingController();
  final _orderName = TextEditingController();
  final _amount = TextEditingController();

  _ChatStep _step = _ChatStep.recipient;
  ServiceRecipient? _selectedRecipient;
  bool _manualRecipient = false;
  DateTime _issueDate = DateTime.now();
  DateTime _currentLineDate = DateTime.now();
  final _lines = <InvoiceLine>[];
  _ChatStep? _returnAfterEdit;
  int? _editingLineIndex;
  _ChatStep? _editingLineField;
  bool _storeOnline = true;
  bool _saving = false;
  late String _draftId;
  late DateTime _draftCreatedAt;
  bool _draftHelpRequested = false;
  bool _draftAutosaveQueued = false;
  bool _draftDeleted = false;
  String? _recipientNameError;
  String? _invoiceNumberError;
  String? _routeError;
  String? _orderNameError;
  String? _amountError;
  String? _lastScrollSignature;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    if (draft == null) {
      final now = DateTime.now();
      _draftId = _uuid.v4();
      _draftCreatedAt = now;
      _issueDate = DateTime(now.year, now.month, now.day);
      _currentLineDate = _issueDate;
      _invoiceNumber.text = _suggestedInvoiceNumber();
    } else {
      _restoreDraft(draft);
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _queueDraftAutosave();
  }

  @override
  void dispose() {
    _messagesController.dispose();
    _manualRecipientName.dispose();
    _manualRecipientAddress.dispose();
    _manualRecipientJib.dispose();
    _invoiceNumber.dispose();
    _route.dispose();
    _orderName.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _restoreDraft(InvoiceChatDraft draft) {
    _draftId = draft.id;
    _draftCreatedAt = draft.createdAt;
    _draftHelpRequested = draft.helpRequested;
    _step = _chatStepFromDraft(draft.step);
    _manualRecipient = draft.manualRecipient;
    final selectedRecipientId = draft.selectedRecipientId;
    if (selectedRecipientId != null) {
      _selectedRecipient = widget.store.recipientById(selectedRecipientId);
    }
    if (_selectedRecipient == null) {
      _manualRecipient = true;
      _manualRecipientName.text = draft.recipientName;
      _manualRecipientAddress.text = draft.recipientAddress;
      _manualRecipientJib.text = draft.recipientJib;
    }
    _issueDate = draft.issueDate;
    _currentLineDate = draft.currentLineDate;
    _invoiceNumber.text = draft.invoiceNumber.isEmpty
        ? _suggestedInvoiceNumber()
        : draft.invoiceNumber;
    _route.text = draft.route;
    _orderName.text = draft.orderName;
    _amount.text = draft.amount;
    _lines
      ..clear()
      ..addAll(draft.lines);
    _storeOnline = draft.storeOnline;
  }

  String get _recipientName {
    return _selectedRecipient?.name ?? _manualRecipientName.text.trim();
  }

  String get _recipientAddress {
    return _selectedRecipient?.address ?? _manualRecipientAddress.text.trim();
  }

  String get _recipientJib {
    return _selectedRecipient?.jib ?? _manualRecipientJib.text.trim();
  }

  bool get _hasMeaningfulDraftProgress {
    return _draftHelpRequested ||
        _recipientName.isNotEmpty ||
        _route.text.trim().isNotEmpty ||
        _orderName.text.trim().isNotEmpty ||
        _amount.text.trim().isNotEmpty ||
        _lines.isNotEmpty ||
        _step != _ChatStep.recipient;
  }

  void _queueDraftAutosave() {
    if (_draftAutosaveQueued || _draftDeleted || !mounted) {
      return;
    }
    _draftAutosaveQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _draftAutosaveQueued = false;
      if (mounted) {
        unawaited(_autosaveDraft());
      }
    });
  }

  Future<void> _autosaveDraft({bool force = false}) async {
    if (_draftDeleted || !widget.store.canWrite) {
      return;
    }
    if (!force && !_hasMeaningfulDraftProgress) {
      return;
    }
    try {
      await widget.store.upsertInvoiceChatDraft(_buildCurrentDraft());
    } catch (_) {
      // Draft autosave should never interrupt the invoice flow.
    }
  }

  InvoiceChatDraft _buildCurrentDraft() {
    return InvoiceChatDraft(
      id: _draftId,
      createdAt: _draftCreatedAt,
      updatedAt: DateTime.now(),
      helpRequested: _draftHelpRequested,
      step: _step.name,
      selectedRecipientId: _selectedRecipient?.id,
      manualRecipient: _manualRecipient,
      recipientName: _recipientName,
      recipientAddress: _recipientAddress,
      recipientJib: _recipientJib,
      invoiceNumber: _invoiceNumber.text.trim(),
      issueDate: _issueDate,
      currentLineDate: _currentLineDate,
      route: _route.text.trim(),
      orderName: _orderName.text.trim(),
      amount: _amount.text.trim(),
      lines: _lines,
      storeOnline: _storeOnline,
    );
  }

  Future<void> _requestHelp() async {
    if (!widget.store.canWrite) {
      showInvoiceStoreReadOnlyMessage(context, widget.store);
      return;
    }
    setState(() {
      _draftHelpRequested = true;
    });
    await _autosaveDraft(force: true);
    if (mounted) {
      _showMessage('Pomoć je zatražena. Drugi korisnik može otvoriti nacrt.');
    }
  }

  Future<void> _deleteDraftAfterSave() async {
    if (_draftDeleted || !widget.store.canWrite) {
      return;
    }
    _draftDeleted = true;
    try {
      await widget.store.deleteInvoiceChatDraft(_draftId);
    } catch (_) {
      // A saved invoice is more important than cleanup; the draft can be
      // removed manually if a transient cloud write fails.
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _selectRecipient(ServiceRecipient recipient) {
    setState(() {
      _selectedRecipient = recipient;
      _manualRecipient = false;
      _recipientNameError = null;
      _invoiceNumber.text = _suggestedInvoiceNumber();
      _step = _nextStepAfterEdit(_ChatStep.invoiceNumber);
    });
  }

  void _useManualRecipient() {
    setState(() {
      _selectedRecipient = null;
      _manualRecipient = true;
      _recipientNameError = null;
    });
  }

  void _confirmManualRecipient() {
    if (_manualRecipientName.text.trim().isEmpty) {
      setState(() {
        _recipientNameError = 'Naziv naručioca je obavezan.';
      });
      return;
    }
    setState(() {
      _recipientNameError = null;
      _invoiceNumber.text = _suggestedInvoiceNumber();
      _step = _nextStepAfterEdit(_ChatStep.invoiceNumber);
    });
  }

  void _confirmInvoiceNumber() {
    final invoiceNumber = normalizeInvoiceNumberForSave(_invoiceNumber.text);
    _invoiceNumber.text = invoiceNumber;
    if (invoiceNumber.isEmpty) {
      setState(() {
        _invoiceNumberError = 'Broj računa je obavezan.';
      });
      return;
    }
    if (!isValidInvoiceNumberFormat(invoiceNumber)) {
      setState(() {
        _invoiceNumberError = 'Broj računa mora biti u formatu 102/26.';
      });
      return;
    }
    setState(() {
      _invoiceNumberError = null;
      _step = _nextStepAfterEdit(_ChatStep.issueDate);
    });
  }

  Future<void> _pickIssueDate(DateTime initialDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _issueDate = picked;
      _currentLineDate = picked;
      _step = _nextStepAfterEdit(_ChatStep.lineDate);
    });
  }

  void _setIssueDate(DateTime date) {
    setState(() {
      _issueDate = date;
      _currentLineDate = date;
      _step = _nextStepAfterEdit(_ChatStep.lineDate);
    });
  }

  Future<void> _pickLineDate(DateTime initialDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _currentLineDate = picked;
      if (_isEditingLineField(_ChatStep.lineDate)) {
        _replaceEditedLine(datumRacuna: picked);
        _finishLineFieldEdit();
      } else {
        _step = _nextStepAfterEdit(_ChatStep.route);
      }
    });
  }

  void _setLineDate(DateTime date) {
    setState(() {
      _currentLineDate = date;
      if (_isEditingLineField(_ChatStep.lineDate)) {
        _replaceEditedLine(datumRacuna: date);
        _finishLineFieldEdit();
      } else {
        _step = _nextStepAfterEdit(_ChatStep.route);
      }
    });
  }

  void _setRoute(String route) {
    final trimmed = route.trim();
    if (parseInvoiceRoute(trimmed).length < 2) {
      setState(() {
        _routeError = 'Relacija treba imati najmanje dva grada.';
      });
      return;
    }
    setState(() {
      _routeError = null;
      _route.text = trimmed;
      if (_isEditingLineField(_ChatStep.route)) {
        _replaceEditedLine(putnaRelacija: trimmed);
        _finishLineFieldEdit();
      } else {
        _step = _nextStepAfterEdit(_ChatStep.orderName);
      }
    });
  }

  void _setOrderName(String orderName) {
    final trimmed = orderName.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _orderNameError = 'Broj narudžbe ili ime je obavezno.';
      });
      return;
    }
    setState(() {
      _orderNameError = null;
      _orderName.text = trimmed;
      if (_isEditingLineField(_ChatStep.orderName)) {
        _replaceEditedLine(brojNarudzbe: trimmed);
        _finishLineFieldEdit();
      } else {
        _step = _nextStepAfterEdit(_ChatStep.amount);
      }
    });
  }

  void _setAmount(String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) {
      setState(() {
        _amountError = 'Unesite ispravan iznos u KM.';
      });
      return;
    }
    final line = InvoiceLine(
      datumRacuna: _currentLineDate,
      putnaRelacija: _route.text.trim(),
      brojNarudzbe: _orderName.text.trim(),
      iznosKm: parsed,
    );
    setState(() {
      _amountError = null;
      _amount.text = _formatAmount(parsed);
      if (_isEditingLineField(_ChatStep.amount)) {
        _replaceEditedLine(iznosKm: parsed);
        _finishLineFieldEdit();
      } else if (_editingLineIndex != null) {
        _replaceEditedLineWith(line);
        _finishLineFieldEdit();
      } else {
        _lines.add(line);
        _step = _nextStepAfterEdit(_ChatStep.moreLines);
      }
    });
  }

  void _startNextLine() {
    setState(() {
      _currentLineDate = _issueDate;
      _route.clear();
      _orderName.clear();
      _amount.clear();
      _returnAfterEdit = null;
      _editingLineIndex = null;
      _editingLineField = null;
      _routeError = null;
      _orderNameError = null;
      _amountError = null;
      _step = _ChatStep.lineDate;
    });
  }

  void _finishLines() {
    if (_lines.isEmpty) {
      _showMessage('Dodajte barem jednu stavku.');
      return;
    }
    setState(() => _step = _ChatStep.summary);
  }

  Future<void> _save() async {
    if (_storeOnline && !widget.store.canWrite) {
      showInvoiceStoreReadOnlyMessage(context, widget.store);
      return;
    }
    final invoiceNumber = normalizeInvoiceNumberForSave(_invoiceNumber.text);
    _invoiceNumber.text = invoiceNumber;
    if (_recipientName.isEmpty || invoiceNumber.isEmpty) {
      setState(() {
        if (_recipientName.isEmpty) {
          _recipientNameError = 'Naziv naručioca je obavezan.';
          _step = _ChatStep.recipient;
        } else {
          _invoiceNumberError = 'Broj računa je obavezan.';
          _step = _ChatStep.invoiceNumber;
        }
      });
      return;
    }
    if (!isValidInvoiceNumberFormat(invoiceNumber)) {
      setState(() {
        _invoiceNumberError = 'Broj računa mora biti u formatu 102/26.';
        _step = _ChatStep.invoiceNumber;
      });
      return;
    }
    if (_lines.isEmpty) {
      _showMessage('Dodajte barem jednu stavku.');
      return;
    }
    setState(() => _saving = true);
    final serviceRecipientToRemember = _manualServiceRecipientToRemember();
    final invoice = StoredInvoice(
      id: _uuid.v4(),
      invoiceNumber: invoiceNumber,
      issueDate: _issueDate,
      createdAt: DateTime.now(),
      lines: _lines,
      recipientId: _selectedRecipient?.id ?? serviceRecipientToRemember?.id,
      recipientName: _recipientName,
      recipientAddress: _recipientAddress,
      recipientJib: _recipientJib,
    );
    final action = await saveInvoiceAndOpenPdfPreview(
      context: context,
      invoice: invoice,
      store: widget.store,
      settings: widget.settings,
      citiesToRemember: _lines.expand((line) {
        return parseInvoiceRoute(line.putnaRelacija);
      }),
      orderNamesToRemember: _lines.map((line) => line.brojNarudzbe),
      serviceRecipientToRemember: serviceRecipientToRemember,
      storageMode: _storeOnline
          ? InvoiceSaveStorageMode.online
          : InvoiceSaveStorageMode.localOnly,
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (action != null) {
      await _deleteDraftAfterSave();
    }
    if (!mounted) {
      return;
    }
    if (action == InvoiceSavePostAction.backToList) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    if (action == InvoiceSavePostAction.newInvoice) {
      _resetForNextInvoice();
    }
  }

  void _resetForNextInvoice() {
    final now = DateTime.now();
    setState(() {
      _draftId = _uuid.v4();
      _draftCreatedAt = now;
      _draftHelpRequested = false;
      _draftDeleted = false;
      _manualRecipientName.clear();
      _manualRecipientAddress.clear();
      _manualRecipientJib.clear();
      _selectedRecipient = null;
      _manualRecipient = false;
      _issueDate = DateTime(now.year, now.month, now.day);
      _currentLineDate = _issueDate;
      _invoiceNumber.text = _suggestedInvoiceNumber();
      _route.clear();
      _orderName.clear();
      _amount.clear();
      _recipientNameError = null;
      _invoiceNumberError = null;
      _routeError = null;
      _orderNameError = null;
      _amountError = null;
      _lines.clear();
      _returnAfterEdit = null;
      _editingLineIndex = null;
      _editingLineField = null;
      _storeOnline = true;
      _step = _ChatStep.recipient;
    });
  }

  ServiceRecipient? _manualServiceRecipientToRemember() {
    if (!_manualRecipient || _selectedRecipient != null) {
      return null;
    }
    final name = _manualRecipientName.text.trim();
    if (name.isEmpty) {
      return null;
    }
    final address = _manualRecipientAddress.text.trim();
    final jib = _manualRecipientJib.text.trim();
    return widget.store.matchingServiceRecipient(
          name: name,
          address: address,
          jib: jib,
        ) ??
        ServiceRecipient(
          id: _uuid.v4(),
          name: name,
          address: address,
          jib: jib,
        );
  }

  String _suggestedInvoiceNumber() {
    return suggestInvoiceNumber(
      store: widget.store,
      recipientName: _recipientName,
      date: _issueDate,
    );
  }

  void _goBack() {
    if (_returnAfterEdit != null) {
      setState(() {
        _step = _returnAfterEdit!;
        _returnAfterEdit = null;
        _editingLineIndex = null;
        _editingLineField = null;
      });
      return;
    }
    if (_step == _ChatStep.moreLines && _lines.isNotEmpty) {
      final last = _lines.removeLast();
      setState(() {
        _currentLineDate = last.datumRacuna;
        _route.text = last.putnaRelacija;
        _orderName.text = last.brojNarudzbe;
        _amount.text = _formatAmount(last.iznosKm);
        _step = _ChatStep.amount;
      });
      return;
    }
    setState(() {
      _step = switch (_step) {
        _ChatStep.recipient => _ChatStep.recipient,
        _ChatStep.invoiceNumber => _ChatStep.recipient,
        _ChatStep.issueDate => _ChatStep.invoiceNumber,
        _ChatStep.lineDate =>
          _lines.isEmpty ? _ChatStep.issueDate : _ChatStep.moreLines,
        _ChatStep.route => _ChatStep.lineDate,
        _ChatStep.orderName => _ChatStep.route,
        _ChatStep.amount => _ChatStep.orderName,
        _ChatStep.moreLines => _ChatStep.amount,
        _ChatStep.summary => _ChatStep.moreLines,
      };
    });
  }

  void _editStep(_ChatStep step) {
    setState(() {
      if (_step.index > step.index) {
        _returnAfterEdit = _step;
      }
      if (step == _ChatStep.recipient && _selectedRecipient == null) {
        _manualRecipient = true;
      }
      _step = step;
    });
  }

  void _editLineField(int index, _ChatStep field) {
    if (index < 0 || index >= _lines.length) {
      return;
    }
    final line = _lines[index];
    setState(() {
      _editingLineIndex = index;
      _editingLineField = field;
      _returnAfterEdit = _step;
      _currentLineDate = line.datumRacuna;
      _route.text = line.putnaRelacija;
      _orderName.text = line.brojNarudzbe;
      _amount.text = _formatAmount(line.iznosKm);
      _routeError = null;
      _orderNameError = null;
      _amountError = null;
      _step = field;
    });
  }

  _ChatStep _nextStepAfterEdit(_ChatStep fallback) {
    final next = _returnAfterEdit ?? fallback;
    _returnAfterEdit = null;
    _editingLineIndex = null;
    _editingLineField = null;
    return next;
  }

  bool _isEditingLineField(_ChatStep field) {
    return _editingLineIndex != null && _editingLineField == field;
  }

  void _replaceEditedLine({
    DateTime? datumRacuna,
    String? putnaRelacija,
    String? brojNarudzbe,
    double? iznosKm,
  }) {
    final index = _editingLineIndex;
    if (index == null || index < 0 || index >= _lines.length) {
      return;
    }
    final current = _lines[index];
    _lines[index] = InvoiceLine(
      datumRacuna: datumRacuna ?? current.datumRacuna,
      putnaRelacija: putnaRelacija ?? current.putnaRelacija,
      brojNarudzbe: brojNarudzbe ?? current.brojNarudzbe,
      iznosKm: iznosKm ?? current.iznosKm,
    );
  }

  void _replaceEditedLineWith(InvoiceLine line) {
    final index = _editingLineIndex;
    if (index == null || index < 0 || index >= _lines.length) {
      return;
    }
    _lines[index] = line;
  }

  void _finishLineFieldEdit() {
    _step = _returnAfterEdit ?? _ChatStep.summary;
    _returnAfterEdit = null;
    _editingLineIndex = null;
    _editingLineField = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    _scheduleMessagesScrollIfNeeded();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomoćnik za račun'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _draftHelpRequested ? null : _requestHelp,
              icon: Icon(
                _draftHelpRequested
                    ? Icons.support_agent
                    : Icons.front_hand_outlined,
              ),
              label: Text(_draftHelpRequested ? 'Pomoć zatražena' : 'Pomoć'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _messagesController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              children: _messages(),
            ),
          ),
          SafeArea(
            top: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: screenHeight * 0.58),
                  child: _stepPanel(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _scheduleMessagesScrollIfNeeded() {
    final signature = [
      _step.index,
      _returnAfterEdit?.index ?? -1,
      _editingLineIndex ?? -1,
      _editingLineField?.index ?? -1,
      _lines.length,
    ].join(':');
    if (_lastScrollSignature == signature) {
      return;
    }
    _lastScrollSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesController.hasClients) {
        return;
      }
      _messagesController.animateTo(
        _messagesController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  List<Widget> _messages() {
    final visibleStepIndex = _visibleStepIndex;
    final widgets = <Widget>[
      const _ChatBubble(
        text: 'Popunićemo račun kroz nekoliko jednostavnih pitanja.',
        fromUser: false,
      ),
    ];
    if (_draftHelpRequested) {
      widgets.add(
        const _ChatBubble(
          text: 'Pomoć je zatražena. Drugi korisnik može otvoriti ovaj nacrt.',
          fromUser: false,
        ),
      );
    }

    _addQuestionAnswer(
      widgets,
      question: 'Za koga je račun?',
      answer: _recipientName.isEmpty ? null : 'Naručilac: $_recipientName',
      onEdit: _recipientName.isEmpty
          ? null
          : () => _editStep(_ChatStep.recipient),
    );

    if (visibleStepIndex >= _ChatStep.invoiceNumber.index) {
      _addQuestionAnswer(
        widgets,
        question: 'Koji je broj računa?',
        answer: visibleStepIndex > _ChatStep.invoiceNumber.index
            ? 'Broj računa: ${_invoiceNumber.text.trim()}'
            : null,
        onEdit: visibleStepIndex > _ChatStep.invoiceNumber.index
            ? () => _editStep(_ChatStep.invoiceNumber)
            : null,
      );
    }

    if (visibleStepIndex >= _ChatStep.issueDate.index) {
      _addQuestionAnswer(
        widgets,
        question: 'Koji je datum računa?',
        answer: visibleStepIndex > _ChatStep.issueDate.index
            ? 'Datum računa: ${formatInvoiceDateMedium(_issueDate)}'
            : null,
        onEdit: visibleStepIndex > _ChatStep.issueDate.index
            ? () => _editStep(_ChatStep.issueDate)
            : null,
      );
    }

    for (var i = 0; i < _lines.length; i++) {
      _addCompletedLineMessages(widgets, i, _lines[i]);
    }

    if (_showCurrentLineDraft) {
      _addCurrentLineDraftMessages(widgets, visibleStepIndex);
    }

    if (_step == _ChatStep.summary) {
      widgets.add(
        _ChatContentBubble(
          child: _FinalReviewCard(
            recipientName: _recipientName,
            invoiceNumber: _invoiceNumber.text.trim(),
            issueDate: _issueDate,
            lines: _lines,
            totalLabel: '${_formatAmount(_invoiceTotal)} KM',
            amountFormatter: _formatAmount,
          ),
        ),
      );
    }

    return widgets;
  }

  int get _visibleStepIndex {
    final returnStep = _returnAfterEdit;
    if (returnStep == null) {
      return _step.index;
    }
    return _step.index > returnStep.index ? _step.index : returnStep.index;
  }

  bool get _showCurrentLineDraft {
    if (_editingLineIndex != null) {
      return false;
    }
    return switch (_step) {
      _ChatStep.lineDate ||
      _ChatStep.route ||
      _ChatStep.orderName ||
      _ChatStep.amount => true,
      _ => false,
    };
  }

  double get _invoiceTotal {
    return _lines.fold<double>(0, (sum, line) => sum + line.iznosKm);
  }

  void _addQuestionAnswer(
    List<Widget> widgets, {
    required String question,
    required String? answer,
    VoidCallback? onEdit,
  }) {
    if (answer != null && answer.trim().isNotEmpty) {
      widgets
        ..add(_ChatBubble(text: question, fromUser: false))
        ..add(_ChatBubble(text: answer, fromUser: true, onTap: onEdit));
    }
  }

  void _addCompletedLineMessages(
    List<Widget> widgets,
    int index,
    InvoiceLine line,
  ) {
    final lineNumber = index + 1;
    widgets.add(
      _ChatBubble(text: 'Stavka $lineNumber (vožnja)', fromUser: false),
    );
    _addQuestionAnswer(
      widgets,
      question: 'Koji je datum vožnje?',
      answer: formatInvoiceDateMedium(line.datumRacuna),
      onEdit: () => _editLineField(index, _ChatStep.lineDate),
    );
    _addQuestionAnswer(
      widgets,
      question: 'Koja je putna relacija?',
      answer: line.putnaRelacija,
      onEdit: () => _editLineField(index, _ChatStep.route),
    );
    _addQuestionAnswer(
      widgets,
      question: 'Koji je broj narudžbe ili ime?',
      answer: line.brojNarudzbe,
      onEdit: () => _editLineField(index, _ChatStep.orderName),
    );
    _addQuestionAnswer(
      widgets,
      question: 'Koji je iznos u KM?',
      answer: '${_formatAmount(line.iznosKm)} KM',
      onEdit: () => _editLineField(index, _ChatStep.amount),
    );
  }

  void _addCurrentLineDraftMessages(
    List<Widget> widgets,
    int visibleStepIndex,
  ) {
    widgets.add(
      _ChatBubble(
        text: 'Stavka ${_lines.length + 1} (vožnja)',
        fromUser: false,
      ),
    );
    _addQuestionAnswer(
      widgets,
      question: 'Koji je datum vožnje?',
      answer: visibleStepIndex > _ChatStep.lineDate.index
          ? formatInvoiceDateMedium(_currentLineDate)
          : null,
      onEdit: visibleStepIndex > _ChatStep.lineDate.index
          ? () => _editStep(_ChatStep.lineDate)
          : null,
    );
    if (visibleStepIndex >= _ChatStep.route.index) {
      _addQuestionAnswer(
        widgets,
        question: 'Koja je putna relacija?',
        answer:
            visibleStepIndex > _ChatStep.route.index &&
                _route.text.trim().isNotEmpty
            ? _route.text.trim()
            : null,
        onEdit:
            visibleStepIndex > _ChatStep.route.index &&
                _route.text.trim().isNotEmpty
            ? () => _editStep(_ChatStep.route)
            : null,
      );
    }
    if (visibleStepIndex >= _ChatStep.orderName.index) {
      _addQuestionAnswer(
        widgets,
        question: 'Koji je broj narudžbe ili ime?',
        answer:
            visibleStepIndex > _ChatStep.orderName.index &&
                _orderName.text.trim().isNotEmpty
            ? _orderName.text.trim()
            : null,
        onEdit:
            visibleStepIndex > _ChatStep.orderName.index &&
                _orderName.text.trim().isNotEmpty
            ? () => _editStep(_ChatStep.orderName)
            : null,
      );
    }
    if (visibleStepIndex >= _ChatStep.amount.index) {
      _addQuestionAnswer(
        widgets,
        question: 'Koji je iznos u KM?',
        answer:
            visibleStepIndex > _ChatStep.amount.index &&
                _amount.text.trim().isNotEmpty
            ? '${_amount.text.trim()} KM'
            : null,
        onEdit:
            visibleStepIndex > _ChatStep.amount.index &&
                _amount.text.trim().isNotEmpty
            ? () => _editStep(_ChatStep.amount)
            : null,
      );
    }
  }

  String _promptForStep() {
    return switch (_step) {
      _ChatStep.recipient => 'Za koga je račun?',
      _ChatStep.invoiceNumber => 'Koji je broj računa?',
      _ChatStep.issueDate => 'Koji je datum računa?',
      _ChatStep.lineDate => 'Koji je datum vožnje?',
      _ChatStep.route => 'Koja je putna relacija?',
      _ChatStep.orderName => 'Koji je broj narudžbe ili ime?',
      _ChatStep.amount => 'Koji je iznos u KM?',
      _ChatStep.moreLines => 'Želite li dodati još jednu stavku?',
      _ChatStep.summary => 'Sačuvati online ili samo offline?',
    };
  }

  Widget _stepPanel(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: switch (_step) {
          _ChatStep.recipient => _recipientPanel(context),
          _ChatStep.invoiceNumber => _invoiceNumberPanel(context),
          _ChatStep.issueDate => _issueDatePanel(context),
          _ChatStep.lineDate => _lineDatePanel(context),
          _ChatStep.route => _routePanel(context),
          _ChatStep.orderName => _orderNamePanel(context),
          _ChatStep.amount => _amountPanel(context),
          _ChatStep.moreLines => _moreLinesPanel(context),
          _ChatStep.summary => _summaryPanel(context),
        },
      ),
    );
  }

  Widget _answerPanel({required List<Widget> children}) {
    return _PanelColumn(
      children: [
        _ActiveQuestion(text: _promptForStep()),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _recipientPanel(BuildContext context) {
    final recipients = widget.store.serviceRecipientsSorted;
    return _answerPanel(
      children: [
        if (recipients.isNotEmpty && !_manualRecipient)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final recipient in recipients)
                _ChoiceButton(
                  icon: Icons.business_outlined,
                  label: recipient.name,
                  onPressed: () => _selectRecipient(recipient),
                ),
              _ChoiceButton(
                icon: Icons.edit_outlined,
                label: 'Unesi ručno',
                onPressed: _useManualRecipient,
              ),
            ],
          )
        else ...[
          _LargeTextField(
            controller: _manualRecipientName,
            label: 'Naziv naručioca',
            errorText: _recipientNameError,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          _LargeTextField(
            controller: _manualRecipientAddress,
            label: 'Adresa',
            minLines: 2,
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          _LargeTextField(controller: _manualRecipientJib, label: 'JIB'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _confirmManualRecipient,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Nastavi'),
          ),
          if (recipients.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _manualRecipient = false),
              child: const Text('Odaberi sa liste'),
            ),
        ],
      ],
    );
  }

  Widget _invoiceNumberPanel(BuildContext context) {
    final suggestion = _suggestedInvoiceNumber();
    return _answerPanel(
      children: [
        const _SuggestionLabel(
          text: 'Prijedlog za ovog naručioca',
          icon: Icons.receipt_long_outlined,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ChoiceButton(
              icon: Icons.receipt_long_outlined,
              label: suggestion,
              onPressed: () {
                _invoiceNumber.text = suggestion;
                _confirmInvoiceNumber();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _LargeTextField(
          controller: _invoiceNumber,
          label: 'Broj računa',
          hint: 'npr. 102/26',
          errorText: _invoiceNumberError,
          keyboardType: TextInputType.text,
          inputFormatters: const [InvoiceNumberInputFormatter()],
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 12),
        _PanelActions(onBack: _goBack, onNext: _confirmInvoiceNumber),
      ],
    );
  }

  Widget _issueDatePanel(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    return _answerPanel(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ChoiceButton(
              icon: Icons.today_outlined,
              label: 'Danas',
              onPressed: () => _setIssueDate(today),
            ),
            _ChoiceButton(
              icon: Icons.history_rounded,
              label: 'Jučer',
              onPressed: () =>
                  _setIssueDate(today.subtract(const Duration(days: 1))),
            ),
            _ChoiceButton(
              icon: Icons.calendar_month_outlined,
              label: 'Odaberi datum',
              onPressed: () => _pickIssueDate(_issueDate),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Nazad'),
          ),
        ),
      ],
    );
  }

  Widget _lineDatePanel(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    return _answerPanel(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ChoiceButton(
              icon: Icons.receipt_long_outlined,
              label: 'Isto kao račun',
              onPressed: () => _setLineDate(_issueDate),
            ),
            _ChoiceButton(
              icon: Icons.today_outlined,
              label: 'Danas',
              onPressed: () => _setLineDate(today),
            ),
            _ChoiceButton(
              icon: Icons.calendar_month_outlined,
              label: 'Odaberi datum',
              onPressed: () => _pickLineDate(_currentLineDate),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Nazad'),
          ),
        ),
      ],
    );
  }

  Widget _routePanel(BuildContext context) {
    final suggestions = suggestRoutes(widget.store.snapshot);
    final citySuggestions = widget.store.cities.take(16).toList();
    return _answerPanel(
      children: [
        if (suggestions.isNotEmpty) ...[
          const _SuggestionLabel(
            text: 'Česte relacije',
            icon: Icons.route_outlined,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final route in suggestions)
                _ChoiceButton(
                  icon: Icons.route_outlined,
                  label: route,
                  onPressed: () => _setRoute(route),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (citySuggestions.isNotEmpty) ...[
          const _SuggestionLabel(
            text: 'Gradovi',
            icon: Icons.location_city_outlined,
          ),
          const SizedBox(height: 8),
          _CitySuggestionChips(
            cities: citySuggestions,
            onSelected: (city) {
              setState(() {
                _route.text = appendCityToInvoiceRoute(_route.text, city);
                _routeError = null;
                _route.selection = TextSelection.collapsed(
                  offset: _route.text.length,
                );
              });
            },
          ),
          const SizedBox(height: 12),
        ],
        _LargeTextField(
          controller: _route,
          label: 'Relacija',
          hint: 'npr. Sarajevo - Mostar, Sarajevo, Mostar; Tuzla / Zenica',
          errorText: _routeError,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        _PanelActions(onBack: _goBack, onNext: () => _setRoute(_route.text)),
      ],
    );
  }

  Widget _orderNamePanel(BuildContext context) {
    final suggestions = widget.store.orderNames.take(8).toList();
    return _answerPanel(
      children: [
        if (suggestions.isNotEmpty) ...[
          const _SuggestionLabel(
            text: 'Sačuvani nazivi',
            icon: Icons.bookmark_outline_rounded,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in suggestions)
                _ChoiceButton(
                  icon: Icons.bookmark_outline_rounded,
                  label: name,
                  onPressed: () => _setOrderName(name),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        _LargeTextField(
          controller: _orderName,
          label: 'Broj narudžbe ili ime',
          errorText: _orderNameError,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        _PanelActions(
          onBack: _goBack,
          onNext: () => _setOrderName(_orderName.text),
        ),
      ],
    );
  }

  Widget _amountPanel(BuildContext context) {
    final suggestions = suggestAmounts(
      widget.store.snapshot,
      route: _route.text,
    );
    return _answerPanel(
      children: [
        if (suggestions.isNotEmpty) ...[
          const _SuggestionLabel(
            text: 'Predloženi iznosi',
            icon: Icons.payments_outlined,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final amount in suggestions)
                _ChoiceButton(
                  icon: Icons.payments_outlined,
                  label: '${_formatAmount(amount)} KM',
                  onPressed: () => _setAmount(amount.toStringAsFixed(2)),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        _LargeTextField(
          controller: _amount,
          label: 'Iznos (KM)',
          errorText: _amountError,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
        ),
        const SizedBox(height: 12),
        _PanelActions(onBack: _goBack, onNext: () => _setAmount(_amount.text)),
      ],
    );
  }

  Widget _moreLinesPanel(BuildContext context) {
    return _answerPanel(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _startNextLine,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Dodaj stavku'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _finishLines,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Gotovo'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Nazad'),
          ),
        ),
      ],
    );
  }

  Widget _summaryPanel(BuildContext context) {
    final theme = Theme.of(context);
    return _answerPanel(
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          selected: {_storeOnline},
          segments: const [
            ButtonSegment<bool>(
              value: true,
              icon: Icon(Icons.cloud_done_outlined),
              label: Text('Online'),
            ),
            ButtonSegment<bool>(
              value: false,
              icon: Icon(Icons.phone_iphone_outlined),
              label: Text('Samo offline'),
            ),
          ],
          onSelectionChanged: _saving
              ? null
              : (selection) {
                  if (selection.isNotEmpty) {
                    setState(() => _storeOnline = selection.first);
                  }
                },
        ),
        if (!_storeOnline) ...[
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.36),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Offline račun nije u zajedničkoj bazi. Ručno sačuvajte ili '
                'podijelite PDF odmah. Ako se browser obriše ili uređaj '
                'pokvari, račun se može trajno izgubiti.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(
            _storeOnline ? 'Sačuvaj online i PDF' : 'Samo otvori PDF',
          ),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _saving ? null : _goBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Nazad'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ],
    );
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(2).replaceAll('.', ',');
  }
}

enum _ChatStep {
  recipient,
  invoiceNumber,
  issueDate,
  lineDate,
  route,
  orderName,
  amount,
  moreLines,
  summary,
}

_ChatStep _chatStepFromDraft(String raw) {
  for (final step in _ChatStep.values) {
    if (step.name == raw) {
      return step;
    }
  }
  return _ChatStep.recipient;
}

final class _PanelColumn extends StatelessWidget {
  const _PanelColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

final class _ActiveQuestion extends StatelessWidget {
  const _ActiveQuestion({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AssistantChatAvatar(size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.fromUser, this.onTap});

  final String text;
  final bool fromUser;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = fromUser ? scheme.onPrimary : scheme.onSurface;
    final bubble = DecoratedBox(
      decoration: BoxDecoration(
        color: fromUser ? scheme.invoiceAccent : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: foreground,
                height: 1.35,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, size: 16, color: foreground),
                  const SizedBox(width: 4),
                  Text(
                    'Uredi',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    final interactiveBubble = onTap == null
        ? bubble
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: bubble,
            ),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableBubbleWidth = fromUser
            ? constraints.maxWidth
            : constraints.maxWidth - _assistantAvatarSize - _assistantAvatarGap;
        final bubbleMaxWidth =
            availableBubbleWidth.isFinite && availableBubbleWidth < 340
            ? availableBubbleWidth
            : 340.0;
        final safeBubbleMaxWidth = bubbleMaxWidth < 0 ? 0.0 : bubbleMaxWidth;
        final constrainedBubble = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: safeBubbleMaxWidth),
          child: interactiveBubble,
        );
        return Align(
          alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: fromUser
                ? constrainedBubble
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _AssistantChatAvatar(),
                      const SizedBox(width: _assistantAvatarGap),
                      constrainedBubble,
                    ],
                  ),
          ),
        );
      },
    );
  }
}

final class _ChatContentBubble extends StatelessWidget {
  const _ChatContentBubble({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableBubbleWidth =
            constraints.maxWidth - _assistantAvatarSize - _assistantAvatarGap;
        final bubbleMaxWidth =
            availableBubbleWidth.isFinite && availableBubbleWidth < 560
            ? availableBubbleWidth
            : 560.0;
        final safeBubbleMaxWidth = bubbleMaxWidth < 0 ? 0.0 : bubbleMaxWidth;
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AssistantChatAvatar(),
                const SizedBox(width: _assistantAvatarGap),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: safeBubbleMaxWidth),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

final class _AssistantChatAvatar extends StatelessWidget {
  const _AssistantChatAvatar({this.size = _assistantAvatarSize});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surface,
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: ClipOval(
            child: Image.asset(
              _assistantAvatarAsset,
              width: size - 4,
              height: size - 4,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

final class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

final class _CitySuggestionChips extends StatelessWidget {
  const _CitySuggestionChips({required this.cities, required this.onSelected});

  final List<String> cities;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cities.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final city = cities[index];
          return ActionChip(
            visualDensity: VisualDensity.compact,
            label: Text(city),
            onPressed: () => onSelected(city),
          );
        },
      ),
    );
  }
}

final class _LargeTextField extends StatelessWidget {
  const _LargeTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? errorText;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

final class _PanelActions extends StatelessWidget {
  const _PanelActions({required this.onBack, required this.onNext});

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Nazad'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Nastavi'),
          ),
        ),
      ],
    );
  }
}

final class _SuggestionLabel extends StatelessWidget {
  const _SuggestionLabel({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

final class _FinalReviewCard extends StatelessWidget {
  const _FinalReviewCard({
    required this.recipientName,
    required this.invoiceNumber,
    required this.issueDate,
    required this.lines,
    required this.totalLabel,
    required this.amountFormatter,
  });

  final String recipientName;
  final String invoiceNumber;
  final DateTime issueDate;
  final List<InvoiceLine> lines;
  final String totalLabel;
  final String Function(double amount) amountFormatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pregled računa',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ako nešto nije tačno, pritisnite odgovor u razgovoru i popravite ga.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            _ReviewRow(
              icon: Icons.business_outlined,
              label: 'Naručilac',
              value: recipientName,
            ),
            _ReviewRow(
              icon: Icons.receipt_long_outlined,
              label: 'Broj računa',
              value: invoiceNumber,
            ),
            _ReviewRow(
              icon: Icons.calendar_month_outlined,
              label: 'Datum računa',
              value: formatInvoiceDateMedium(issueDate),
            ),
            const SizedBox(height: 12),
            Text(
              'Stavke',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < lines.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _ReviewLine(
                index: i + 1,
                line: lines[i],
                amountLabel: '${amountFormatter(lines[i].iznosKm)} KM',
              ),
            ],
            const Divider(height: 24),
            _ReviewRow(
              icon: Icons.payments_outlined,
              label: 'Ukupno',
              value: totalLabel,
              strong: true,
            ),
          ],
        ),
      ),
    );
  }
}

final class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.value,
    this.strong = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _ReviewLine extends StatelessWidget {
  const _ReviewLine({
    required this.index,
    required this.line,
    required this.amountLabel,
  });

  final int index;
  final InvoiceLine line;
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.75),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stavka $index (vožnja)',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              line.putnaRelacija,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${formatInvoiceDateMedium(line.datumRacuna)} · '
              '${line.brojNarudzbe} · $amountLabel',
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
