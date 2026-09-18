# charts_example

Reproduces a crash in `TrackballBehavior` when a series is shown again
after its data source changed while the series was hidden.

While a series is hidden (legend tap or `ChartSeriesController.isVisible`)
its renderer skips `performLayout`, where the segments are created. A data
source update in that state still repopulates the data points, so the data
count and the segment list run out of sync. Showing the series schedules
the rebuild for the next frame; any trackball activation before that frame
(pointer enter, tap or `TrackballBehavior.show`) throws

```
RangeError (length): Invalid value: Not in inclusive range 0..4: 5
  ChartSeriesRenderer.segmentAt
  TrackballBehavior._generateAllPoints.<anonymous closure>
```

or, for a series that was empty while hidden,

```
RangeError (length): Invalid value: Valid value range is empty: 0
```

Run the app and press "Run all steps", or hide the series, add data, and
press "Show series + trackball". `test/trackball_hidden_series_test.dart`
contains the same sequence as a widget test.
