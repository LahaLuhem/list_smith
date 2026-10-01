import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '/src/data/pagination/typedefs/item_id_getter.dart';
import '/src/data/presentation/typedefs/item_builder.dart';

/// The rows edits are animating in and out, one controller per item id.
///
/// An exit holds its removal back until it ends, so the leaving row stays in the display, exactly where
/// it was, and a later edit on the same id turns it round.
final class RowTransitionsNotifier<T extends Object> extends ChangeNotifier {
  /// Ticks the controllers.
  final TickerProvider vsync;

  /// Removes an item once its row has gone.
  final void Function(T item) bookRemoval;

  final _transitions = <Object, _Transition<T>>{};
  final _rows = <Object, _TransitionRowState<T>>{};

  /// Creates it.
  new({required this.vsync, required this.bookRemoval});

  /// [itemBuilder] for one build, each row wrapped in [transitionBuilder] while it animates.
  ItemBuilder<T> decorate(
    ItemBuilder<T> itemBuilder, {
    required ItemIdGetter<T> itemIdGetter,
    required AnimatedSwitcherTransitionBuilder transitionBuilder,
  }) =>
      (_, item, index) => _TransitionRow(
        rowTransitionsNotifier: this,
        id: itemIdGetter(item),
        transitionBuilder: transitionBuilder,
        buildChild: (context) => itemBuilder(context, item, index),
      );

  /// Animates in the row an upsert just added, or brings a leaving one back.
  void upsert(Object id, {required bool isNewRow, required Duration duration}) {
    final transition = _transitions[id];
    if (transition == null) {
      if (isNewRow) _animate(_start(id, duration, value: 0), isEntering: true);

      return;
    }
    if (transition.leavingItem == null) return;

    transition
      ..leavingItem = null
      ..leavingChild = null;
    _animate(transition, isEntering: true);
  }

  /// Animates a shown row out, then removes [item].
  void remove(Object id, T item, {required Duration duration, required Axis axis}) {
    final transition = _transitions[id];
    if (transition != null) {
      transition
        ..leavingItem = item
        ..leavingChild ??= _rows[id]?._lastChild;
      _animate(transition, isEntering: false);

      return;
    }

    _start(id, duration, value: 1)
      ..leavingItem = item
      ..leavingChild = _rows[id]?._lastChild;
    // A frame on, so a row that shrank itself (a Dismissible, a Slidable) reads as empty. Those throw
    // if kept in the tree once they're done.
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _startExit(id, axis))
      ..ensureVisualUpdate();
  }

  /// Ends every transition now, removing what the exits held back, so none carries onto a fresh list.
  void settle() {
    if (_transitions.isEmpty) return;

    _transitions.values.map((transition) => transition.leavingItem).nonNulls.forEach(bookRemoval);
    _disposeTransitions();

    notifyListeners();
  }

  @override
  void dispose() {
    _disposeTransitions();

    super.dispose();
  }

  _Transition<T> _start(Object id, Duration duration, {required double value}) {
    final controller = AnimationController(vsync: vsync, duration: duration, value: value)
      ..addStatusListener((status) => _onStatus(id, status));

    return _transitions[id] = _Transition(controller);
  }

  void _animate(_Transition<T> transition, {required bool isEntering}) {
    transition.hasStarted = true;
    unawaited(isEntering ? transition.controller.forward() : transition.controller.reverse());

    notifyListeners();
  }

  void _startExit(Object id, Axis axis) {
    final transition = _transitions[id];
    // Settled, or brought back by an upsert, meanwhile.
    if (transition == null || transition.leavingItem == null) return;

    if ((_rows[id]?._extentAlong(axis) ?? 0) == 0) {
      _finishExit(id);
    } else {
      _animate(transition, isEntering: false);
    }
  }

  void _onStatus(Object id, AnimationStatus status) {
    final transition = _transitions[id];
    if (transition == null) return;

    final isLeaving = transition.leavingItem != null;
    if (status.isDismissed && isLeaving) _finishExit(id);
    if (status.isCompleted && !isLeaving) _finishEntry(id);
  }

  void _finishExit(Object id) {
    final transition = _transitions.remove(id);
    if (transition == null) return;

    transition.controller.dispose();
    final leavingItem = transition.leavingItem;
    if (leavingItem != null) bookRemoval(leavingItem);
    notifyListeners();
  }

  void _finishEntry(Object id) {
    _transitions.remove(id)?.controller.dispose();
    notifyListeners();
  }

  void _disposeTransitions() {
    for (final transition in _transitions.values) {
      transition.controller.dispose();
    }
    _transitions.clear();
  }

  Animation<double>? _animationOf(Object id) {
    final transition = _transitions[id];

    return transition != null && transition.hasStarted ? transition.controller : null;
  }

  bool _isLeaving(Object id) => _transitions[id]?.leavingItem != null;

  /// What a leaving row shows instead of building its item again: the item is already gone from the
  /// consumer's store.
  Widget? _leavingChildOf(Object id) {
    final transition = _transitions[id];
    if (transition == null || transition.leavingItem == null) return null;

    return transition.leavingChild ?? const SizedBox.shrink();
  }
}

