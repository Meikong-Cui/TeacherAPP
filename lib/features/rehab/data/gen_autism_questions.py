import json, sys

src = 'C:/Users/cyx20/WorkBuddy/教育app/teacher_app/lib/features/rehab/data/_autism_questions_raw.json'
out = 'C:/Users/cyx20/WorkBuddy/教育app/teacher_app/lib/features/rehab/data/autism_questions.dart'

with open(src, encoding='utf-8') as f:
    data = json.load(f)

def d(s):
    """Emit a valid Dart string literal using JSON encoding (double-quoted)."""
    return json.dumps(s if s is not None else '', ensure_ascii=False)

area_labels = {
    'perception': '感知觉',
    'gross_motor': '粗大动作',
    'fine_motor': '精细动作',
    'language': '语言与沟通',
    'cognition': '认知',
    'social': '社会交往',
    'self_care': '生活自理',
    'emotion': '情绪与行为',
}
emotion_dims = ['依附情绪行为', '情绪理解', '情绪表达与调节', '关系与情感', '对物品的兴趣', '感觉偏好']

lines = []
lines.append('// 此文件由 1.孤独症评测题目一.docx 结构化提取生成，请勿手工修改。')
lines.append('// 共 8 大领域评估表，含情绪与行为 6 子维度，合计 493 题。')
lines.append('// 评级：普通领域 P(通过)/E(中间项)/F(不通过)/X(未评)；情绪与行为域 A(没有)/M(轻度)/S(重度)。')
lines.append('')
lines.append('/// 单道评估题。')
lines.append('class AutismQuestion {')
lines.append('  const AutismQuestion({')
lines.append('    required this.code,')
lines.append('    required this.scope,')
lines.append('    required this.name,')
lines.append('    required this.refAge,')
lines.append('    this.sub,')
lines.append('  });')
lines.append('  final String code;')
lines.append('  final String scope;')
lines.append('  final String name;')
lines.append('  final String refAge;')
lines.append('  /// 仅情绪与行为域有：所属子维度（依附情绪行为/情绪理解/…）。')
lines.append('  final String? sub;')
lines.append('}')
lines.append('')
lines.append('/// 一个评估领域（含其题目列表）。')
lines.append('class AutismQuestionArea {')
lines.append('  const AutismQuestionArea({')
lines.append('    required this.key,')
lines.append('    required this.label,')
lines.append('    required this.items,')
lines.append('  });')
lines.append('  final String key;')
lines.append('  final String label;')
lines.append('  final List<AutismQuestion> items;')
lines.append('}')
lines.append('')
lines.append('/// 8 大领域顺序（与后端 AutismArchiveService.AREAS_8 一致）。')
lines.append('const List<String> autismAreaKeys = <String>[')
for a in data:
    lines.append('  %s,' % d(a['key']))
lines.append('];')
lines.append('')
lines.append('const Map<String, String> autismAreaLabels = <String, String>{')
for a in data:
    lines.append('  %s: %s,' % (d(a['key']), d(area_labels.get(a['key'], a['label']))))
lines.append('};')
lines.append('')
lines.append('/// 情绪与行为 6 子维度（与后端 EMOTION_DIMS 一致）。')
lines.append('const List<String> autismEmotionDims = <String>[')
for dim in emotion_dims:
    lines.append('  %s,' % d(dim))
lines.append('];')
lines.append('')
lines.append('/// 普通领域评级选项。')
lines.append("const List<String> autismNormalRatings = <String>['P', 'E', 'F', 'X'];")
lines.append('/// 情绪与行为域评级选项（A 没有 / M 轻度 / S 重度）。')
lines.append("const List<String> autismEmotionRatings = <String>['A', 'M', 'S'];")
lines.append('')
lines.append('/// 某领域是否使用情绪域评级。')
lines.append("bool autismIsEmotionArea(String areaKey) => areaKey == 'emotion';")
lines.append('')
lines.append('/// 某领域可用的评级选项。')
lines.append('List<String> autismRatingsFor(String areaKey) =>')
lines.append("    autismIsEmotionArea(areaKey) ? autismEmotionRatings : autismNormalRatings;")
lines.append('')
lines.append('const List<AutismQuestionArea> autismQuestionAreas = <AutismQuestionArea>[')
total = 0
for a in data:
    lines.append('  AutismQuestionArea(')
    lines.append('    key: %s,' % d(a['key']))
    lines.append('    label: %s,' % d(area_labels.get(a['key'], a['label'])))
    lines.append('    items: <AutismQuestion>[')
    for it in a['items']:
        total += 1
        sub = it.get('sub')
        if sub:
            lines.append('      AutismQuestion(code: %s, scope: %s, name: %s, refAge: %s, sub: %s),'
                         % (d(it.get('code')), d(it.get('scope')), d(it.get('name')), d(it.get('refAge')), d(sub)))
        else:
            lines.append('      AutismQuestion(code: %s, scope: %s, name: %s, refAge: %s),'
                         % (d(it.get('code')), d(it.get('scope')), d(it.get('name')), d(it.get('refAge'))))
    lines.append('    ],')
    lines.append('  ),')
lines.append('];')
lines.append('')
lines.append('/// 题目总数（应为 493）。')
lines.append('const int autismQuestionTotal = %d;' % total)
lines.append('')

with open(out, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print('WROTE', out, 'questions=', total)
