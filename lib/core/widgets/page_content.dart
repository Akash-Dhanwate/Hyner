import 'package:flutter/material.dart';

class PageContent extends StatelessWidget {
  const PageContent({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
              sliver: SliverList(delegate: SliverChildListDelegate(children)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A vertically scrolling page whose body is composed from lazy slivers.
/// Use this for registers that may grow so Flutter only builds visible rows.
class SliverPageContent extends StatelessWidget {
  const SliverPageContent({
    super.key,
    required this.header,
    required this.slivers,
    this.onRefresh,
  });

  final Widget header;
  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scrollView = CustomScrollView(
      physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          sliver: SliverToBoxAdapter(child: header),
        ),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 36)),
      ],
    );
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: onRefresh == null
              ? scrollView
              : RefreshIndicator(onRefresh: onRefresh!, child: scrollView),
        ),
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      letterSpacing: 1.6,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class InlineNotice extends StatelessWidget {
  const InlineNotice(this.message, {super.key, this.isError = false});
  final String message;
  final bool isError;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isError
              ? scheme.errorContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              size: 20,
              color: isError
                  ? scheme.onErrorContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError
                      ? scheme.onErrorContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
