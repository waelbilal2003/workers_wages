import 'package:flutter/material.dart';
import 'dart:async';
import '../models/attendance_model.dart';
import '../services/attendance_storage_service.dart';
import '../services/worker_index_service.dart';

class AttendanceChecklistScreen extends StatefulWidget {
  final String selectedDate;

  const AttendanceChecklistScreen({Key? key, required this.selectedDate})
      : super(key: key);

  @override
  _AttendanceChecklistScreenState createState() =>
      _AttendanceChecklistScreenState();
}

class _AttendanceChecklistScreenState extends State<AttendanceChecklistScreen> {
  final AttendanceStorageService _storageService = AttendanceStorageService();
  final WorkerIndexService _workerIndexService = WorkerIndexService();

  List<TextEditingController> _workerControllers = [];
  List<TextEditingController> _wageControllers = [];
  List<String> _statusValues = []; // "موجود" or "غائب"

  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrCreateChecklist();
    });
  }

  @override
  void dispose() {
    for (var c in _workerControllers) {
      c.dispose();
    }
    for (var c in _wageControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOrCreateChecklist() async {
    final document = await _storageService
        .loadAttendanceDocumentForDate(widget.selectedDate);
    if (document != null && document.records.isNotEmpty) {
      _loadChecklist(document);
    } else {
      _createNewChecklist();
    }
  }

  void _loadChecklist(AttendanceDocument document) {
    setState(() {
      _workerControllers.clear();
      _wageControllers.clear();
      _statusValues.clear();

      for (var record in document.records) {
        _workerControllers.add(TextEditingController(text: record.workerName));
        _wageControllers
            .add(TextEditingController(text: record.wageDescription));
        _statusValues.add(record.status);
      }
      _hasUnsavedChanges = false;
    });
  }

  void _createNewChecklist() {
    setState(() {
      _workerControllers.clear();
      _wageControllers.clear();
      _statusValues.clear();
      _hasUnsavedChanges = false;
      _addNewRow();
    });
  }

  void _addNewRow() {
    setState(() {
      _workerControllers.add(TextEditingController());
      _wageControllers.add(TextEditingController());
      _statusValues.add('موجود'); // القيمة الافتراضية
      _hasUnsavedChanges = true;
    });
  }

  void _showStatusDialog(int index) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('اختر الحالة'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                      title: const Text('موجود'),
                      onTap: () {
                        setState(() => _statusValues[index] = 'موجود');
                        Navigator.pop(context);
                      }),
                  ListTile(
                      title: const Text('غائب'),
                      onTap: () {
                        setState(() => _statusValues[index] = 'غائب');
                        Navigator.pop(context);
                      }),
                ],
              ),
            ));
  }

  Future<void> _saveChecklist() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final List<AttendanceRecord> records = [];
    for (int i = 0; i < _workerControllers.length; i++) {
      if (_workerControllers[i].text.isNotEmpty) {
        records.add(AttendanceRecord(
          workerName: _workerControllers[i].text.trim(),
          wageDescription: _wageControllers[i].text.trim(),
          status: _statusValues[i],
        ));
      }
    }

    final document =
        AttendanceDocument(date: widget.selectedDate, records: records);
    final success = await _storageService.saveAttendanceDocument(document);

    if (success) {
      for (var record in records) {
        await _workerIndexService.saveWorker(record.workerName);
      }
      setState(() => _hasUnsavedChanges = false);
    }

    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'تم الحفظ بنجاح' : 'فشل الحفظ'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'جدول التفقد\nبتاريخ ${widget.selectedDate}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, height: 1.2),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveChecklist,
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            _buildTableHeader(),
            Expanded(
              child: ListView.builder(
                itemCount: _workerControllers.length,
                itemBuilder: (context, index) => _buildTableRow(index),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewRow,
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: const [
          Expanded(
              flex: 3,
              child: Text('العامل',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 2,
              child: Text('الأجرة اليومية',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child: Text('الحالة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildTableRow(int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
                flex: 3,
                child: TextField(
                    controller: _workerControllers[index],
                    decoration: const InputDecoration(hintText: 'اسم العامل'))),
            const SizedBox(width: 8),
            Expanded(
                flex: 2,
                child: TextField(
                    controller: _wageControllers[index],
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(hintText: '7 دولار'))),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () => _showStatusDialog(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                    color: _statusValues[index] == 'موجود'
                        ? Colors.lightGreen[100]
                        : Colors.red[100],
                  ),
                  child: Center(child: Text(_statusValues[index])),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
