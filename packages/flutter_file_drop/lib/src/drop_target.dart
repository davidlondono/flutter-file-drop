import 'dart:async';
import 'dart:collection';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_file_drop_platform_interface/flutter_file_drop_platform_interface.dart';

import 'drop_types.dart';

/// Callback for drag entry and movement over a [DropTarget].
typedef DropPreviewCallback = void Function(DropPreview preview);

/// Callback when the pointer leaves a [DropTarget].
typedef DropLeaveCallback = void Function();

/// Async callback for a completed drop.
typedef DropCallback = Future<void> Function(DropResult result);

/// Headless target for incoming file and text drops.
///
/// This widget wraps app-owned content and adds no visual styling. A nested
/// target receives the whole batch when it accepts at least one item.
class DropTarget extends StatefulWidget {
  /// Creates a target around [child].
  const DropTarget({
    required this.child,
    this.constraints = const DropConstraints.unrestricted(),
    this.onEnter,
    this.onMove,
    this.onLeave,
    this.onDrop,
    super.key,
  });

  /// App-owned content rendered inside this target.
  final Widget child;

  /// Rules applied to each item before routing the completed batch.
  final DropConstraints constraints;

  /// Called when the drag first enters this target.
  final DropPreviewCallback? onEnter;

  /// Called as the pointer moves within this target.
  final DropPreviewCallback? onMove;

  /// Called when the drag leaves this target or completes.
  final DropLeaveCallback? onLeave;

  /// Called with accepted and rejected items in source order.
  ///
  /// File access remains valid until the returned future completes.
  final DropCallback? onDrop;

  @override
  State<DropTarget> createState() => _DropTargetState();
}

class _DropTargetState extends State<DropTarget> {
  int _viewId = 0;
  bool _attachedToRouter = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewId = View.of(context).viewId;
    if (!_attachedToRouter) {
      _DropRouter.instance.attach(this);
      _attachedToRouter = true;
    }
  }

  @override
  void dispose() {
    if (_attachedToRouter) _DropRouter.instance.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _DropTargetRenderWidget(state: this, child: widget.child);
}

class _DropTargetRenderWidget extends SingleChildRenderObjectWidget {
  const _DropTargetRenderWidget({required this.state, required super.child});

  final _DropTargetState state;

  @override
  _RenderDropTarget createRenderObject(BuildContext context) =>
      _RenderDropTarget(state);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDropTarget renderObject,
  ) {
    renderObject.state = state;
  }
}

class _RenderDropTarget extends RenderProxyBox {
  _RenderDropTarget(this.state);

  _DropTargetState state;

  @override
  bool hitTestSelf(Offset position) => true;
}

class _DropRouter {
  _DropRouter._();

  static final _DropRouter instance = _DropRouter._();

  final Set<_DropTargetState> _targets = LinkedHashSet.identity();
  StreamSubscription<PlatformDropEvent>? _subscription;
  _DropTargetState? _hoveredTarget;
  String? _sessionId;

  void attach(_DropTargetState target) {
    _targets.add(target);
    _listen();
  }

  void _listen() {
    if (_subscription != null || _targets.isEmpty) return;
    late final StreamSubscription<PlatformDropEvent> subscription;
    subscription = FlutterFileDropPlatform.instance.events.listen(
      _enqueue,
      onError: (Object error, StackTrace stack) {
        Zone.current.handleUncaughtError(error, stack);
      },
      onDone: () {
        if (identical(_subscription, subscription)) _subscription = null;
        _listen();
      },
    );
    _subscription = subscription;
  }

  void detach(_DropTargetState target) {
    _targets.remove(target);
    if (identical(_hoveredTarget, target)) _hoveredTarget = null;
    if (_targets.isEmpty) {
      unawaited(_subscription?.cancel());
      _subscription = null;
      _sessionId = null;
    }
  }

  void _enqueue(PlatformDropEvent event) {
    unawaited(
      _handleEvent(event).catchError((Object error, StackTrace stack) {
        Zone.current.handleUncaughtError(error, stack);
      }),
    );
  }

