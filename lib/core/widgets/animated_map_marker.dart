import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Smoothly interpolates a marker position between successive
/// `target` values so the driver dot on a mini-map glides instead of
/// snapping between the 15-second WebSocket location pings.
///
/// Use it as a wrapper around the MarkerLayer (or any subtree that
/// renders the marker at a given LatLng): pass the desired
/// [target] and a [builder] that returns the rendered subtree given
/// the *currently interpolated* LatLng.
///
/// Whenever [target] changes, the widget restarts the animation from
/// the position it's currently interpolated to (not from the previous
/// raw target) — so a fast follow-up update doesn't make the marker
/// jump backwards mid-glide.
class AnimatedMarkerPosition extends StatefulWidget {
  final LatLng target;
  final Duration duration;
  final Curve curve;
  final Widget Function(BuildContext context, LatLng position) builder;

  const AnimatedMarkerPosition({
    super.key,
    required this.target,
    required this.builder,
    this.duration = const Duration(milliseconds: 1500),
    this.curve = Curves.easeInOut,
  });

  @override
  State<AnimatedMarkerPosition> createState() =>
      _AnimatedMarkerPositionState();
}

class _AnimatedMarkerPositionState extends State<AnimatedMarkerPosition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late LatLng _from;
  late LatLng _to;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..value = 1.0;
    _from = widget.target;
    _to = widget.target;
  }

  @override
  void didUpdateWidget(covariant AnimatedMarkerPosition old) {
    super.didUpdateWidget(old);
    if (widget.duration != old.duration) {
      _ctrl.duration = widget.duration;
    }
    if (widget.target != old.target) {
      // Capture the current interpolated position as the new starting
      // point so an update mid-animation continues smoothly instead of
      // snapping backward to the previous raw target.
      _from = _currentInterpolated();
      _to = widget.target;
      _ctrl
        ..stop()
        ..forward(from: 0);
    }
  }

  LatLng _currentInterpolated() {
    final t = widget.curve.transform(_ctrl.value);
    return LatLng(
      _from.latitude + (_to.latitude - _from.latitude) * t,
      _from.longitude + (_to.longitude - _from.longitude) * t,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) => widget.builder(ctx, _currentInterpolated()),
    );
  }
}
