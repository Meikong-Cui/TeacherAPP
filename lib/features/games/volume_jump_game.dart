import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:teacher_app/features/games/game_shell.dart';

/// 音量跳一跳（发音）：按住发声，麦克风振幅决定跳跃距离；无权限自动降级手动蓄力。
class VolumeJumpGame extends StatefulWidget {
  const VolumeJumpGame({super.key});

  @override
  State<VolumeJumpGame> createState() => _VolumeJumpGameState();
}

class _VolumeJumpGameState extends State<VolumeJumpGame>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  bool _micReady = false;
  bool _manual = false;
  bool _pressing = false;
  double _charge = 0;
  Timer? _tick;

  final List<double> _platforms = List<double>.generate(7, (int i) => i * 150.0);
  int _current = 0;
  int _score = 0;
  double _charX = 0;
  double _charY = 0;
  bool _fell = false;
  bool _won = false;

  late final AnimationController _anim;
  double _jumpStartX = 0;
  double _jumpEndX = 0;
  double _jumpH = 0;

  @override
  void initState() {
    super.initState();
    _charX = _platforms.first;
    _anim = AnimationController(vsync: this);
    _anim.addListener(() {
      final double k = _anim.value;
      if (!mounted) return;
      setState(() {
        _charX = _jumpStartX + (_jumpEndX - _jumpStartX) * k;
        _charY = sin(pi * k) * _jumpH;
      });
    });
    _anim.addStatusListener((AnimationStatus s) {
      if (s == AnimationStatus.completed) _onLanded();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _anim.dispose();
    _recorder.dispose();
    super.dispose();
  }

  int? _platformAt(double x) {
    for (int i = 0; i < _platforms.length; i++) {
      if ((_platforms[i] - x).abs() <= 55) return i;
    }
    return null;
  }

  Future<void> _startPress() async {
    if (_pressing || _fell || _won) return;
    setState(() {
      _pressing = true;
      _charge = 0;
    });
    if (!_manual) {
      try {
        final bool has = await _recorder.hasPermission();
        if (!has) {
          setState(() => _manual = true);
        } else {
          final dir = await getTemporaryDirectory();
          await _recorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
            path: '${dir.path}/vol_jump_amp.m4a',
          );
          _micReady = true;
        }
      } catch (_) {
        setState(() => _manual = true);
      }
    }
    _tick = Timer.periodic(const Duration(milliseconds: 50), (_) => _readVol());
  }

  Future<void> _readVol() async {
    double v = 0;
    if (!_manual && _micReady) {
      try {
        final Amplitude amp = await _recorder.getAmplitude();
        final double cur = amp.current;
        v = ((cur + 50) / 50).clamp(0, 1).toDouble();
      } catch (_) {
        v = 0;
      }
    } else {
      v = _charge;
    }
    if (!mounted) return;
    setState(() {
      if (_pressing) {
        if (_manual) {
          _charge = (_charge + 0.02).clamp(0, 1);
        } else {
          _charge = _charge < v ? v : (_charge * 0.9 + v * 0.1);
        }
      }
    });
  }

  Future<void> _endPress() async {
    if (!_pressing) return;
    _pressing = false;
    _tick?.cancel();
    try {
      if (_micReady) await _recorder.stop();
    } catch (_) {
      // 忽略停止异常
    }
    _jump(_charge);
  }

  void _jump(double power) {
    _jumpStartX = _charX;
    _jumpEndX = _charX + 30 + power * 240;
    _jumpH = 70 + power * 140;
    _anim.duration = Duration(milliseconds: (450 + power * 400).toInt());
    _anim.reset();
    _anim.forward();
  }

  void _onLanded() {
    final int? land = _platformAt(_jumpEndX);
    if (land != null) {
      _current = land;
      _score++;
      _charX = _platforms[land];
      _charY = 0;
      if (_current == _platforms.length - 1) _won = true;
    } else {
      _fell = true;
      _charY = 0;
    }
    if (mounted) setState(() {});
  }

  void _retry() {
    setState(() {
      _fell = false;
      _charX = _platforms[_current];
      _charY = 0;
    });
  }

  void _reset() {
    setState(() {
      _current = 0;
      _score = 0;
      _charX = _platforms.first;
      _charY = 0;
      _fell = false;
      _won = false;
      _charge = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: '音量跳一跳',
      instructions: '玩法：\n'
          '1. 按住下方按钮并发声（音量越大，蓄力条越满）。\n'
          '2. 松手后小动物按音量大小向前跳。\n'
          '3. 落到下一个平台得 1 分，掉下去可重试；跳到终点即过关。\n'
          '（若未授权麦克风，将自动切换为「按住蓄力」模式。）',
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                Text('得分：$_score',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                if (_manual)
                  const Text('手动蓄力模式',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                TextButton(onPressed: _reset, child: const Text('重新开始')),
              ],
            ),
          ),
          Expanded(child: _buildWorld()),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildWorld() {
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints c) {
        final double w = c.maxWidth;
        final double h = c.maxHeight;
        final double anchor = w * 0.3;
        final double cameraX = _charX - anchor;
        final double ground = h - 70;
        final List<Widget> kids = <Widget>[Container(color: Colors.lightBlue.shade50)];
        for (int i = 0; i < _platforms.length; i++) {
          final double px = _platforms[i] - cameraX;
          if (px < -80 || px > w + 80) continue;
          kids.add(Positioned(
            left: px - 38,
            top: ground - 16,
            child: Container(
              width: 76,
              height: 16,
              decoration: BoxDecoration(
                color: i == _current ? Colors.orange : Colors.brown.shade400,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ));
        }
        final double cx = _charX - cameraX;
        kids.add(Positioned(
          left: cx - 18,
          top: ground - 16 - _charY - 34,
          child: const Text('🐸', style: TextStyle(fontSize: 34)),
        ));
        return Stack(children: kids);
      },
    );
  }

  Widget _buildControls() {
    if (_won) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            const Text('🎉 到达终点！',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.replay),
              label: const Text('再玩一次'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: <Widget>[
          if (_fell)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text('差一点，掉下去了！', style: TextStyle(color: Colors.red)),
                  TextButton(onPressed: _retry, child: const Text('重试')),
                ],
              ),
            ),
          LinearProgressIndicator(
            value: _charge,
            minHeight: 14,
            backgroundColor: Colors.grey.shade300,
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTapDown: (_) => _startPress(),
            onTapUp: (_) => _endPress(),
            onTapCancel: () => _endPress(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _pressing ? Colors.red : Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                _pressing ? '发声中…松手起跳' : '按住并发声蓄力',
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
