import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../orchestrator/domain/flashcard_orchestrator.dart';
import 'dart:math';

class FlashcardViewer extends StatefulWidget {
  final List<Flashcard> cards;

  const FlashcardViewer({super.key, required this.cards});

  @override
  State<FlashcardViewer> createState() => _FlashcardViewerState();
}

class _FlashcardViewerState extends State<FlashcardViewer> {
  late PageController _pageController;
  int _currentIndex = 0;
  final Map<int, bool> _flipped = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleFlip(int index) {
    setState(() {
      _flipped[index] = !(_flipped[index] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return const Center(child: Text('No flashcards in this deck.'));
    }

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const ScrollIntent(direction: AxisDirection.left),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const ScrollIntent(direction: AxisDirection.right),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ScrollIntent: CallbackAction<ScrollIntent>(
            onInvoke: (intent) {
              if (intent.direction == AxisDirection.left) {
                _previousPage();
              } else {
                _nextPage();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.cards.length,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double value = 1.0;
                        if (_pageController.position.haveDimensions) {
                          value = _pageController.page! - index;
                          value = (1 - (value.abs() * 0.15)).clamp(0.0, 1.0);
                        }
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
                            child: child,
                          ),
                        );
                      },
                      child: _FlashcardItem(
                        card: widget.cards[index],
                        isFlipped: _flipped[index] ?? false,
                        onTap: () => _toggleFlip(index),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Navigation Bar
              Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          onPressed: _currentIndex > 0 ? _previousPage : null,
                          tooltip: 'Previous Card',
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_currentIndex + 1} / ${widget.cards.length}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Text(
                              'SWIPE OR TAP',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                letterSpacing: 1.2,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
                          onPressed: _currentIndex < widget.cards.length - 1 ? _nextPage : null,
                          tooltip: 'Next Card',
                        ),
                      ],
                    ),
                  );
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}

class ScrollIntent extends Intent {
  final AxisDirection direction;
  const ScrollIntent({required this.direction});
}

class _FlashcardItem extends StatelessWidget {
  final Flashcard card;
  final bool isFlipped;
  final VoidCallback onTap;

  const _FlashcardItem({
    required this.card,
    required this.isFlipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        tween: Tween<double>(begin: 0, end: isFlipped ? 180 : 0),
        builder: (context, double angle, child) {
          final isBack = angle >= 90;
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(angle * pi / 180),
            alignment: Alignment.center,
            child: isBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _buildCardSide(
                      context,
                      title: 'ANSWER',
                      content: card.answer,
                      explanation: card.explanation,
                      isBack: true,
                    ),
                  )
                : _buildCardSide(
                    context,
                    title: 'QUESTION',
                    content: card.question,
                    isBack: false,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCardSide(
    BuildContext context, {
    required String title,
    required String content,
    String? explanation,
    required bool isBack,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isBack ? colorScheme.primaryContainer : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isBack 
              ? colorScheme.primary.withValues(alpha: 0.2) 
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 3),
          Center(
            child: Text(
              content,
              textAlign: TextAlign.center,
              style: (content.length > 100 ? theme.textTheme.titleMedium : theme.textTheme.headlineSmall)?.copyWith(
                color: isBack ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.4,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const Spacer(flex: 4),
          if (isBack && explanation != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.onPrimaryContainer.withValues(alpha: 0.1)),
              ),
              child: Text(
                explanation,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Center(
             child: Row(
               mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isBack ? Icons.flip_to_front_rounded : Icons.flip_to_back_rounded, 
                    size: 14, 
                    color: (isBack ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant).withValues(alpha: 0.4)
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isBack ? 'TAP TO SEE QUESTION' : 'TAP TO REVEAL ANSWER',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: (isBack ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant).withValues(alpha: 0.4),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
             ),
          ),
        ],
      ),
    );
  }
}
