import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'firestore_service.dart';
import 'screen_time_service.dart';

class WeeklyReportService {
  WeeklyReportService._();

  static final WeeklyReportService instance = WeeklyReportService._();

  final _firestore = FirestoreService.instance;
  final _screenTime = ScreenTimeService.instance;

  Future<void> exportWeeklyReport({
    required BuildContext context,
    required String uid,
    int days = 7,
  }) async {
    final insights = await _firestore.getInsightsOnce(uid, days: days);
    final profile = await _firestore.getUserProfile(uid) ?? const <String, dynamic>{};
    final name = (profile['name'] as String?)?.trim();
    final displayName = (name == null || name.isEmpty) ? 'User' : name;

    final doc = pw.Document();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final usageSnapshot = await _loadWeeklyUsage(start: start, end: now, days: days);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _titleSection(displayName, start, now),
          pw.SizedBox(height: 16),
          _summarySection(insights),
          pw.SizedBox(height: 16),
          _weeklyChartSection(start, usageSnapshot.weeklyHours),
          pw.SizedBox(height: 16),
          _categorySection(insights),
          pw.SizedBox(height: 16),
          _topAppsSection(usageSnapshot.topApps),
          pw.SizedBox(height: 16),
          _habitsSection(insights),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'LifeInSync-weekly-report.pdf',
    );
  }

  pw.Widget _titleSection(String name, DateTime start, DateTime end) {
    final rangeLabel = _fmtDateRange(start, end);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'LifeInSync Weekly Report',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Name: $name'),
        pw.Text('Period: $rangeLabel'),
      ],
    );
  }

  pw.Widget _summarySection(InsightData insights) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Average wellbeing: ${insights.avgWellbeing.toStringAsFixed(1)}'),
          pw.Text('Average fatigue: ${insights.avgFatigue.toStringAsFixed(1)}'),
          pw.Text('Focus hours: ${insights.focusHours.toStringAsFixed(1)}h'),
          pw.Text('Productive ratio: ${(insights.productiveRatio * 100).round()}%'),
        ],
      ),
    );
  }

  pw.Widget _categorySection(InsightData insights) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Category breakdown',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tableCell('Category', bold: true),
                _tableCell('Time', bold: true),
              ],
            ),
            ...insights.categoryRows.map(
              (row) => pw.TableRow(
                children: [
                  _tableCell(row.$1),
                  _tableCell(row.$2),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _weeklyChartSection(DateTime start, List<double> hours) {
    final maxHours = hours.isEmpty ? 0.0 : hours.reduce((a, b) => a > b ? a : b);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Weekly screen time',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        if (maxHours <= 0)
          pw.Text('No screen time data yet.')
        else
          _barChart(start, hours, maxHours),
      ],
    );
  }

  pw.Widget _barChart(DateTime start, List<double> hours, double maxHours) {
    const chartHeight = 120.0;
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: List.generate(hours.length, (index) {
          final day = start.add(Duration(days: index));
          final label = _weekdayLabel(day.weekday);
          final value = hours[index];
          final height = (value / maxHours) * chartHeight;

          return pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Container(
                width: 16,
                height: height.isNaN ? 0 : height,
                decoration: pw.BoxDecoration(
                  color: PdfColors.green400,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
            ],
          );
        }),
      ),
    );
  }

  pw.Widget _topAppsSection(List<(String, int)> topApps) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Top apps (weekly)',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        if (topApps.isEmpty)
          pw.Text('No app usage data yet.')
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _tableCell('App', bold: true),
                  _tableCell('Time', bold: true),
                ],
              ),
              ...topApps.map(
                (row) => pw.TableRow(
                  children: [
                    _tableCell(row.$1),
                    _tableCell(_fmtMinutes(row.$2)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _habitsSection(InsightData insights) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Habit consistency',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tableCell('Habit', bold: true),
                _tableCell('Completed', bold: true),
              ],
            ),
            ...insights.habitConsistency.map(
              (row) => pw.TableRow(
                children: [
                  _tableCell(row.$2),
                  _tableCell('${row.$3}/${row.$4}'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _tableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  String _fmtDateRange(DateTime start, DateTime end) {
    return '${_fmtDate(start)} - ${_fmtDate(end)}';
  }

  String _fmtDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  String _weekdayLabel(int weekday) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[(weekday - 1).clamp(0, labels.length - 1)];
  }

  String _fmtMinutes(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  Future<_WeeklyUsageSnapshot> _loadWeeklyUsage({
    required DateTime start,
    required DateTime end,
    required int days,
  }) async {
    try {
      final buckets = await _screenTime.getDailyUsageBucketsForRange(
        start: start,
        end: end,
      );

      final byDay = {
        for (final b in buckets) _dateKey(b.date): b,
      };

      final hours = <double>[];
      final appMinutes = <String, int>{};

      for (var i = 0; i < days; i++) {
        final day = start.add(Duration(days: i));
        final bucket = byDay[_dateKey(day)];
        final totalMinutes = bucket?.totalMinutes ?? 0;
        hours.add(totalMinutes / 60);

        for (final app in bucket?.apps ?? const <ScreenUsageEntry>[]) {
          appMinutes[app.appName] =
              (appMinutes[app.appName] ?? 0) + app.usageMinutes;
        }
      }

      final topApps = appMinutes.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return _WeeklyUsageSnapshot(
        weeklyHours: hours,
        topApps: topApps.take(10).map((e) => (e.key, e.value)).toList(),
      );
    } catch (_) {
      return const _WeeklyUsageSnapshot(weeklyHours: <double>[], topApps: <(String, int)>[]);
    }
  }

  String _dateKey(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }
}

class _WeeklyUsageSnapshot {
  final List<double> weeklyHours;
  final List<(String, int)> topApps;

  const _WeeklyUsageSnapshot({
    required this.weeklyHours,
    required this.topApps,
  });
}
