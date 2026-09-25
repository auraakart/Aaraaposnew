enum InsightClassification { fact, calculation, prediction, recommendation }

class InsightEvidence {
  const InsightEvidence({
    required this.sourceType,
    this.sourceId,
    this.metric,
    this.value,
    this.window,
  });

  final String sourceType;
  final String? sourceId;
  final String? metric;
  final Object? value;
  final String? window;
}

class LocalBusinessInsight {
  const LocalBusinessInsight({
    required this.id,
    required this.type,
    required this.classification,
    required this.title,
    required this.message,
    required this.evidence,
    required this.generatedAt,
  });

  final String id;
  final String type;
  final InsightClassification classification;
  final String title;
  final String message;
  final List<InsightEvidence> evidence;
  final DateTime generatedAt;
}

class AssistantAnswer {
  const AssistantAnswer({
    required this.question,
    required this.classification,
    required this.answer,
    required this.evidence,
  });

  final String question;
  final InsightClassification classification;
  final String answer;
  final List<InsightEvidence> evidence;
}

String classificationLabel(InsightClassification value) => switch (value) {
      InsightClassification.fact => 'Recorded fact',
      InsightClassification.calculation => 'Calculated',
      InsightClassification.prediction => 'Prediction',
      InsightClassification.recommendation => 'Recommendation',
    };
