import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fastvlm_flutter/services/app_state.dart';
import 'package:fastvlm_flutter/widgets/error_dialog.dart';

void main() {
  Widget buildTestWidget({required AppError error}) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ErrorDialog.show(context, error),
              child: const Text('Show Error'),
            ),
          ),
        ),
      ),
    );
  }

  group('ErrorDialog', () {
    testWidgets('shows error title', (tester) async {
      const error = AppError(
        source: ErrorSource.camera,
        title: 'Test Error Title',
        message: 'Test error message',
        canRetry: false,
      );

      await tester.pumpWidget(buildTestWidget(error: error));
      await tester.tap(find.text('Show Error'));
      await tester.pumpAndSettle();

      expect(find.text('Test Error Title'), findsOneWidget);
    });

    testWidgets('shows error message', (tester) async {
      const error = AppError(
        source: ErrorSource.vlm,
        title: 'Title',
        message: 'Detailed error message',
        canRetry: false,
      );

      await tester.pumpWidget(buildTestWidget(error: error));
      await tester.tap(find.text('Show Error'));
      await tester.pumpAndSettle();

      expect(find.text('Detailed error message'), findsOneWidget);
    });

    testWidgets('shows dismiss button', (tester) async {
      const error = AppError(
        source: ErrorSource.camera,
        title: 'Title',
        message: 'Message',
        canRetry: false,
      );

      await tester.pumpWidget(buildTestWidget(error: error));
      await tester.tap(find.text('Show Error'));
      await tester.pumpAndSettle();

      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('shows retry button when canRetry is true', (tester) async {
      const error = AppError(
        source: ErrorSource.camera,
        title: 'Title',
        message: 'Message',
        canRetry: true,
      );

      await tester.pumpWidget(buildTestWidget(error: error));
      await tester.tap(find.text('Show Error'));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('hides retry button when canRetry is false', (tester) async {
      const error = AppError(
        source: ErrorSource.vlm,
        title: 'Title',
        message: 'Message',
        canRetry: false,
      );

      await tester.pumpWidget(buildTestWidget(error: error));
      await tester.tap(find.text('Show Error'));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('dismiss button closes dialog', (tester) async {
      const error = AppError(
        source: ErrorSource.camera,
        title: 'Title',
        message: 'Message',
        canRetry: false,
      );

      await tester.pumpWidget(buildTestWidget(error: error));
      await tester.tap(find.text('Show Error'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(find.text('Title'), findsNothing);
    });

    testWidgets('shows camera icon for camera errors', (tester) async {
      const error = AppError(
        source: ErrorSource.camera,
        title: 'Camera Error',
        message: 'Message',
        canRetry: false,
      );

      await tester.pumpWidget(buildTestWidget(error: error));
      await tester.tap(find.text('Show Error'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    });

    testWidgets('shows memory icon for VLM errors', (tester) async {
      const error = AppError(
        source: ErrorSource.vlm,
        title: 'VLM Error',
        message: 'Message',
        canRetry: false,
      );

      await tester.pumpWidget(buildTestWidget(error: error));
      await tester.tap(find.text('Show Error'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.memory_outlined), findsOneWidget);
    });
  });

  group('ErrorBanner', () {
    testWidgets('shows error title and message', (tester) async {
      const error = AppError(
        source: ErrorSource.camera,
        title: 'Banner Title',
        message: 'Banner message',
        canRetry: false,
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ErrorBanner(error: error),
            ),
          ),
        ),
      );

      expect(find.text('Banner Title'), findsOneWidget);
      expect(find.text('Banner message'), findsOneWidget);
    });

    testWidgets('shows dismiss button', (tester) async {
      const error = AppError(
        source: ErrorSource.camera,
        title: 'Title',
        message: 'Message',
        canRetry: false,
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ErrorBanner(error: error),
            ),
          ),
        ),
      );

      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('shows retry button when canRetry is true', (tester) async {
      const error = AppError(
        source: ErrorSource.vlm,
        title: 'Title',
        message: 'Message',
        canRetry: true,
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ErrorBanner(error: error),
            ),
          ),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
