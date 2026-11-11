import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the passenger "choose destination on map" crash.
///
/// The home screens put a `DraggableScrollableSheet` in a `Stack` alongside
/// overlays that come and go. Confirming a map pick changes two things in the
/// same frame: it inserts the match-state banner ABOVE the sheet (idle ->
/// searching) and swaps the LAST child's type (map picker -> recenter button).
///
/// `Element.updateChildren` matches unkeyed children positionally — top-down
/// until a mismatch, bottom-up until a mismatch, then it destroys whatever
/// unkeyed children are left in the middle. The tail swap kills the bottom-up
/// scan, so the sheet lands in that middle range and its element is torn down
/// and rebuilt. That is fatal, because the new sheet's `initState` calls
/// `DraggableScrollableController._attach` before the old sheet's `dispose`
/// calls `_detach` — and `_attach` opens with
/// `assert(_attachedController == null)`. With asserts off it is worse but
/// quieter: the old `dispose` runs `_detach(disposeExtent: true)` against the
/// live sheet, leaving the controller permanently detached so dragging,
/// snapping and every `animateTo` silently stop working.
///
/// These tests don't pump the real screens (they need a backend, GPS and
/// network map tiles). They reproduce the exact `Stack` shape instead, which is
/// where the bug actually lives.
void main() {
  /// The passenger/driver Stack shape: an optional overlay above the sheet, and
  /// a tail that swaps widget type. [keyed] selects the fixed or the pre-fix
  /// arrangement.
  Widget harness({
    required DraggableScrollableController controller,
    required bool showBanner,
    required bool picking,
    required bool keyed,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            SizedBox(key: keyed ? const ValueKey('map') : null),
            if (showBanner)
              Positioned(
                key: keyed ? const ValueKey('banner') : null,
                top: 0,
                left: 0,
                right: 0,
                child: const SizedBox(height: 40),
              ),
            DraggableScrollableSheet(
              key: keyed ? const ValueKey('sheet') : null,
              controller: controller,
              initialChildSize: 0.55,
              minChildSize: 0.26,
              maxChildSize: 0.85,
              builder: (_, scrollController) => ListView(
                controller: scrollController,
                children: const [SizedBox(height: 400)],
              ),
            ),
            // The tail: two different widget types, only one present at a time.
            if (!picking)
              Align(
                key: keyed ? const ValueKey('recenter') : null,
                alignment: Alignment.bottomRight,
                child: const SizedBox.square(dimension: 44),
              ),
            if (picking)
              Center(
                key: keyed ? const ValueKey('picker') : null,
                child: const SizedBox.square(dimension: 44),
              ),
          ],
        ),
      ),
    );
  }

  testWidgets(
    'keyed: sheet element survives an insert above it plus a tail type swap',
    (tester) async {
      final controller = DraggableScrollableController();
      addTearDown(controller.dispose);

      // In map-pick mode, no banner yet — matchUiState == idle.
      await tester.pumpWidget(harness(
        controller: controller,
        showBanner: false,
        picking: true,
        keyed: true,
      ));

      final before = tester.state(find.byType(DraggableScrollableSheet));
      expect(controller.isAttached, isTrue);

      // Confirming the pick: banner appears AND the tail swaps, same frame.
      await tester.pumpWidget(harness(
        controller: controller,
        showBanner: true,
        picking: false,
        keyed: true,
      ));

      expect(
        tester.state(find.byType(DraggableScrollableSheet)),
        same(before),
        reason: 'the sheet was rebuilt from scratch — its State, its scroll '
            'position and the destination field inside it were all lost',
      );
      // The real user-visible symptom: a detached controller means the sheet
      // can no longer be dragged, snapped or animated.
      expect(controller.isAttached, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unkeyed: the same transition destroys the sheet and trips _attach',
    (tester) async {
      final controller = DraggableScrollableController();
      addTearDown(controller.dispose);

      // NB: don't try to silence the stack dump this provokes by swapping out
      // FlutterError.onError — the test binding's handler is what records the
      // exception for takeException, so overriding it makes the binding assert
      // '_pendingExceptionDetails != null'. The noise is the cost of asserting
      // on a framework-thrown error.
      await tester.pumpWidget(harness(
        controller: controller,
        showBanner: false,
        picking: true,
        keyed: false,
      ));
      expect(controller.isAttached, isTrue);

      await tester.pumpWidget(harness(
        controller: controller,
        showBanner: true,
        picking: false,
        keyed: false,
      ));

      // Documents why the keys above are load-bearing: without them the
      // replacement sheet attaches to a controller the outgoing sheet has not
      // released yet. If a future Flutter release stops throwing here, re-read
      // the header comment before relaxing anything — the release-mode failure
      // (a silently detached controller) does not depend on this assert.
      expect(
        tester.takeException(),
        isNotNull,
        reason: 'expected DraggableScrollableController._attach to reject a '
            'second concurrent attachment',
      );
    },
  );
}
