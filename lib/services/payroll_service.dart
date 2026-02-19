import 'package:intl/intl.dart';
import 'worker_index_service.dart';
import 'attendance_storage_service.dart';
import 'payment_storage_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// نموذج لتخزين نتائج الحساب لعامل واحد
class PayrollResult {
  final String workerName;
  final int presentDays;
  final int absentDays;
  final double advances;
  final double netDue;
  final String wageUnit;
  final String currency;

  PayrollResult({
    required this.workerName,
    required this.presentDays,
    required this.absentDays,
    required this.advances,
    required this.netDue,
    required this.wageUnit,
    required this.currency,
  });
}

class PayrollService {
  final WorkerIndexService _workerService = WorkerIndexService();
  final AttendanceStorageService _attendanceService =
      AttendanceStorageService();
  final PaymentStorageService _paymentService = PaymentStorageService();

  // دالة مساعدة لاستخراج الرقم والوحدة من نص مثل "7 دولار"
  Map<String, dynamic> _parseWage(String wageDescription) {
    if (wageDescription.isEmpty) {
      return {'value': 0.0, 'unit': ''};
    }
    final regex = RegExp(r'(\d+\.?\d*)\s*(.*)');
    final match = regex.firstMatch(wageDescription);
    if (match != null) {
      final value = double.tryParse(match.group(1)!) ?? 0.0;
      final unit = match.group(2)!.trim();
      return {'value': value, 'unit': unit};
    }
    return {'value': 0.0, 'unit': wageDescription}; // إذا لم يكن هناك رقم
  }

  Future<List<PayrollResult>> calculatePayroll(String selectedDateStr) async {
    final workersData = await _workerService.getAllWorkersWithData();
    if (workersData.isEmpty) return [];

    final List<PayrollResult> results = [];
    final selectedDate = DateFormat('yyyy/M/d').parse(selectedDateStr);
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final collectionDates = await _loadCollectionDates();

    for (var workerData in workersData.values) {
      int absentDays = 0;
      int presentDays = 0;
      double totalAdvances = 0.0;
      double totalEarnedValue = 0.0;
      String latestWageUnit = '';

      // تحديد تاريخ البداية: آخر قبض أو بداية الشهر
      DateTime startDate = firstDayOfMonth;
      if (collectionDates.containsKey(workerData.name)) {
        try {
          final collectionDate =
              DateFormat('yyyy/M/d').parse(collectionDates[workerData.name]!);
          // نبدأ من اليوم التالي لتاريخ القبض
          startDate = collectionDate.add(const Duration(days: 1));
        } catch (_) {}
      }

      for (int i = 0; i <= selectedDate.difference(startDate).inDays; i++) {
        final currentDate = startDate.add(Duration(days: i));
        final dateString =
            '${currentDate.year}/${currentDate.month}/${currentDate.day}';

        final attendanceDoc =
            await _attendanceService.loadAttendanceDocumentForDate(dateString);
        if (attendanceDoc != null) {
          final workerRecords = attendanceDoc.records
              .where((r) => r.workerName == workerData.name)
              .toList();

          for (var record in workerRecords) {
            if (record.status == 'موجود') {
              presentDays++;
              final parsedWage = _parseWage(record.wageDescription);
              totalEarnedValue += parsedWage['value'];
              if (parsedWage['unit'].isNotEmpty) {
                latestWageUnit = parsedWage['unit'];
              }
            } else {
              absentDays++;
            }
          }
        }

        final paymentDoc =
            await _paymentService.loadPaymentDocumentForDate(dateString);
        if (paymentDoc != null) {
          for (var payment in paymentDoc.transactions) {
            if (payment.workerName == workerData.name) {
              totalAdvances += double.tryParse(payment.paymentValue) ?? 0.0;
            }
          }
        }
      }

      final netDueValue = totalEarnedValue - totalAdvances;

      results.add(PayrollResult(
        workerName: workerData.name,
        presentDays: presentDays,
        absentDays: absentDays,
        advances: totalAdvances,
        netDue: netDueValue,
        wageUnit: latestWageUnit,
        currency: workerData.currency, // إضافة العملة من بيانات العامل
      ));
    }

    return results;
  }

  Future<String> _getCollectionFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/worker_collection_dates.json';
  }

  Future<Map<String, String>> _loadCollectionDates() async {
    try {
      final file = File(await _getCollectionFilePath());
      if (await file.exists()) {
        final Map<String, dynamic> json = jsonDecode(await file.readAsString());
        return json.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
    return {};
  }

  Future<void> saveCollectionDate(String workerName, String date) async {
    try {
      final dates = await _loadCollectionDates();
      dates[workerName] = date;
      final file = File(await _getCollectionFilePath());
      await file.writeAsString(jsonEncode(dates));
    } catch (_) {}
  }
}
