import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The id of the row a child shows, null for a separator or the footer.
@internal
typedef RowIdGetter = Object? Function(int childIndex);

/// Which child shows the row with [id] now, null once it's gone. [lastChildIndex] is where it was.
@internal
typedef RowIndexGetter = int? Function(Object id, int lastChildIndex);

/// Keeps the row the user is reading where it is when rows above it change, or a pull's room does. At
/// the very start nothing is kept, so a new row shows there and a pull pushes the rows.
///
/// Here until Flutter anchors scroll views itself: https://github.com/flutter/flutter/issues/99158.
@internal
class const ScrollAnchor({
  /// Which row a child shows.
  required final RowIdGetter rowIdGetter,

  /// Finds a row again once rows above it changed.
  required final RowIndexGetter rowIndexGetter,

  /// How far a pull pushes the rows from outside the scroll view.
  required final ValueListenable<double> pullExtentListenable,

  /// The keyed rows.
  required Widget sliver,
  super.key,
}) extends SingleChildRenderObjectWidget {
  /// Creates it.
  this : super(child: sliver);

  @override
  RenderScrollAnchor createRenderObject(BuildContext context) => RenderScrollAnchor(
    rowIdGetter: rowIdGetter,
    rowIndexGetter: rowIndexGetter,
    pullExtentListenable: pullExtentListenable,
  );

  @override
  void updateRenderObject(BuildContext context, RenderScrollAnchor renderObject) => renderObject
    ..rowIdGetter = rowIdGetter
    ..rowIndexGetter = rowIndexGetter
    ..pullExtentListenable = pullExtentListenable;
}

/// [ScrollAnchor]'s render object.
@internal
class RenderScrollAnchor({
  /// See [ScrollAnchor.rowIdGetter].
  required var RowIdGetter rowIdGetter,

  /// See [ScrollAnchor.rowIndexGetter].
  required var RowIndexGetter rowIndexGetter,
  required ValueListenable<double> pullExtentListenable,
}) extends RenderProxySliver {
  /// The 1st row on screen at the last layout, null at the very start.
  _AnchoredRow? _anchoredRow;

  var _pullExtentListenable = pullExtentListenable;

  late var _lastPullExtent = _pullExtentListenable.value;

  /// Creates it.
  this;

  /// See [ScrollAnchor.pullExtentListenable].
  ValueListenable<double> get pullExtentListenable => _pullExtentListenable;

  set pullExtentListenable(ValueListenable<double> value) {
    if (identical(value, _pullExtentListenable)) return;

    if (attached) {
      _pullExtentListenable.removeListener(markNeedsLayout);
      value.addListener(markNeedsLayout);
    }
    _pullExtentListenable = value;
  }

  bool get _isAtStart => constraints.scrollOffset < precisionErrorTolerance;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _pullExtentListenable.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _pullExtentListenable.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout() {
    final pullExtent = _pullExtentListenable.value;
    final pullCorrection = pullExtent - _lastPullExtent;
    _lastPullExtent = pullExtent;
    if (pullCorrection.abs() > precisionErrorTolerance && !_isAtStart) {
      // Scrolled away, the position takes up the pull's change, so the rows hold still.
      geometry = _correctionGeometry(pullCorrection);

      return;
    }

    final rowsSliver = child! as RenderSliverMultiBoxAdaptor
      ..layout(constraints, parentUsesSize: true);
    final rowsGeometry = rowsSliver.geometry!;

    final listCorrection = rowsGeometry.scrollOffsetCorrection;
    if (listCorrection != null) {
      // The list fixed its own estimate: its rows move with the position, so the record does too.
      _anchoredRow = _anchoredRow?.correctedBy(listCorrection);
      geometry = rowsGeometry;

      return;
    }

    final anchorCorrection = _anchorCorrectionIn(rowsSliver);
    if (anchorCorrection != null) {
      _anchoredRow = _anchoredRow?.correctedBy(anchorCorrection);
      geometry = _correctionGeometry(anchorCorrection);

      return;
    }

    _anchoredRow = _firstRowOnScreenIn(rowsSliver);
    geometry = rowsGeometry;
  }

  /// Never past the start, which a row after a separator or a shrinking pull can ask for.
  SliverGeometry _correctionGeometry(double correction) =>
      SliverGeometry(scrollOffsetCorrection: math.max(correction, -constraints.scrollOffset));

  /// How far the anchored row moved since the last layout, null if it didn't or it's gone.
  double? _anchorCorrectionIn(RenderSliverMultiBoxAdaptor rowsSliver) {
    final anchoredRow = _anchoredRow;
    if (anchoredRow == null || _isAtStart) return null;

    final childIndex = rowIndexGetter(anchoredRow.id, anchoredRow.childIndex);
    // Loops, like the per-item scans on the build path (APPENDIX.md#scan-loops).
    var anchoredBox = rowsSliver.firstChild;
    while (anchoredBox != null && rowsSliver.indexOf(anchoredBox) != childIndex) {
      anchoredBox = rowsSliver.childAfter(anchoredBox);
    }
    if (anchoredBox == null) return null;

    final anchorCorrection = rowsSliver.childScrollOffset(anchoredBox)! - anchoredRow.scrollOffset;

    return anchorCorrection.abs() <= precisionErrorTolerance ? null : anchorCorrection;
  }

  /// Null at the very start, so a new row there shows.
  _AnchoredRow? _firstRowOnScreenIn(RenderSliverMultiBoxAdaptor rowsSliver) {
    if (_isAtStart) return null;

    // By starts, since only the list may read its rows' sizes.
    RenderBox? edgeBox;
    for (
      var box = rowsSliver.firstChild;
      box != null && rowsSliver.childScrollOffset(box)! <= constraints.scrollOffset;
      box = rowsSliver.childAfter(box)
    ) {
      edgeBox = box;
    }
    // Only rows follow their item, so a separator or the footer hands over to the row after it.
    for (var box = edgeBox; box != null; box = rowsSliver.childAfter(box)) {
      final childIndex = rowsSliver.indexOf(box);
      final id = rowIdGetter(childIndex);
      if (id != null) {
        return (id: id, childIndex: childIndex, scrollOffset: rowsSliver.childScrollOffset(box)!);
      }
    }

    return null;
  }
}

typedef _AnchoredRow = ({Object id, int childIndex, double scrollOffset});

extension on _AnchoredRow {
  _AnchoredRow correctedBy(double correction) =>
      (id: id, childIndex: childIndex, scrollOffset: scrollOffset + correction);
}
