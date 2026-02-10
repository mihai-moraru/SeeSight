// Copyright (c) 2025-2026 Mihai Moraru. MIT License. See LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/vlm_service.dart';
import 'glass_container.dart';
import 'status_indicator.dart';

/// Modern draggable bottom sheet for prompt and response
class ResponseBottomSheet extends StatefulWidget {
  final String prompt;
  final String promptSuffix;
  final String response;
  final bool isLoading;
  final bool isModelLoaded;
  final void Function(String prompt, String suffix) onPromptChanged;
  final List<QuickPrompt> quickPrompts;
  final EvaluationState evaluationState;
  final Widget? floatingWidget;

  const ResponseBottomSheet({
    super.key,
    required this.prompt,
    required this.promptSuffix,
    required this.response,
    required this.isLoading,
    required this.isModelLoaded,
    required this.onPromptChanged,
    required this.evaluationState,
    this.quickPrompts = const [],
    this.floatingWidget,
  });

  @override
  State<ResponseBottomSheet> createState() => _ResponseBottomSheetState();
}

class _ResponseBottomSheetState extends State<ResponseBottomSheet> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _isExpanded = false;

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  void _toggleSheet() {
    final targetSize = _isExpanded ? 0.20 : 0.5;
    _sheetController.animateTo(
      targetSize,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
    setState(() => _isExpanded = !_isExpanded);
  }

  void _showEditDialog(BuildContext context) {
    final promptController = TextEditingController(text: widget.prompt);
    final suffixController = TextEditingController(text: widget.promptSuffix);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: GlassContainer(
          blur: 20,
          opacity: 0.9,
          tintColor: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Prompt',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Main Prompt',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: promptController,
                maxLines: 3,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'Enter your prompt...',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Output Instructions',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: suffixController,
                maxLines: 2,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'Enter output instructions...',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    widget.onPromptChanged(
                      promptController.text,
                      suffixController.text,
                    );
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.20,
      minChildSize: 0.15,
      maxChildSize: 0.75,
      snap: true,
      snapSizes: const [0.20, 0.40, 0.75],
      builder: (context, scrollController) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            setState(() {
              _isExpanded = notification.extent > 0.25;
            });
            return true;
          },
          child: Column(
            children: [
              // Floating widget (e.g. capture button) above the sheet
              if (widget.floatingWidget != null) ...[
                widget.floatingWidget!,
                const SizedBox(height: 10),
              ],
              // Status indicator pill that travels with the sheet
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: StatusIndicator(state: widget.evaluationState),
              ),
              // Sheet content
              Expanded(
                child: GlassContainer(
                  blur: 20,
                  opacity: 0.15,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Column(
                    children: [
                      // Drag handle
                      GestureDetector(
                        onTap: _toggleSheet,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Content
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            // Prompt preview row
                            _buildPromptRow(context),
                            const SizedBox(height: 16),
                            // Quick prompts
                            if (widget.quickPrompts.isNotEmpty) ...[
                              _buildQuickPrompts(),
                              const SizedBox(height: 16),
                            ],
                            // Response
                            _buildResponse(context),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPromptRow(BuildContext context) {
    return GestureDetector(
      onTap: () => _showEditDialog(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.prompt,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  maxLines: _isExpanded ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.promptSuffix.isNotEmpty)
                  Text(
                    widget.promptSuffix,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.edit_rounded,
              size: 18,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.quickPrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = widget.quickPrompts[index];
          return GestureDetector(
            onTap: () => widget.onPromptChanged(prompt.prompt, prompt.suffix),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                prompt.label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResponse(BuildContext context) {
    if (!widget.isModelLoaded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Loading model...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.isLoading && widget.response.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    if (widget.response.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'Point your camera at something\nto get started',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    // Render markdown response
    return MarkdownBody(
      data: widget.response,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.5,
        ),
        h1: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        h2: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        code: TextStyle(
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          color: Colors.white,
          fontSize: 14,
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        listBullet: const TextStyle(color: Colors.white),
        strong: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        em: const TextStyle(
          color: Colors.white,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class QuickPrompt {
  final String label;
  final String prompt;
  final String suffix;

  const QuickPrompt({
    required this.label,
    required this.prompt,
    this.suffix = '',
  });
}