/// One row's animation. [leavingItem] is set while the row goes out.
final class _Transition<T extends Object> {
  final AnimationController controller;

  /// False for an exit waiting its frame, so the row isn't wrapped before it moves.
  var hasStarted = false;

  T? leavingItem;
  Widget? leavingChild;

  new(this.controller);
}

class _TransitionRow<T extends Object> extends StatefulWidget {
  final RowTransitionsNotifier<T> rowTransitionsNotifier;
  final Object id;
  final AnimatedSwitcherTransitionBuilder transitionBuilder;
  final WidgetBuilder buildChild;

  const new({
    required this.rowTransitionsNotifier,
    required this.id,
    required this.transitionBuilder,
    required this.buildChild,
  });

  @override
  State<_TransitionRow<T>> createState() => _TransitionRowState<T>();
}

class _TransitionRowState<T extends Object> extends State<_TransitionRow<T>> {
  /// Keeps the item's state while the wrapper comes and goes around it.
  final _childKey = GlobalKey();

  Widget? _lastChild;

  @override
  void initState() {
    super.initState();

    widget.rowTransitionsNotifier._rows[widget.id] = this;
  }

  @override
  void didUpdateWidget(_TransitionRow<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.id == widget.id &&
        identical(oldWidget.rowTransitionsNotifier, widget.rowTransitionsNotifier)) {
      return;
    }
    _unregister(oldWidget);
    widget.rowTransitionsNotifier._rows[widget.id] = this;
  }

  @override
  void dispose() {
    _unregister(widget);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transitionsNotifier = widget.rowTransitionsNotifier;
    final leavingChild = transitionsNotifier._leavingChildOf(widget.id);
    final child = leavingChild ?? widget.buildChild(context);
    if (leavingChild == null) _lastChild = child;
    final keyedChild = KeyedSubtree(key: _childKey, child: child);

    return ListenableBuilder(
      listenable: transitionsNotifier,
      builder: (_, _) {
        final animation = transitionsNotifier._animationOf(widget.id);
        if (animation == null) return keyedChild;

        final isLeaving = transitionsNotifier._isLeaving(widget.id);

        // Nobody taps a row that's going, or hears it read out.
        return IgnorePointer(
          ignoring: isLeaving,
          child: ExcludeSemantics(
            excluding: isLeaving,
            child: widget.transitionBuilder(keyedChild, animation),
          ),
        );
      },
    );
  }

  double _extentAlong(Axis axis) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return 0;

    return switch (axis) {
      .vertical => box.size.height,
      .horizontal => box.size.width,
    };
  }

  void _unregister(_TransitionRow<T> row) {
    final rows = row.rowTransitionsNotifier._rows;
    if (identical(rows[row.id], this)) rows.remove(row.id);
  }
}
