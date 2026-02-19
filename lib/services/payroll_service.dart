import 'package:intl/intl.dart';
import 'worker_index_service.dart';
import 'attendance_storage_service.dart';
import 'payment_storage_service.dart';

// نموذج لتخزين نتائج الحساب لعامل واحد
class PayrollResult {
  final String workerName;
  final String totalEarned; // e.g. "21 دولار"
  final int absentDays;
  final double advances;
  final String netDue; // e.g. "11 دولار"

  PayrollResult({
    required this.workerName,
    required this.totalEarned,
    required this.absentDays,
    required this.advances,
    required this.netDue,
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

    for (var workerData in workersData.values) {
      int absentDays = 0;
      double totalAdvances = 0.0;
      double totalEarnedValue = 0.0;
      String latestWageUnit = '';

      for (int i = 0;
          i <= selectedDate.difference(firstDayOfMonth).inDays;
          i++) {
        final currentDate = firstDayOfMonth.add(Duration(days: i));
        final dateString =
            '${currentDate.year}/${currentDate.month}/${currentDate.day}';

        // 1. حساب الحضور والغياب والأجرة - جمع كل السطور لنفس العامل
        final attendanceDoc =
            await _attendanceService.loadAttendanceDocumentForDate(dateString);
        if (attendanceDoc != null) {
          // جمع كل سطور العامل في نفس اليوم
          final workerRecords = attendanceDoc.records
              .where((r) => r.workerName == workerData.name)
              .toList();

          for (var record in workerRecords) {
            if (record.status == 'موجود') {
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

        // 2. حساب الدفعات
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

      // 3. حساب النتائج النهائية
      final netDueValue = totalEarnedValue - totalAdvances;

      results.add(PayrollResult(
        workerName: workerData.name,
        totalEarned:
            '${totalEarnedValue.toStringAsFixed(2)} $latestWageUnit'.trim(),
        absentDays: absentDays,
        advances: totalAdvances,
        netDue: '${netDueValue.toStringAsFixed(2)} $latestWageUnit'.trim(),
      ));
    }

    return results;
  }
}
