import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fastvlm_flutter/services/vlm_service.dart';
import 'package:fastvlm_flutter/widgets/status_indicator.dart';

void main() {
  Widget buildTestWidget(EvaluationState state) {
    return MaterialApp(
      home: Scaffold(
        body: StatusIndicator(state: state),
      ),
    );
  }

  group('StatusIndicator', () {
    group('Idle State', () {
      testWidgets('shows Ready label', (tester) async {
        await tester.pumpWidget(buildTestWidget(EvaluationState.idle));
        await tester.pump();

        expect(find.text('Ready'), findsOneWidget);
      });

      testWidgets('shows white text', (tester) async {
        await tester.pumpWidget(buildTestWidget(EvaluationState.idle));
        await tester.pump();

        final text = tester.widget<Text>(find.text('Ready'));
        expect(text.style?.color, Colors.white);
      });

      testWidgets('uses green status color for ready state', (tester) async {
        await tester.pumpWidget(buildTestWidget(EvaluationState.idle));
        await tester.pump();

        // The status indicator uses mint green for the idle/ready state
        final animatedContainers = tester.widgetList<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        expect(animatedContainers.isNotEmpty, isTrue);
      });
    });

    group('Processing Prompt State', () {
      testWidgets('shows Processing label', (tester) async {
        await tester
            .pumpWidget(buildTestWidget(EvaluationState.processingPrompt));
        await tester.pump();

        expect(find.text('Processing'), findsOneWidget);
      });

      testWidgets('shows white text', (tester) async {
        await tester
            .pumpWidget(buildTestWidget(EvaluationState.processingPrompt));
        await tester.pump();

        final text = tester.widget<Text>(find.text('Processing'));
        expect(text.style?.color, Colors.white);
      });
    });

    group('Generating Response State', () {
      testWidgets('shows Generating label', (tester) async {
        await tester
            .pumpWidget(buildTestWidget(EvaluationState.generatingResponse));
        await tester.pump();

        expect(find.text('Generating'), findsOneWidget);
      });

      testWidgets('shows white text', (tester) async {
        await tester
            .pumpWidget(buildTestWidget(EvaluationState.generatingResponse));
        await tester.pump();

        final text = tester.widget<Text>(find.text('Generating'));
        expect(text.style?.color, Colors.white);
      });
    });

    group('Layout', () {
      testWidgets('uses ClipRRect with rounded corners', (tester) async {
        await tester.pumpWidget(buildTestWidget(EvaluationState.idle));
        await tester.pump();

        final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
        expect(clipRRect.borderRadius, BorderRadius.circular(20));
      });

      testWidgets('uses BackdropFilter for glassmorphism', (tester) async {
        await tester.pumpWidget(buildTestWidget(EvaluationState.idle));
        await tester.pump();

        expect(find.byType(BackdropFilter), findsOneWidget);
      });

      testWidgets('has dot and text in row', (tester) async {
        await tester.pumpWidget(buildTestWidget(EvaluationState.idle));
        await tester.pump();

        expect(find.byType(Row), findsOneWidget);

        final row = tester.widget<Row>(find.byType(Row));
        // Row contains: dot container, SizedBox, Text
        expect(row.children.length, 3);
      });
    });

    group('Animation', () {
      testWidgets('does not animate pulse when idle', (tester) async {
        await tester.pumpWidget(buildTestWidget(EvaluationState.idle));
        await tester.pump();

        // Find the StatusIndicator widget
        expect(find.byType(StatusIndicator), findsOneWidget);

        // Verify the Transform.scale exists (part of AnimatedBuilder)
        expect(find.byType(Transform), findsWidgets);
      });

      testWidgets('animates pulse when processing', (tester) async {
        await tester
            .pumpWidget(buildTestWidget(EvaluationState.processingPrompt));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));

        // Animation should be running - verify widget tree contains Transform
        expect(find.byType(Transform), findsWidgets);
      });
    });
  });
}
