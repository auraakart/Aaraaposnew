import 'package:flutter/material.dart';

import '../sell/local_pos_database.dart';
import 'ai_domain.dart';

class BusinessAssistantScreen extends StatefulWidget {
  const BusinessAssistantScreen({required this.database, super.key});

  final LocalPosDatabase database;

  @override
  State<BusinessAssistantScreen> createState() =>
      _BusinessAssistantScreenState();
}

class _BusinessAssistantScreenState extends State<BusinessAssistantScreen> {
  final controller = TextEditingController();
  AssistantAnswer? answer;
  List<LocalBusinessInsight> insights = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadInsights();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> loadInsights() async {
    final next = await widget.database.generateBusinessInsights();
    if (!mounted) return;
    setState(() {
      insights = next;
      loading = false;
    });
  }

  Future<void> ask([String? value]) async {
    final question = (value ?? controller.text).trim();
    if (question.isEmpty) return;
    setState(() => loading = true);
    final result = await widget.database.assistantAnswer(question);
    if (!mounted) return;
    setState(() {
      controller.text = question;
      answer = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Assistant')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Answers use recorded AaraaPOS data. Recommendations show the evidence behind them.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: ask,
              decoration: InputDecoration(
                hintText: 'Ask about sales, stock, credit or expenses',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Ask',
                  onPressed: ask,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final question in const [
                  'How much did I sell today?',
                  'Show low stock',
                  'How much do customers owe?',
                  'What should I order?',
                  'What is the latest cash difference?',
                ])
                  ActionChip(
                    label: Text(question),
                    onPressed: () => ask(question),
                  ),
              ],
            ),
            if (loading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (!loading && answer != null) ...[
              const SizedBox(height: 20),
              _AnswerCard(answer: answer!),
            ],
            const SizedBox(height: 24),
            Text(
              'Suggested actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (!loading && insights.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('No additional suggestions right now'),
                  subtitle: Text(
                    'Suggestions appear when recorded data supports them.',
                  ),
                ),
              ),
            for (final insight in insights)
              _InsightCard(insight: insight),
          ],
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer});

  final AssistantAnswer answer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              classificationLabel(answer.classification),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(
              answer.answer,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Why this answer?'),
              children: [
                for (final evidence in answer.evidence)
                  _EvidenceTile(evidence: evidence),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final LocalBusinessInsight insight;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: Icon(_classificationIcon(insight.classification)),
        title: Text(insight.title),
        subtitle: Text(
          '${classificationLabel(insight.classification)} • ${insight.message}',
        ),
        children: [
          for (final evidence in insight.evidence)
            _EvidenceTile(evidence: evidence),
        ],
      ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.evidence});

  final InsightEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      evidence.sourceType,
      if (evidence.metric != null) evidence.metric!,
      if (evidence.value != null) '${evidence.value}',
      if (evidence.window != null) evidence.window!,
    ];
    return ListTile(
      dense: true,
      leading: const Icon(Icons.data_object, size: 20),
      title: Text(parts.join(' • ')),
    );
  }
}

IconData _classificationIcon(InsightClassification classification) =>
    switch (classification) {
      InsightClassification.fact => Icons.fact_check_outlined,
      InsightClassification.calculation => Icons.calculate_outlined,
      InsightClassification.prediction => Icons.query_stats,
      InsightClassification.recommendation => Icons.lightbulb_outline,
    };
