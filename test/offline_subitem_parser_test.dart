import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_app/features/rehab/presentation/offline_subitem_parser.dart';

/// 线下模板报告小项解析/过滤的单测。
///
/// 重点覆盖：教师版（带编号小项）与家长版（概括式段落、无编号小项）两种文本形态。
/// 过滤规则必须与后端 OfflineTemplateService.filterSubItems 完全一致，
/// 否则屏幕预览与导出 PDF 内容会对不上。
void main() {
  const String teacherText = '操作模仿\n'
      '1、结合节奏明显的音乐旋律做动作\n'
      '2、模仿用小棒物件敲打\n'
      '语言模仿\n'
      '1、结合动作模仿说出单字';

  const String parentText = '家长在日常生活中多给予鼓励与陪伴，'
      '并配合教师的教学计划进行巩固练习。';

  group('isNumberedLine', () {
    test('识别阿拉伯数字编号行', () {
      expect(isNumberedLine('1、结合音乐'), isTrue);
      expect(isNumberedLine('2. 模仿动作'), isTrue);
      expect(isNumberedLine('  3) 敲打'), isTrue);
      expect(isNumberedLine('10、第十项'), isTrue);
    });

    test('识别圈码编号行', () {
      expect(isNumberedLine('① 结合音乐'), isTrue);
      expect(isNumberedLine('③敲打'), isTrue);
    });

    test('分类标题与空行不算小项', () {
      expect(isNumberedLine('操作模仿'), isFalse);
      expect(isNumberedLine(''), isFalse);
      expect(isNumberedLine('   '), isFalse);
    });
  });

  group('parseItemIndices / itemTexts', () {
    test('按出现顺序编号 0,1,2（跨标题连续）', () {
      expect(parseItemIndices(teacherText), <int>[0, 1, 2]);
    });

    test('itemTexts 保留原始编号文本', () {
      expect(itemTexts(teacherText), <String>[
        '1、结合节奏明显的音乐旋律做动作',
        '2、模仿用小棒物件敲打',
        '1、结合动作模仿说出单字',
      ]);
    });

    test('概括式段落没有小项', () {
      expect(parseItemIndices(parentText), isEmpty);
      expect(itemTexts(parentText), isEmpty);
    });
  });

  group('filterSubItems', () {
    test('selected 为 null 表示全量，原样返回', () {
      expect(filterSubItems(teacherText, null), teacherText);
    });

    test('全选时原文不变', () {
      expect(filterSubItems(teacherText, <int>{0, 1, 2}), teacherText);
    });

    test('部分勾选：只留被选小项及其所属标题', () {
      expect(
        filterSubItems(teacherText, <int>{0}),
        '操作模仿\n1、结合节奏明显的音乐旋律做动作',
      );
      expect(
        filterSubItems(teacherText, <int>{2}),
        '语言模仿\n1、结合动作模仿说出单字',
      );
    });

    test('标题下无任何选中项时该标题一并剔除', () {
      // 只选「语言模仿」下的小项，「操作模仿」标题应消失。
      final String out = filterSubItems(teacherText, <int>{2});
      expect(out.contains('操作模仿'), isFalse);
      expect(out.contains('语言模仿'), isTrue);
    });

    test('空集合表示全不选', () {
      expect(filterSubItems(teacherText, <int>{}), '');
    });

    test('无编号小项的概括式段落原样保留，不得被清空', () {
      // 家长版指导说明（回归用例）：即便 selection 为空或与文本无关，
      // 也不能整段抹掉，否则家长版报告预览/PDF 会出现空白。
      expect(filterSubItems(parentText, <int>{}), parentText);
      expect(filterSubItems(parentText, <int>{0, 1}), parentText);
      expect(filterSubItems(parentText, null), parentText);
    });
  });

  group('encodeSelectedItems / decodeSelectedItems', () {
    test('编码解码往返一致', () {
      final Map<String, Map<String, List<int>>> items =
          <String, Map<String, List<int>>>{
        '感知': <String, List<int>>{
          'rehabGoal': <int>[0, 2],
          'guidance': <int>[1],
        },
      };
      final Map<String, Map<String, List<int>>>? back =
          decodeSelectedItems(encodeSelectedItems(items));
      expect(back, isNotNull);
      expect(back!['感知']!['rehabGoal'], <int>[0, 2]);
      expect(back['感知']!['guidance'], <int>[1]);
    });

    test('空 / null 参数返回 null', () {
      expect(decodeSelectedItems(null), isNull);
      expect(decodeSelectedItems(''), isNull);
    });
  });
}
