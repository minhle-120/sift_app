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
    _pageController = PageController(viewportFraction: 0.85);
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
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Card ${_currentIndex + 1} of ${widget.cards.length}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    // Previous Button
                    _buildNavButton(
                      icon: Icons.chevron_left_rounded,
                      onPressed: _currentIndex > 0 ? _previousPage : null,
                    ),
                    
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
                                value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
                              }
                              return Center(
                                child: SizedBox(
                                  height: Curves.easeOut.transform(value) * 450,
                                  width: Curves.easeOut.transform(value) * 350,
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

                    // Next Button
                    _buildNavButton(
                      icon: Icons.chevron_right_rounded,
                      onPressed: _currentIndex < widget.cards.length - 1 ? _nextPage : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({required IconData icon, VoidCallback? onPressed}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: IconButton.filledTonal(
        icon: Icon(icon),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(16),
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
          const Spacer(),
          Center(
            child: Text(
              content,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: isBack ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          const Spacer(),
          if (isBack && explanation != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                explanation,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