  Future<void> _handleEvent(PlatformDropEvent event) async {
    if (event.type == PlatformDropEventType.leave) {
      if (_sessionId == null || _sessionId == event.sessionId) {
        _leaveHoveredTarget();
        _sessionId = null;
      }
      return;
    }
    _sessionId = event.sessionId;
    final position = Offset(event.globalPositionX, event.globalPositionY);
    final targets = _targetsAt(position);
    if (event.type == PlatformDropEventType.drop) {
      try {
        await _deliverDrop(event, position, targets);
      } finally {
        _leaveHoveredTarget();
        _sessionId = null;
      }
      return;
    }
    _updateHover(event, position, targets);
  }

  List<_DropTargetState> _targetsAt(Offset position) {
    if (_targets.isEmpty) return const <_DropTargetState>[];
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      position,
      _targets.last._viewId,
    );
    final hits = <_DropTargetState>[];
    final seen = HashSet<_DropTargetState>.identity();
    for (final entry in result.path) {
      final renderObject = entry.target;
      if (renderObject is _RenderDropTarget &&
          renderObject.state.mounted &&
          seen.add(renderObject.state)) {
        hits.add(renderObject.state);
      }
    }
    return hits;
  }

  void _updateHover(
    PlatformDropEvent event,
    Offset position,
    List<_DropTargetState> targets,
  ) {
    final target = targets.firstOrNull;
    if (!identical(target, _hoveredTarget)) {
      _leaveHoveredTarget();
      _hoveredTarget = target;
      if (target != null) {
        target.widget.onEnter?.call(_preview(event, position, target));
      }
      return;
    }
    if (target != null) {
      target.widget.onMove?.call(_preview(event, position, target));
    }
  }

  void _leaveHoveredTarget() {
    final target = _hoveredTarget;
    _hoveredTarget = null;
    if (target?.mounted == true) target!.widget.onLeave?.call();
  }

  DropPreview _preview(
    PlatformDropEvent event,
    Offset position,
    _DropTargetState target,
  ) => DropPreview(
    globalPosition: position,
    localPosition: _localPosition(target, position),
    items: event.items.map(_toPreview).toList(growable: false),
  );

  DropItemPreview _toPreview(PlatformDropItem item) => DropItemPreview(
    kind: item.type == PlatformDropItemType.file
        ? DropItemKind.file
        : DropItemKind.string,
    name: item.name,
    mimeType: item.mimeType,
    size: item.size,
    lastModified: item.lastModifiedMilliseconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(item.lastModifiedMilliseconds!),
  );

  Offset _localPosition(_DropTargetState target, Offset position) {
    final renderObject = target.context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return position;
    return renderObject.globalToLocal(position);
  }

  Future<void> _deliverDrop(
    PlatformDropEvent event,
    Offset position,
    List<_DropTargetState> targets,
  ) async {
    final platform = FlutterFileDropPlatform.instance;
    final candidates = <({_DropTargetState target, DropResult result})>[];
    try {
      for (final target in targets) {
        candidates.add((
          target: target,
          result: _resultFor(event, position, target),
        ));
      }
      if (candidates.isEmpty) return;
      final selected = candidates.firstWhere(
        (candidate) => candidate.result.hasAcceptedItems,
        orElse: () => candidates.first,
      );
      final callback = selected.target.widget.onDrop;
      if (callback != null && selected.target.mounted) {
        await callback(selected.result);
      }
    } finally {
      for (final candidate in candidates) {
        for (final item in candidate.result.items) {
          final value = item.item;
          if (value is DropFile) value.invalidate();
        }
      }
      if (event.sessionId.isNotEmpty) {
        await platform.releaseSession(event.sessionId);
      }
    }
  }

  DropResult _resultFor(
    PlatformDropEvent event,
    Offset position,
    _DropTargetState target,
  ) {
    var acceptedFiles = 0;
    final items = <DropResultItem>[];
    for (final sourceItem in event.items) {
      final reasons = <DropRejectionReason>[];
      void reject(DropRejectionReason reason) {
        if (!reasons.contains(reason)) reasons.add(reason);
      }

      final isFile = sourceItem.type == PlatformDropItemType.file;
      final kind = isFile ? DropItemKind.file : DropItemKind.string;
      final item = isFile
          ? DropFile.fromPlatform(
              name: sourceItem.name,
              mimeType: sourceItem.mimeType,
              size: sourceItem.size,
              lastModified: sourceItem.lastModifiedMilliseconds == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(
                      sourceItem.lastModifiedMilliseconds!,
                    ),
              path: sourceItem.path,
              sessionId: event.sessionId,
              handle: sourceItem.handle ?? '',
              readChunk: FlutterFileDropPlatform.instance.readFileChunk,
              releaseRead:
                  FlutterFileDropPlatform.instance.releaseFileReadStream,
            )
          : DropString(
              value: sourceItem.value ?? '',
              mimeType: sourceItem.mimeType,
            );
      final constraints = target.widget.constraints;

      if (sourceItem.accessDenied ||
          (isFile && !sourceItem.isDirectory && sourceItem.handle == null) ||
          (!isFile && sourceItem.value == null)) {
        reject(DropRejectionReason.accessFailed);
      }
      if (sourceItem.isDirectory) {
        reject(DropRejectionReason.unsupportedKind);
      }
      if (constraints.allowedKinds != null &&
          !constraints.allowedKinds!.contains(kind)) {
        reject(DropRejectionReason.unsupportedKind);
      }
      if (constraints.allowedMimeTypes != null) {
        final mimeType = sourceItem.mimeType;
        if (mimeType == null || mimeType.isEmpty) {
          reject(DropRejectionReason.metadataUnavailable);
        }
        if (!_matchesMime(mimeType, constraints.allowedMimeTypes!)) {
          reject(DropRejectionReason.mimeTypeNotAllowed);
        }
      }
      if (isFile && constraints.allowedExtensions != null) {
        final name = sourceItem.name;
        if (name == null || name.isEmpty) {
          reject(DropRejectionReason.metadataUnavailable);
        }
        if (!_matchesExtension(name, constraints.allowedExtensions!)) {
          reject(DropRejectionReason.extensionNotAllowed);
        }
      }
      if (isFile && constraints.maxFileSizeBytes != null) {
        final size = sourceItem.size;
        if (size == null || size < 0) {
          reject(DropRejectionReason.fileSizeUnknown);
        } else if (size > constraints.maxFileSizeBytes!) {
          reject(DropRejectionReason.fileTooLarge);
        }
      }
      if (isFile && reasons.isEmpty) {
        final maxFiles = constraints.maxFiles;
        if (maxFiles != null && acceptedFiles >= maxFiles) {
          reject(DropRejectionReason.maxFilesExceeded);
        } else {
          acceptedFiles++;
        }
      }
      items.add(DropResultItem(item: item, reasons: reasons));
    }
    return DropResult(
      globalPosition: position,
      localPosition: _localPosition(target, position),
      items: items,
    );
  }

  bool _matchesMime(String? mimeType, Set<String> allowlist) {
    if (allowlist.isEmpty) return false;
    if (mimeType == null) return false;
    final normalized = mimeType.split(';').first.trim().toLowerCase();
    for (final allowed in allowlist) {
      final pattern = allowed.trim().toLowerCase();
      if (pattern == '*/*' || pattern == normalized) return true;
      if (pattern.endsWith('/*') &&
          normalized.startsWith(pattern.substring(0, pattern.length - 1))) {
        return true;
      }
    }
    return false;
  }

  bool _matchesExtension(String? name, Set<String> allowlist) {
    if (allowlist.isEmpty || name == null) return false;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return false;
    final extension = name.substring(dot + 1).toLowerCase();
    return allowlist.any((value) {
      final normalized = value.toLowerCase();
      return extension ==
          (normalized.startsWith('.') ? normalized.substring(1) : normalized);
    });
  }
}
