import 'package:material_ui/material_ui.dart';
import '../../core/design_system/mechi_ui.dart';
import 'domain.dart';

List<Job> reviewsFor(List<Job> jobs, int mechanicId) => jobs
    .where(
      (job) =>
          job.mechanicId == mechanicId &&
          job.status == JobStatus.reviewed &&
          job.rating != null &&
          job.rating! >= 1 &&
          job.rating! <= 5,
    )
    .toList();

double? reviewAverage(List<Job> reviews) => reviews.isEmpty
    ? null
    : reviews.fold(0, (sum, job) => sum + job.rating!) / reviews.length;

class MechanicReviews extends StatelessWidget {
  const MechanicReviews({
    super.key,
    required this.specialty,
    required this.records,
    required this.now,
  });

  final String specialty;
  final List<Job> records;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    final counts = List<int>.filled(5, 0);
    for (final entry in records) {
      counts[entry.rating! - 1]++;
    }
    final average = reviewAverage(records);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Specialisations', style: type.titleMedium),
        const SizedBox(height: 8),
        ChipLabel(specialty, background: Mechi.canvas, ink: Mechi.ink),
        const SizedBox(height: 20),
        Text('Reviews', style: type.titleMedium),
        const SizedBox(height: 10),
        Panel(
          color: Mechi.canvas,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      average?.toStringAsFixed(1) ?? '—',
                      style: type.headlineMedium,
                    ),
                    ReviewStars(average?.round() ?? 0),
                    Text(
                      '${records.length} ${records.length == 1 ? 'review' : 'reviews'}',
                      style: type.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    for (var rating = 5; rating >= 1; rating--)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Text('$rating', style: type.bodySmall),
                            const SizedBox(width: 6),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: records.isEmpty
                                    ? 0
                                    : counts[rating - 1] / records.length,
                                minHeight: 5,
                                color: Mechi.ink,
                                backgroundColor: Mechi.line,
                                borderRadius: BorderRadius.circular(8),
                                semanticsLabel:
                                    '$rating stars, ${counts[rating - 1]} reviews',
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (records.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('No reviews yet.'),
          ),
        for (final record in records)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Panel(
              color: Mechi.canvas,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Mechi.pale,
                        child: Text(
                          'MC',
                          style: TextStyle(color: Mechi.blue, fontSize: 10),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mechi customer', style: type.labelLarge),
                            Text(
                              _relativeDate(record.paidAt ?? record.date),
                              style: type.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      ReviewStars(record.rating!),
                    ],
                  ),
                  if (record.review case final text? when text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(text),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _relativeDate(DateTime date) {
    final days = now.difference(date).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '$days days ago';
  }
}

class ReviewStars extends StatelessWidget {
  const ReviewStars(this.rating, {super.key});
  final int rating;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$rating out of 5 stars',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var star = 1; star <= 5; star++)
            Icon(
              star <= rating ? Icons.star_rounded : Icons.star_border_rounded,
              size: 14,
              color: Mechi.star,
            ),
        ],
      ),
    ),
  );
}
