import 'package:flutter/material.dart';
import '../../../orchestrator/domain/quiz_orchestrator.dart';

const Color _emerald = Color(0xFF10B981);
const Color _rose = Color(0xFFF43F5E);

class QuizViewer extends StatefulWidget {
  final List<QuizQuestion> questions;

  const QuizViewer({super.key, required this.questions});

  @override
  State<QuizViewer> createState() => _QuizViewerState();
}

class _QuizViewerState extends State<QuizViewer> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isFinished = false;
  
  // Maps question index to the user's selected option index
  final Map<int, int> _selectedAnswers = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onOptionSelected(int qIndex, int oIndex) {
    if (_selectedAnswers.containsKey(qIndex)) return; // Only allow one selection per question
    setState(() {
      _selectedAnswers[qIndex] = oIndex;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutQuart,
      );
    } else if (_selectedAnswers.length == widget.questions.length) {
      setState(() {
        _isFinished = true;
      });
    }
  }

  void _finishQuiz() {
    if (_selectedAnswers.length == widget.questions.length) {
      setState(() {
        _isFinished = true;
      });
    }
  }

  void _restartQuiz() {
    setState(() {
      _currentIndex = 0;
      _isFinished = false;
      _selectedAnswers.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  void _prevQuestion() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.questions.isEmpty) {
      return Center(
        child: Text('No questions available.', style: theme.textTheme.bodyLarge),
      );
    }

    if (_isFinished) {
      return _buildResultsView(theme);
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Knowledge Check',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Question ${_currentIndex + 1} of ${widget.questions.length}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_left_rounded),
                      onPressed: _currentIndex > 0 ? _prevQuestion : null,
                      tooltip: 'Previous',
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_right_rounded),
                      onPressed: _currentIndex < widget.questions.length - 1 ? _nextQuestion : null,
                      tooltip: 'Next',
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
        
        // Progress Bar
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(
            begin: 0,
            end: (_selectedAnswers.length) / widget.questions.length,
          ),
          builder: (context, value, _) => LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            color: theme.colorScheme.primary,
            minHeight: 4,
          ),
        ),

        // Questions PageView
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                 _currentIndex = index;
              });
            },
            itemCount: widget.questions.length,
            itemBuilder: (context, index) {
              final question = widget.questions[index];
              final selectedIndex = _selectedAnswers[index];
              final hasAnswered = selectedIndex != null;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 600),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOut,
                      builder: (context, opacity, _) => Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Text(
                          question.question,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.4,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    ...List.generate(question.options.length, (oIndex) {
                      final option = question.options[oIndex];
                      final isCorrect = oIndex == question.correctIndex;
                      final isSelected = selectedIndex == oIndex;

                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 400 + (oIndex * 150)),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: Opacity(
                              opacity: value.clamp(0.0, 1.0),
                              child: child,
                            ),
                          );
                        },
                        child: _buildOptionCard(
                          context,
                          index: oIndex,
                          option: option,
                          isSelected: isSelected,
                          isCorrect: isCorrect,
                          hasAnswered: hasAnswered,
                          onTap: () => _onOptionSelected(index, oIndex),
                        ),
                      );
                    }),
                    
                    if (hasAnswered && question.explanation.isNotEmpty) ...[
                      const SizedBox(height: 40),
                      _buildExplanationBox(theme, question.explanation),
                      const SizedBox(height: 32),
                      if (index < widget.questions.length - 1)
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: _nextQuestion,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Next Question'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                          ),
                        )
                      else 
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: _finishQuiz,
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Finish Quiz'),
                                SizedBox(width: 8),
                                Icon(Icons.check_circle_outline_rounded, size: 18),
                              ],
                            ),
                          ),
                        )
                    ]
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required int index,
    required String option,
    required bool isSelected,
    required bool isCorrect,
    required bool hasAnswered,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    Color backgroundColor = theme.colorScheme.surfaceContainerLow;
    Color borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);
    Color textColor = theme.colorScheme.onSurface;
    IconData? icon;

    if (hasAnswered) {
      if (isCorrect) {
        backgroundColor = _emerald.withValues(alpha: 0.15);
        borderColor = _emerald.withValues(alpha: 0.6);
        icon = Icons.check_circle_rounded;
      } else if (isSelected) {
        backgroundColor = _rose.withValues(alpha: 0.15);
        borderColor = _rose.withValues(alpha: 0.6);
        icon = Icons.cancel_rounded;
      } else {
        backgroundColor = theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: hasAnswered ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: isSelected || (hasAnswered && isCorrect) ? 2.5 : 1.5),
            boxShadow: isSelected ? [
               BoxShadow(
                color: (hasAnswered && !isCorrect ? _rose : theme.colorScheme.primary).withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ] : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected || (hasAnswered && isCorrect) 
                      ? (hasAnswered && !isCorrect ? _rose : (isCorrect && hasAnswered ? _emerald : theme.colorScheme.primary))
                      : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + index),
                    style: TextStyle(
                      color: isSelected || (hasAnswered && isCorrect) ? Colors.white : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  option,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: hasAnswered ? (isCorrect ? _emerald : (isSelected ? _rose : null)) : null,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 12),
                Icon(icon, color: iconColor(isCorrect, isSelected)),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Color iconColor(bool isCorrect, bool isSelected) {
    if (isCorrect) return _emerald;
    if (isSelected) return _rose;
    return Colors.transparent;
  }

  Widget _buildExplanationBox(ThemeData theme, String explanation) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.auto_awesome_rounded, size: 18, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Text(
                'Deep Insights',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            explanation,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(ThemeData theme) {
    int correctCount = 0;
    widget.questions.asMap().forEach((idx, q) {
      if (_selectedAnswers[idx] == q.correctIndex) {
        correctCount++;
      }
    });

    final percentage = (correctCount / widget.questions.length);
    final isGreat = percentage >= 0.75;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1000),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.elasticOut,
              builder: (context, value, _) => Transform.scale(
                scale: value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: isGreat ? _emerald.withValues(alpha: 0.1) : theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isGreat ? Icons.emoji_events_rounded : Icons.psychology_rounded,
                    size: 64,
                    color: isGreat ? _emerald : theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              isGreat ? 'Mastery Achieved!' : 'Keep Learning!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You scored $correctCount out of ${widget.questions.length}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _restartQuiz,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Restart Quiz'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _isFinished = false;
                      _currentIndex = 0;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_pageController.hasClients) {
                        _pageController.jumpToPage(0);
                      }
                    });
                  },
                  icon: const Icon(Icons.library_books_rounded),
                  label: const Text('Review Answers'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
