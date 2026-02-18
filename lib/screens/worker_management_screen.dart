import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/worker_index_service.dart';

class WorkerManagementScreen extends StatefulWidget {
  const WorkerManagementScreen({super.key});

  @override
  State<WorkerManagementScreen> createState() => _WorkerManagementScreenState();
}

class _WorkerManagementScreenState extends State<WorkerManagementScreen> {
  final WorkerIndexService _workerIndexService = WorkerIndexService();
  Map<int, WorkerData> _workersData = {};

  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocusNode = FocusNode();

  // متحكمات وعُقد تركيز للتعديل المباشر
  Map<String, TextEditingController> _mobileControllers = {};
  Map<String, FocusNode> _mobileFocusNodes = {};
  Map<String, TextEditingController> _balanceControllers = {};
  Map<String, FocusNode> _balanceFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    _mobileControllers.values.forEach((c) => c.dispose());
    _mobileFocusNodes.values.forEach((n) => n.dispose());
    _balanceControllers.values.forEach((c) => c.dispose());
    _balanceFocusNodes.values.forEach((n) => n.dispose());
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    final workers = await _workerIndexService.getAllWorkersWithData();
    if (mounted) {
      setState(() {
        _workersData = workers;
        _initializeControllersAndNodes();
      });
    }
  }

  void _initializeControllersAndNodes() {
    // تنظيف الموارد القديمة قبل إعادة التهيئة
    _mobileControllers.values.forEach((c) => c.dispose());
    _mobileFocusNodes.values.forEach((n) => n.dispose());
    _balanceControllers.values.forEach((c) => c.dispose());
    _balanceFocusNodes.values.forEach((n) => n.dispose());

    _mobileControllers.clear();
    _mobileFocusNodes.clear();
    _balanceControllers.clear();
    _balanceFocusNodes.clear();

    // إعادة بناء المتحكمات والعُقد
    _workersData.forEach((key, worker) {
      // متحكمات وعقد للموبايل
      _mobileControllers[worker.name] =
          TextEditingController(text: worker.mobile);
      _mobileFocusNodes[worker.name] = FocusNode();
      _mobileFocusNodes[worker.name]!.addListener(() {
        if (!_mobileFocusNodes[worker.name]!.hasFocus) {
          _saveMobileEdit(worker.name);
        }
      });

      // متحكمات وعقد للرصيد (الاجرة يومية)
      _balanceControllers[worker.name] =
          TextEditingController(text: worker.balance.toStringAsFixed(2));
      _balanceFocusNodes[worker.name] = FocusNode();
      _balanceFocusNodes[worker.name]!.addListener(() {
        if (!_balanceFocusNodes[worker.name]!.hasFocus) {
          _saveBalanceEdit(worker.name);
        }
      });
    });
  }

  Future<void> _addNewWorker() async {
    final name = _addController.text.trim();
    if (name.isNotEmpty) {
      await _workerIndexService.saveWorker(name);
      _addController.clear();
      _addFocusNode.unfocus();
      await _loadWorkers();
    }
  }

  Future<void> _deleteWorker(WorkerData worker) async {
    if (worker.balance != 0.0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'لا يمكن حذف عامل أجرته اليومية غير صفر (${worker.balance.toStringAsFixed(2)})'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف العامل "${worker.name}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );

    if (confirm == true) {
      await _workerIndexService.removeWorker(worker.name);
      await _loadWorkers();
    }
  }

  Future<void> _saveMobileEdit(String workerName) async {
    final newMobile = _mobileControllers[workerName]?.text.trim() ?? '';
    await _workerIndexService.updateWorkerMobile(workerName, newMobile);
  }

  Future<void> _saveBalanceEdit(String workerName) async {
    final newBalance = double.tryParse(
            _balanceControllers[workerName]?.text.trim() ?? '0.0') ??
        0.0;
    await _workerIndexService.setInitialBalance(workerName, newBalance);
  }

  @override
  Widget build(BuildContext context) {
    List<MapEntry<int, WorkerData>> sortedEntries =
        _workersData.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        // تم التعديل: تغيير العنوان ومحاذاته لليمين
        centerTitle: false,
        title: Align(
          alignment: Alignment.centerRight,
          child: const Text('أسماء العمال وأجورهم'),
        ),
        backgroundColor: Colors.teal[600],
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _addController,
                focusNode: _addFocusNode,
                decoration: InputDecoration(
                  labelText: 'إضافة عامل جديد',
                  suffixIcon: IconButton(
                      icon: const Icon(Icons.add), onPressed: _addNewWorker),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addNewWorker(),
              ),
            ),
            // رأس الجدول
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: const [
                  Expanded(
                      flex: 2,
                      child: Text('الاسم',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  // تم التعديل: تغيير النص
                  Expanded(
                      flex: 2,
                      child: Text('الاجرة اليومية',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center)),
                  Expanded(
                      flex: 3,
                      child: Text('الموبايل',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center)),
                  Expanded(
                      flex: 2,
                      child: Text('تاريخ البدء',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center)),
                  SizedBox(width: 24),
                ],
              ),
            ),
            // قائمة العمال
            Expanded(
              child: sortedEntries.isEmpty
                  ? const Center(child: Text('لا يوجد عمال مسجلين.'))
                  : ListView.builder(
                      itemCount: sortedEntries.length,
                      itemBuilder: (context, index) {
                        final entry = sortedEntries[index];
                        final worker = entry.value;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Row(
                              children: [
                                Expanded(
                                    flex: 2,
                                    child: Text(worker.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold))),
                                Expanded(
                                    flex: 2,
                                    child: _buildEditableCell(
                                      _balanceControllers[worker.name],
                                      _balanceFocusNodes[worker.name],
                                      isNumeric: true,
                                    )),
                                Expanded(
                                    flex: 3,
                                    child: _buildEditableCell(
                                        _mobileControllers[worker.name],
                                        _mobileFocusNodes[worker.name],
                                        isNumeric: true,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly
                                        ])),
                                // تم الإصلاح: التعامل الآمن مع قيمة التاريخ
                                Expanded(
                                    flex: 2,
                                    child: Center(
                                        child: Text(worker.startDate ?? '',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black)))),
                                SizedBox(
                                  width: 24,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _deleteWorker(worker),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableCell(
      TextEditingController? controller, FocusNode? focusNode,
      {bool isNumeric = false, List<TextInputFormatter>? inputFormatters}) {
    if (controller == null || focusNode == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: inputFormatters,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
          border: UnderlineInputBorder(),
        ),
      ),
    );
  }
}
