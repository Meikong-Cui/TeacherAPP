import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/data/models/seal.dart';
import 'package:teacher_app/features/seal/data/seal_repository.dart';

final Provider<SealRepository> sealRepositoryProvider =
    Provider<SealRepository>((ref) => const SealRepository());

/// 用章申请列表状态。
class SealListState {
  const SealListState({
    this.items = const <SealApproval>[],
    this.loading = false,
    this.error,
    this.message,
  });

  final List<SealApproval> items;
  final bool loading;
  final String? error;
  final String? message;

  SealListState copyWith({
    List<SealApproval>? items,
    bool? loading,
    String? error,
    String? message,
  }) =>
      SealListState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        error: error,
        message: message,
      );
}

class SealListNotifier extends StateNotifier<SealListState> {
  SealListNotifier(this._repo) : super(const SealListState());

  final SealRepository _repo;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final List<SealApproval> items = await _repo.list();
      state = state.copyWith(items: items, loading: false, message: null);
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败：$e');
    }
  }

  Future<bool> apply(SealApproval approval) async {
    try {
      await _repo.apply(approval);
      await load();
      state = state.copyWith(message: '用章申请已提交');
      return true;
    } catch (e) {
      state = state.copyWith(error: '提交失败：$e');
      return false;
    }
  }

  Future<bool> review(String id, int status, {String? comment}) async {
    try {
      await _repo.approve(id, status, comment: comment);
      await load();
      state = state.copyWith(
          message: status == 1 ? '已通过用章申请' : '已驳回用章申请');
      return true;
    } catch (e) {
      state = state.copyWith(error: '操作失败：$e');
      return false;
    }
  }
}

final StateNotifierProvider<SealListNotifier, SealListState>
    sealListProvider =
    StateNotifierProvider<SealListNotifier, SealListState>(
  (ref) => SealListNotifier(ref.watch(sealRepositoryProvider)),
);
