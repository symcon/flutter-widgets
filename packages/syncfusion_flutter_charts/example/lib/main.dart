import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

/// Reproduces a crash in [TrackballBehavior] when a series is shown again
/// after its data changed while it was hidden.
///
/// Hiding a series (legend tap or [ChartSeriesController.isVisible]) makes
/// the series renderer skip [RenderBox.performLayout], where the segments
/// are created. A data source update in that state still repopulates the
/// data points, so the series' data count no longer matches its segments.
/// When the series is shown again, the chart schedules a rebuild for the
/// next frame. Any trackball activation that arrives before that frame
/// (a pointer entering the plot area, a tap, or [TrackballBehavior.show])
/// derives the nearest point index from the new data count and indexes
/// into the stale segment list:
///
///   RangeError (length): Invalid value: Not in inclusive range 0..4: 5
///     ChartSeriesRenderer.segmentAt
///     TrackballBehavior._generateAllPoints.<anonymous closure>
///
/// Steps: "1. Hide series", "2. Add data", "3. Show series + trackball", or
/// "Run all steps" to execute them with a frame in between. Step 3 shows
/// the series and activates the trackball in the same event handler, which
/// is what a mouse move right after a legend tap does as well.
void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _lastError.value = details.exceptionAsString();
  };
  runApp(const _TrackballReproApp());
}

final ValueNotifier<String?> _lastError = ValueNotifier<String?>(null);

class _TrackballReproApp extends StatelessWidget {
  const _TrackballReproApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: false),
      home: const _TrackballReproPage(),
    );
  }
}

class _TrackballReproPage extends StatefulWidget {
  const _TrackballReproPage();

  @override
  State<_TrackballReproPage> createState() => _TrackballReproPageState();
}

class _TrackballReproPageState extends State<_TrackballReproPage> {
  final GlobalKey _chartKey = GlobalKey();
  final TrackballBehavior _trackball = TrackballBehavior(
    enable: true,
    activationMode: ActivationMode.singleTap,
    tooltipDisplayMode: TrackballDisplayMode.floatAllPoints,
  );
  ChartSeriesController<_Point, num>? _controller;
  List<_Point> _data = _generate(5);
  bool _hidden = false;

  static List<_Point> _generate(int count) {
    return List<_Point>.generate(
      count,
      (int index) => _Point(index, 20 + (index * 37) % 60),
    );
  }

  void _hideSeries() {
    _controller?.isVisible = false;
    setState(() => _hidden = true);
  }

  void _addData() {
    setState(() => _data = _generate(_data.length + 10));
  }

  void _showSeriesAndTrackball() {
    _controller?.isVisible = true;
    setState(() => _hidden = false);
    // Activate the trackball before the frame that re-lays out the series,
    // the same way a pointer event arriving right after the legend tap does.
    final RenderBox chart =
        _chartKey.currentContext!.findRenderObject()! as RenderBox;
    try {
      _trackball.show(chart.size.width * 0.9, chart.size.height / 2, 'pixel');
      _lastError.value = null;
    } catch (error, stackTrace) {
      _lastError.value = '$error\n$stackTrace';
    }
  }

  Future<void> _runAllSteps() async {
    _hideSeries();
    await _nextFrame();
    _addData();
    await _nextFrame();
    _showSeriesAndTrackball();
  }

  Future<void> _nextFrame() {
    return WidgetsBinding.instance.endOfFrame;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trackball after hidden data update')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SfCartesianChart(
              key: _chartKey,
              primaryXAxis: NumericAxis(),
              legend: Legend(isVisible: true),
              trackballBehavior: _trackball,
              series: <CartesianSeries<_Point, num>>[
                ColumnSeries<_Point, num>(
                  name: 'Sales',
                  dataSource: _data,
                  // Live charts typically update without animation. While a
                  // series animates, the trackball skips it, which would
                  // hide the crash in this example.
                  animationDuration: 0,
                  xValueMapper: (_Point point, _) => point.x,
                  yValueMapper: (_Point point, _) => point.y,
                  onRendererCreated:
                      (ChartSeriesController<_Point, num> controller) {
                    _controller = controller;
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${_data.length} data points, series ${_hidden ? 'hidden' : 'visible'}. '
              'Hide the series, add data, then show it and open the trackball '
              'before the next frame. Tapping the legend and moving the mouse '
              'into the plot area right away reproduces the same crash.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ElevatedButton(
                  onPressed: _hideSeries,
                  child: const Text('1. Hide series'),
                ),
                ElevatedButton(
                  onPressed: _addData,
                  child: const Text('2. Add data'),
                ),
                ElevatedButton(
                  onPressed: _showSeriesAndTrackball,
                  child: const Text('3. Show series + trackball'),
                ),
                ElevatedButton(
                  onPressed: _runAllSteps,
                  child: const Text('Run all steps'),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: _lastError,
            builder: (BuildContext context, String? error, _) {
              if (error == null) {
                return const SizedBox.shrink();
              }
              return Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade50,
                child: SingleChildScrollView(
                  child: SelectableText(
                    error,
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Point {
  _Point(this.x, this.y);

  final num x;
  final num y;
}
