// lib/screens/attendance_checklist_screen.dart
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

  List<String> _workerNames = [];
  List<TextEditingController> _wageControllers = [];
  List<FocusNode> _wageFocusNodes = [];
  List<String> _statusValues = [];

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
    for (var c in _wageControllers) {
      c.dispose();
    }
    for (var n in _wageFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOrCreateChecklist() async {
    final allWorkers = await _workerIndexService.getAllWorkersWithData();
    if (!mounted) return;
    if (allWorkers.isEmpty) {
      setState(() {
        _workerNames = [];
      });
      return;
    }

    final document = await _storageService
        .loadAttendanceDocumentForDate(widget.selectedDate);

    setState(() {
      // تنظيف الموارد القديمة
      _workerNames.clear();
      _wageControllers.forEach((c) => c.dispose());
      _wageControllers.clear();
      _wageFocusNodes.forEach((n) => n.dispose());
      _wageFocusNodes.clear();
      _statusValues.clear();

      allWorkers.values.forEach((worker) {
        // === START OF FIX ===
        // البحث عن السجل المحفوظ للعامل الحالي
        final savedRecord = document?.records.firstWhere(
          (r) => r.workerName == worker.name,
          orElse: () => AttendanceRecord(
              workerName: '',
              wageDescription: '',
              status: ''), // قيمة وهمية في حالة عدم العثور
        );
        // التحقق مما إذا كان السجل موجوداً حقاً
        final bool recordFound =
            savedRecord != null && savedRecord.workerName.isNotEmpty;
        // === END OF FIX ===

        _workerNames.add(worker.name);

        _wageControllers.add(TextEditingController(
            text: recordFound ? savedRecord.wageDescription : ''));
        _wageFocusNodes.add(FocusNode());
        _statusValues.add(recordFound ? savedRecord.status : 'موجود');
      });
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _saveChecklist() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final List<AttendanceRecord> records = [];
    for (int i = 0; i < _workerNames.length; i++) {
      records.add(AttendanceRecord(
        workerName: _workerNames[i],
        wageDescription: _wageControllers[i].text.trim(),
        status: _statusValues[i],
      ));
    }

    final document =
        AttendanceDocument(date: widget.selectedDate, records: records);
    final success = await _storageService.saveAttendanceDocument(document);

    if (success) {
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
                        setState(() {
                          _statusValues[index] = 'موجود';
                          _hasUnsavedChanges = true; // <-- الإصلاح: تفعيل الحفظ
                        });
                        Navigator.pop(context);
                      }),
                  ListTile(
                      title: const Text('غائب'),
                      onTap: () {
                        setState(() {
                          _statusValues[index] = 'غائب';
                          _hasUnsavedChanges = true; // <-- الإصلاح: تفعيل الحفظ
                        });
                        Navigator.pop(context);
                      }),
                ],
              ),
            ));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // إضافة تحذير عند الخروج بوجود تغييرات غير محفوظة
      onWillPop: () async {
        if (_hasUnsavedChanges) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('تغييرات غير محفوظة'),
              content: const Text('هل تريد الخروج بدون حفظ؟'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('البقاء')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('خروج')),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'جدول التفقد\nبتاريخ ${widget.selectedDate}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.2),
          ),
          centerTitle: true,
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white))
                  : Stack(
                      children: [
                        const Icon(Icons.save),
                        if (_hasUnsavedChanges)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                              constraints: const BoxConstraints(
                                  minWidth: 10, minHeight: 10),
                            ),
                          ),
                      ],
                    ),
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
                child: _workerNames.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'لا يوجد عمال مسجلين.\nالرجاء إضافتهم من القائمة الرئيسية عبر "ادخال الاسماء" أولاً.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _workerNames.length,
                        itemBuilder: (context, index) => _buildTableRow(index),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
                flex: 3,
                child: Text(_workerNames[index],
                    style: const TextStyle(fontWeight: FontWeight.w500))),
            const SizedBox(width: 8),
            Expanded(
                flex: 2,
                child: TextField(
                  controller: _wageControllers[index],
                  focusNode: _wageFocusNodes[index],
                  textAlign: TextAlign.center,
                  decoration:
                      const InputDecoration.collapsed(hintText: 'ادخل الأجرة'),
                  onChanged: (val) {
                    // <-- الإصلاح: تفعيل الحفظ
                    if (!_hasUnsavedChanges) {
                      setState(() {
                        _hasUnsavedChanges = true;
                      });
                    }
                  },
                  onSubmitted: (val) {
                    if (index < _wageFocusNodes.length - 1) {
                      FocusScope.of(context)
                          .requestFocus(_wageFocusNodes[index + 1]);
                    } else {
                      FocusScope.of(context).unfocus();
                      _saveChecklist();
                    }
                  },
                )),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () => _showStatusDialog(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _statusValues[index] == 'موجود'
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                  ),
                  child: Center(
                    child: Text(
                      _statusValues[index],
                      style: TextStyle(
                        color: _statusValues[index] == 'موجود'
                            ? Colors.green[800]
                            : Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
