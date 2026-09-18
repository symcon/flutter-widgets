// Regression test for the trackball indexing a stale segment list after a
// series' data changed while the series was hidden. See lib/main.dart for
// the full description of the sequence.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class _Point {
  _Point(this.x, this.y);

  final num x;
  final num y;
}

List<_Point> _points(int count) {
  return List<_Point>.generate(
    count,
    (int index) => _Point(index, (index * 7) % 13),
  );
}

Widget _chart({
  required List<_Point> data,
  required TrackballBehavior trackball,
  required bool column,
  required void Function(ChartSeriesController<_Point, num>) onCreated,
}) {
  final CartesianSeries<_Point, num> series = column
      ? ColumnSeries<_Point, num>(
          dataSource: data,
          animationDuration: 0,
          xValueMapper: (_Point point, _) => point.x,
          yValueMapper: (_Point point, _) => point.y,
          onRendererCreated: onCreated,
        )
      : LineSeries<_Point, num>(
          dataSource: data,
          animationDuration: 0,
          xValueMapper: (_Point point, _) => point.x,
          yValueMapper: (_Point point, _) => point.y,
          onRendererCreated: onCreated,
        );
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 300,
        child: SfCartesianChart(
          primaryXAxis: NumericAxis(),
          trackballBehavior: trackball,
          series: <CartesianSeries<_Point, num>>[series],
        ),
      ),
    ),
  );
}

void main() {
  for (final bool column in <bool>[true, false]) {
    final String kind = column ? 'ColumnSeries' : 'LineSeries';

    testWidgets(
        '$kind: trackball after the data grew while the series was hidden',
        (WidgetTester tester) async {
      ChartSeriesController<_Point, num>? controller;
      final TrackballBehavior trackball = TrackballBehavior(enable: true);
      await tester.pumpWidget(_chart(
        data: _points(5),
        trackball: trackball,
        column: column,
        onCreated: (ChartSeriesController<_Point, num> c) => controller = c,
      ));
      controller!.isVisible = false;
      await tester.pump();

      await tester.pumpWidget(_chart(
        data: _points(50),
        trackball: trackball,
        column: column,
        onCreated: (ChartSeriesController<_Point, num> c) => controller = c,
      ));

      // Show the series and activate the trackball before the next frame,
      // like a pointer event right after a legend tap.
      controller!.isVisible = true;
      trackball.show(350, 150, 'pixel');
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });

    testWidgets(
        '$kind: trackball after data arrived while the empty series was hidden',
        (WidgetTester tester) async {
      ChartSeriesController<_Point, num>? controller;
      final TrackballBehavior trackball = TrackballBehavior(enable: true);
      await tester.pumpWidget(_chart(
        data: <_Point>[],
        trackball: trackball,
        column: column,
        onCreated: (ChartSeriesController<_Point, num> c) => controller = c,
      ));
      controller!.isVisible = false;
      await tester.pump();

      await tester.pumpWidget(_chart(
        data: _points(20),
        trackball: trackball,
        column: column,
        onCreated: (ChartSeriesController<_Point, num> c) => controller = c,
      ));

      controller!.isVisible = true;
      trackball.show(200, 150, 'pixel');
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });
  }
}
