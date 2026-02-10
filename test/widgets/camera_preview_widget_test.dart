import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fastvlm_flutter/widgets/camera_preview_widget.dart';

void main() {
  Widget buildTestWidget({
    bool isCameraInitialized = false,
    VoidCallback? onSwitchCamera,
    bool canSwitchCamera = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: CameraPreviewWidget(
            controller: null, // Cannot mock CameraController easily
            isCameraInitialized: isCameraInitialized,
            onSwitchCamera: onSwitchCamera,
            canSwitchCamera: canSwitchCamera,
          ),
        ),
      ),
    );
  }

  group('CameraPreviewWidget', () {
    group('Loading State', () {
      testWidgets('shows loading indicator when not initialized',
          (tester) async {
        await tester.pumpWidget(buildTestWidget(isCameraInitialized: false));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows Initializing Camera text', (tester) async {
        await tester.pumpWidget(buildTestWidget(isCameraInitialized: false));

        expect(find.text('Initializing Camera...'), findsOneWidget);
      });

      testWidgets('has black background during loading', (tester) async {
        await tester.pumpWidget(buildTestWidget(isCameraInitialized: false));

        final container =
            tester.widget<Container>(find.byType(Container).first);
        expect(container.color, Colors.black);
      });
    });

    group('Switch Camera Button (Loading State)', () {
      // Note: When not initialized, no switch button should appear
      // as the camera preview isn't shown
      testWidgets('hides switch button when not initialized', (tester) async {
        await tester.pumpWidget(buildTestWidget(
          isCameraInitialized: false,
          canSwitchCamera: true,
          onSwitchCamera: () {},
        ));

        expect(find.byIcon(Icons.cameraswitch), findsNothing);
      });
    });
  });
}
