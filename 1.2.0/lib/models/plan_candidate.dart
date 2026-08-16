/// 候选清单条目:四级结构 类型(一级)→主题(二级)→单元(三级)→标题(四级)
class PlanCandidate {
  const PlanCandidate({
    this.type = '',
    this.topic = '',
    this.unit = '',
    this.title = '',
  });

  final String type;
  final String topic;
  final String unit;
  final String title;

  String get key => '$type$topic$unit$title';

  Map<String, dynamic> toJson() =>
      {'type': type, 'topic': topic, 'unit': unit, 'title': title};

  factory PlanCandidate.fromJson(Map<String, dynamic> j) => PlanCandidate(
        type: j['type'] as String? ?? '',
        topic: j['topic'] as String? ?? '',
        unit: j['unit'] as String? ?? '',
        title: j['title'] as String? ?? '',
      );
}
