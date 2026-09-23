// lib/widgets/skeleton_loader.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../themes/color-palette.dart';

class SkeletonLoader extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const SkeletonLoader({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;
    final VivreColors colors = context.colors;
    return Shimmer.fromColors(
      baseColor: colors.surfaceSoft,
      highlightColor: colors.surface,
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.colors.surfaceSoft,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.surfaceSoft,
        shape: BoxShape.circle,
      ),
    );
  }
}

class SkeletonText extends StatelessWidget {
  final int lines;
  final double lineHeight;
  final double spacing;
  final List<double>? widthFactors;

  const SkeletonText({
    super.key,
    this.lines = 1,
    this.lineHeight = 14,
    this.spacing = 8,
    this.widthFactors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(lines, (index) {
        final double factor = widthFactors != null && index < widthFactors!.length
            ? widthFactors![index]
            : (index == lines - 1 ? 0.6 : 1.0);
        return Padding(
          padding: EdgeInsets.only(bottom: index == lines - 1 ? 0 : spacing),
          child: FractionallySizedBox(
            widthFactor: factor,
            alignment: Alignment.centerLeft,
            child: SkeletonBox(height: lineHeight),
          ),
        );
      }),
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      isLoading: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            const SkeletonCircle(size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: SkeletonText(lines: 2, widthFactors: const [0.5, 0.8]),
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final double height;

  const SkeletonCard({super.key, this.height = 96});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      isLoading: true,
      child: Container(
        width: double.infinity,
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SkeletonText(lines: 3, widthFactors: [0.4, 1.0, 0.7]),
      ),
    );
  }
}