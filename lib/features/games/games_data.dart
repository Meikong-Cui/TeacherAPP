import 'package:flutter/material.dart';

/// 小游戏元信息（用于游戏大厅卡片展示与路由跳转）。
class GameMeta {
  const GameMeta({
    required this.id,
    required this.title,
    required this.category,
    required this.desc,
    required this.icon,
    required this.route,
  });

  final String id;
  final String title;
  final String category; // 听觉 / 发音 / 认知 / 情绪表达
  final String desc;
  final IconData icon;
  final String route;
}

const List<GameMeta> kGames = <GameMeta>[
  GameMeta(
    id: 'find',
    title: '找一找小动物',
    category: '听觉',
    desc: '听叫声提示，在画面里找出对应小动物，找到会标红圈。',
    icon: Icons.visibility_outlined,
    route: '/games/find',
  ),
  GameMeta(
    id: 'jump',
    title: '音量跳一跳',
    category: '发音',
    desc: '对着话筒发声，声音越大跳得越远，帮小动物过独木桥。',
    icon: Icons.graphic_eq_outlined,
    route: '/games/jump',
  ),
  GameMeta(
    id: 'puzzle',
    title: '拼图小游戏',
    category: '认知',
    desc: '把打乱的图块拼回原样，训练观察与空间认知。',
    icon: Icons.grid_view_outlined,
    route: '/games/puzzle',
  ),
  GameMeta(
    id: 'sequence',
    title: '故事排序',
    category: '认知',
    desc: '把打乱顺序的故事图（如洗手步骤）拖回正确顺序。',
    icon: Icons.sort_outlined,
    route: '/games/sequence',
  ),
  GameMeta(
    id: 'wheel',
    title: '表情大转盘',
    category: '情绪表达',
    desc: '转动转盘，抽到哪个表情就做出对应表情。',
    icon: Icons.emoji_emotions_outlined,
    route: '/games/wheel',
  ),
  GameMeta(
    id: 'schulte',
    title: '舒尔特方格',
    category: '专注力',
    desc: '按数字从小到大依次点击，训练专注力与视觉搜索。',
    icon: Icons.grid_3x3_outlined,
    route: '/games/schulte',
  ),
  GameMeta(
    id: 'pairs',
    title: '对对碰',
    category: '记忆力',
    desc: '先看图案位置再翻牌配对，训练工作记忆。',
    icon: Icons.flutter_dash_outlined,
    route: '/games/pairs',
  ),
  GameMeta(
    id: 'seqmem',
    title: '顺序记忆',
    category: '记忆力',
    desc: '记住依次点亮的格子并按顺序复现，训练顺序记忆。',
    icon: Icons.view_timeline_outlined,
    route: '/games/seqmem',
  ),
];
