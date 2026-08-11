import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_app/data/models/reimbursement.dart';
import 'package:teacher_app/features/reimbursement/data/reimbursement_repository.dart';

final Provider<ReimbursementRepository> reimbursementRepositoryProvider =
    Provider<ReimbursementRepository>((ref) => const ReimbursementRepository());

final StateNotifierProvider<ReimbursementListNotifier, ReimbursementListState>
    reimbursementListProvider =
    StateNotifierProvider<ReimbursementListNotifier, ReimbursementListState>(
  (ref) => ReimbursementListNotifier(ref.watch(reimbursementRepositoryProvider)),
);

/// 我的报销列表状态。
class ReimbursementListState {
  const ReimbursementListState({
    this.list = const <Reimbursement>[],
    this.loading = false,
    this.error,
  });

  final List<Reimbursement> list;
  final bool loading;
  final String? error;

  ReimbursementListState copyWith({
    List<Reimbursement>? list,
    bool? loading,
    String? error,
  }) =>
      ReimbursementListState(
        list: list ?? this.list,
        loading: loading ?? this.loading,
        error: error,
      );
}

/// 报销列表逻辑：加载 / 提交。
class ReimbursementListNotifier
    extends StateNotifier<ReimbursementListState> {
  ReimbursementListNotifier(this._repository)
      : super(const ReimbursementListState());

  final ReimbursementRepository _repository;

  /// 加载我的报销列表。
  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final List<Reimbursement> list = await _repository.listMine();
      state = state.copyWith(list: list, loading: false);
    } on ReimbursementException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败：$e');
    }
  }

  /// 提交新报销申请，成功后刷新列表。
  Future<Reimbursement> apply(Reimbursement draft) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final Reimbursement created = await _repository.apply(draft);
      final List<Reimbursement> next = <Reimbursement>[created, ...state.list];
      state = state.copyWith(list: next, loading: false);
      return created;
    } on ReimbursementException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(loading: false, error: '提交失败：$e');
      rethrow;
    }
  }
}

/// 单条报销详情（按 id）。
final FutureProviderFamily<Reimbursement?, String> reimbursementDetailProvider =
    FutureProvider.family<Reimbursement?, String>(
  (ref, id) => ref.watch(reimbursementRepositoryProvider).getById(id),
);
