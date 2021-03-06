part of async;

abstract class ReplayStream<T> implements Stream<T> {
  factory ReplayStream(final Stream<T> stream) =>
      new _ReplayStream(checkNotNull(stream));

  Iterable<T> get values;

  Stream<T> replay();

  void disableReplay();
}

class _ReplayStream<T> extends Stream<T> implements ReplayStream<T> {
  final Stream<T> _stream;
  final MutableSequence<Try<T>> _events = new GrowableSequence();

  bool _streamDone = false;
  Option<StreamSubscription> _subscription = Option.NONE;
  Option<StreamController> _replayController = Option.NONE;
  Option<StreamController> _streamController = Option.NONE;
  bool _replayDisabled = false;

  _ReplayStream(this._stream);

  Iterable<T> get values =>
      _events
        .where((final Try<T> event) =>
            event.then(
              (final T value) => true,
              onError: (_) => false).value)
        .map((final Try<T> event) => event.value);

  void _addEvent(final Try<T> event) {
    // Only add events when we are not in replay mode;
    if (!_replayDisabled) {
      _events.add(event);
    }

    event.then(
        (final T data) {
          _streamController.map((final StreamController controller) => controller.add(data));
          _replayController.map((final StreamController controller) => controller.add(data));
        }, onError: (e, [final StackTrace st]) {
          _streamController.map((final StreamController controller) => controller.addError(e,st));
          _replayController.map((final StreamController controller) => controller.addError(e,st));
        });
  }

  StreamSubscription _subscribe() =>
      _subscription.orCompute(() {
        final StreamSubscription subscription = _stream.listen(
            (final T data) => _addEvent(new Try.success(data)),
            onError: (final error, [final StackTrace stackTrace]) => _addEvent(new Try.failure(error, stackTrace)),
            onDone: () {
              _streamDone = true;
              _streamController.map((final StreamController controller) => controller.close());
              _replayController.map((final StreamController controller) => controller.close());
            });
        this._subscription = new Option(subscription);
        return subscription;
      });

  void disableReplay() {
    checkState(_replayController.isEmpty);
    _replayDisabled = true;
    _events.clear();
  }

  StreamSubscription<T> listen(void onData(T event), {Function onError, void onDone(), bool cancelOnError}) {
    checkState(_subscription.isEmpty);

    final StreamController controller = new StreamController(
        onListen: () {
          _subscribe();
        }, onPause: () => _subscribe().pause(),
        onResume: () => _subscribe().resume(),
        onCancel: () {/* do nothing */},
        sync: false);

    this._streamController = new Option(controller);

    return controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  Stream<T> replay() =>
      _replayController.orCompute(() {
        checkState(!this._replayDisabled);
        if (_streamController.isNotEmpty) {
          _streamController.value.close();
          this._streamController = Option.NONE;
        }

        final StreamController controller = new StreamController(
            onListen: () {
              _subscribe().resume();
            }, onPause: () => _subscribe().pause(),
            onResume: () => _subscribe().resume(),
            onCancel: () => _subscribe().cancel(),
            sync: false);

        this._replayController = new Option(controller);
        _events.forEach((final Try<T> event) =>
            event.then(
                (final T value) => controller.add(value),
                onError: (final e, final StackTrace st) => controller.addError(e, st)));

        _events.clear();

        if (_streamDone) {
          controller.close();
        }

        return controller;
      }).stream;
}