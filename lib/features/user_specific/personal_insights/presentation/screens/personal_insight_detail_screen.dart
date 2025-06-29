import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mental_wellness_app/models/personal_insight_model.dart';

class PersonalInsightDetailScreen extends StatelessWidget {
  final PersonalInsight insight;

  const PersonalInsightDetailScreen({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy年M月d日');
    final timeFormat = DateFormat('H:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text('${dateFormat.format(insight.generatedDate.toDate())} の気づき'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildSectionTitle(context, '📝 気づきの要約', Icons.lightbulb_outline),
            const SizedBox(height: 8.0),
            _buildContentCard(
              context,
              insight.summaryText,
              color: Colors.blue.shade50,
              borderColor: Colors.blue.shade200,
            ),
            const SizedBox(height: 24.0),
            _buildSectionTitle(context, '🔍 主要な観察ポイント', Icons.search),
            const SizedBox(height: 8.0),
            if (insight.keyObservations.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(), // To disable scrolling within ListView
                itemCount: insight.keyObservations.length,
                itemBuilder: (context, index) {
                  return _buildObservationItem(context, insight.keyObservations[index]);
                },
              )
            else
              _buildContentCard(context, '具体的な観察ポイントはありませんでした。', color: Colors.grey.shade100),
            const SizedBox(height: 24.0),
            _buildSectionTitle(context, '✨ ポジティブなアファメーション', Icons.star_outline),
            const SizedBox(height: 8.0),
            _buildContentCard(
              context,
              insight.positiveAffirmation,
              color: Colors.green.shade50,
              borderColor: Colors.green.shade200,
              textStyle: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.black87),
            ),
            const SizedBox(height: 24.0),
            _buildSectionTitle(context, 'ℹ️ 分析情報', Icons.info_outline),
            const SizedBox(height: 8.0),
            Card(
              elevation: 0,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('生成日時', '${dateFormat.format(insight.generatedDate.toDate())} ${timeFormat.format(insight.generatedDate.toDate())}'),
                    _buildInfoRow('分析対象期間', 
                        '${dateFormat.format(insight.periodCoveredStart.toDate())} 〜 ${dateFormat.format(insight.periodCoveredEnd.toDate())}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Theme.of(context).primaryColorDark),
        const SizedBox(width: 8.0),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildContentCard(BuildContext context, String content, {Color? color, Color? borderColor, TextStyle? textStyle}) {
    return Card(
      elevation: 0,
      color: color ?? Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(color: borderColor ?? Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          content,
          style: textStyle ?? const TextStyle(fontSize: 16, height: 1.5),
          textAlign: TextAlign.justify,
        ),
      ),
    );
  }

  Widget _buildObservationItem(BuildContext context, String observation) {
    return Card(
      elevation: 0,
      color: Colors.amber.shade50,
      margin: const EdgeInsets.only(bottom: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(color: Colors.amber.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_outline, size: 18, color: Colors.amber.shade700),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                observation,
                style: const TextStyle(fontSize: 15, height: 1.4),
                textAlign: TextAlign.justify,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: Colors.black54))),
        ],
      ),
    );
  }
}
