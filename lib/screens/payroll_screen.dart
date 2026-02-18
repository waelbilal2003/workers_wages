import 'package:flutter/material.dart';
import '../services/payroll_service.dart';

class PayrollScreen extends StatefulWidget {
  final String selectedDate;

  const PayrollScreen({Key? key, required this.selectedDate}) : super(key: key);

  @override
  _PayrollScreenState createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final PayrollService _payrollService = PayrollService();
  late Future<List<PayrollResult>> _payrollFuture;

  @override
  void initState() {
    super.initState();
    _payrollFuture = _payrollService.calculatePayroll(widget.selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'احتساب الاجرة المستحقة\nلغاية تاريخ ${widget.selectedDate}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, height: 1.2),
        ),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: FutureBuilder<List<PayrollResult>>(
          future: _payrollFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('حدث خطأ: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('لا توجد بيانات لعرضها.'));
            }

            final results = snapshot.data!;
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(
                        label: Text('العامل',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(
                        label: Text('أيام الدوام',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        numeric: true),
                    DataColumn(
                        label: Text('أيام الغياب',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        numeric: true),
                    DataColumn(
                        label: Text('دفعة من الحساب',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        numeric: true),
                    DataColumn(
                        label: Text('الاستحقاق',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        numeric: true),
                  ],
                  rows: results
                      .map((result) => DataRow(cells: [
                            DataCell(Text(result.workerName)),
                            DataCell(Text(result.totalEarned)),
                            DataCell(Text(result.absentDays.toString())),
                            DataCell(Text(result.advances.toStringAsFixed(2))),
                            DataCell(Text(result.netDue,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green))),
                          ]))
                      .toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
