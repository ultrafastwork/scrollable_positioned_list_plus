// Host side of the profile-mode harness in `integration_test/perf_test.dart`.
//
// Writes one `build/perf/<scenario>.json` per scenario (the full
// FrameTimingSummarizer output) and prints a compact table of the key numbers.

import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

const _outputDir = 'build/perf';

const _columns = <String, String>{
  'frame_count': 'frames',
  'average_frame_build_time_millis': 'build avg',
  '90th_percentile_frame_build_time_millis': 'build p90',
  '99th_percentile_frame_build_time_millis': 'build p99',
  'worst_frame_build_time_millis': 'build worst',
  'average_frame_rasterizer_time_millis': 'raster avg',
  '90th_percentile_frame_rasterizer_time_millis': 'raster p90',
  '99th_percentile_frame_rasterizer_time_millis': 'raster p99',
  'worst_frame_rasterizer_time_millis': 'raster worst',
  'missed_frame_build_budget_count': 'missed build',
  'missed_frame_rasterizer_budget_count': 'missed raster',
};

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null || data.isEmpty) {
      stderr.writeln('perf_driver: no performance data was reported.');
      return;
    }
    final dir = Directory(_outputDir)..createSync(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    for (final entry in data.entries) {
      File(
        '${dir.path}/${entry.key}.json',
      ).writeAsStringSync(encoder.convert(entry.value));
    }
    stdout.writeln(_table(data));
    stdout.writeln('perf_driver: wrote ${data.length} summaries to $_outputDir/');
  },
);

/// A Markdown table, ready to paste into a task file.
String _table(Map<String, dynamic> data) {
  String format(Object? value) => switch (value) {
    final double d => d.toStringAsFixed(2),
    null => '-',
    _ => '$value',
  };

  final buffer = StringBuffer()
    ..writeln('| scenario | ${_columns.values.join(' | ')} |')
    ..writeln('|---|${List.filled(_columns.length, '---').join('|')}|');
  final keys = data.keys.toList()..sort();
  for (final key in keys) {
    final summary = data[key];
    if (summary is! Map) continue;
    final cells = _columns.keys.map((column) => format(summary[column]));
    buffer.writeln('| $key | ${cells.join(' | ')} |');
  }
  return buffer.toString();
}
