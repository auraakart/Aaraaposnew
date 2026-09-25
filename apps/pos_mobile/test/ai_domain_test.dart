import 'package:aaraapos_pos/ai/ai_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifications are explicit to the user', () {
    expect(
      classificationLabel(InsightClassification.fact),
      'Recorded fact',
    );
    expect(
      classificationLabel(InsightClassification.calculation),
      'Calculated',
    );
    expect(
      classificationLabel(InsightClassification.prediction),
      'Prediction',
    );
    expect(
      classificationLabel(InsightClassification.recommendation),
      'Recommendation',
    );
  });
}
