import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Existing test
  testWidgets('DevicePreview default constructor renders widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      DevicePreview(
        builder:
            (context) => const SizedBox(), // Using SizedBox for a minimal app
      ),
    );
    // No need to pumpAndSettle if we are not waiting for state changes or complex UI.
    // We are primarily testing the properties of the DevicePreview widget itself.
    expect(find.byType(DevicePreview), findsOneWidget);
  });

  group('DevicePreview.builder factory constructor', () {
    testWidgets('creates with toolbar hidden and elements off by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        DevicePreview.frameOnly(builder: (context) => const SizedBox()),
      );

      final devicePreview = tester.widget<DevicePreview>(
        find.byType(DevicePreview),
      );

      expect(
        devicePreview.isToolbarVisible,
        isFalse,
        reason: 'isToolbarVisible should be false for builder factory',
      );
      expect(
        devicePreview.hideAppBar,
        isTrue,
        reason: 'hideAppBar should be true for builder factory',
      );
      expect(
        devicePreview.hideBottomBar,
        isTrue,
        reason: 'hideBottomBar should be true for builder factory',
      );
      expect(
        devicePreview.hideBoxAroundDevice,
        isTrue,
        reason: 'hideBoxAroundDevice should be true for builder factory',
      );
    });

    testWidgets('allows overriding enabled and other base properties', (
      tester,
    ) async {
      await tester.pumpWidget(
        DevicePreview.frameOnly(
          enabled: false, // Example of a base property
          builder: (context) => const SizedBox(),
        ),
      );

      final devicePreview = tester.widget<DevicePreview>(
        find.byType(DevicePreview),
      );

      expect(devicePreview.enabled, isFalse);
      // Default builder values should still hold
      expect(devicePreview.isToolbarVisible, isFalse);
      expect(devicePreview.hideAppBar, isTrue);
    });
  });

  group(
    'DevicePreview default constructor (backward compatibility and new parameters)',
    () {
      testWidgets(
        'has correct default values for visibility and new hide parameters',
        (tester) async {
          await tester.pumpWidget(
            DevicePreview(builder: (context) => const SizedBox()),
          );

          final devicePreview = tester.widget<DevicePreview>(
            find.byType(DevicePreview),
          );

          expect(
            devicePreview.isToolbarVisible,
            isTrue,
            reason: 'isToolbarVisible should default to true',
          );
          expect(
            devicePreview.hideAppBar,
            isFalse,
            reason: 'hideAppBar should default to false',
          );
          expect(
            devicePreview.hideBottomBar,
            isFalse,
            reason: 'hideBottomBar should default to false',
          );
          expect(
            devicePreview.hideBoxAroundDevice,
            isFalse,
            reason: 'hideBoxAroundDevice should default to false',
          );
        },
      );

      testWidgets('allows overriding new hide parameters individually', (
        tester,
      ) async {
        await tester.pumpWidget(
          DevicePreview(
            builder: (context) => const SizedBox(),
            hideAppBar: true,
            hideBottomBar: false, // Explicitly false
            hideBoxAroundDevice: true,
          ),
        );

        final devicePreview = tester.widget<DevicePreview>(
          find.byType(DevicePreview),
        );

        expect(
          devicePreview.isToolbarVisible,
          isTrue,
          reason: 'isToolbarVisible should still default to true',
        );
        expect(
          devicePreview.hideAppBar,
          isTrue,
          reason: 'hideAppBar should be overridable to true',
        );
        expect(
          devicePreview.hideBottomBar,
          isFalse,
          reason: 'hideBottomBar should be overridable to false',
        );
        expect(
          devicePreview.hideBoxAroundDevice,
          isTrue,
          reason: 'hideBoxAroundDevice should be overridable to true',
        );
      });

      testWidgets(
        'allows overriding isToolbarVisible along with new hide parameters',
        (tester) async {
          await tester.pumpWidget(
            DevicePreview(
              builder: (context) => const SizedBox(),
              isToolbarVisible: false,
              hideAppBar:
                  true, // This would be somewhat redundant if toolbar is not visible, but testing prop assignment
              hideBottomBar: true,
              hideBoxAroundDevice: true,
            ),
          );

          final devicePreview = tester.widget<DevicePreview>(
            find.byType(DevicePreview),
          );

          expect(devicePreview.isToolbarVisible, isFalse);
          expect(devicePreview.hideAppBar, isTrue);
          expect(devicePreview.hideBottomBar, isTrue);
          expect(devicePreview.hideBoxAroundDevice, isTrue);
        },
      );
    },
  );
}
