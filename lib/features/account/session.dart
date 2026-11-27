import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'backend.dart';
import 'push_registration.dart';

enum AccountStatus { active, suspended, archived }

enum AccountRole { driver, mechanic, admin }

enum VerificationStatus {
  draft,
  submitted,
  underReview,
  assessmentRequired,
  changesRequired,
  approved,
  rejected,
  suspended,
}

enum SessionStage {
  initializing,
  signedOut,
  authenticating,
  firebaseIdentity,
  bootstrapping,
  verification,
  roleSelection,
  driverOnboarding,
  mechanicOnboarding,
  ready,
  restricted,
  retry,
  failed,
}

T _enum<T extends Enum>(Iterable<T> values, Object? value) => values.firstWhere(
  (item) =>
      item.name.toLowerCase() ==
      (value as String).replaceAll('_', '').toLowerCase(),
);

class RoleContext {
  RoleContext.fromJson(Json json)
    : role = _enum(AccountRole.values, json['role']),
      profileComplete = json['profileComplete'] as bool,
      canContinueOnboarding = json['canContinueOnboarding'] as bool,
      canPerformMechanicWork = json['canPerformMechanicWork'] as bool,
      verificationStatus = json['verificationStatus'] == null
          ? null
          : _enum(VerificationStatus.values, json['verificationStatus']);
  final AccountRole role;
  final bool profileComplete, canContinueOnboarding, canPerformMechanicWork;
  final VerificationStatus? verificationStatus;
}

class Account {
  Account.fromJson(Json json)
    : id = json['id'] as String,
      email = json['email'] as String?,
      phone = json['phone'] as String?,
      status = _enum(AccountStatus.values, json['status']),
      roles = (json['grantedRoles'] as List)
          .map((value) => _enum(AccountRole.values, value))
          .toSet(),
      contexts = (json['roleContexts'] as List)
          .cast<Json>()
          .map(RoleContext.fromJson)
          .toList(),
      driverProfileComplete = json['driverProfileComplete'] as bool?,
      mechanicProfileComplete = json['mechanicProfileComplete'] as bool?,
      mechanicVerificationStatus = json['mechanicVerificationStatus'] == null
          ? null
          : _enum(
              VerificationStatus.values,
              json['mechanicVerificationStatus'],
            );
  final String id;
  final String? email, phone;
  final AccountStatus status;
  final Set<AccountRole> roles;
  final List<RoleContext> contexts;
  final bool? driverProfileComplete, mechanicProfileComplete;
  final VerificationStatus? mechanicVerificationStatus;
}

class Session {
  const Session(this.stage, {this.account, this.role, this.failure});
  final SessionStage stage;
  final Account? account;
  final RoleContext? role;
  final ApiFailure? failure;
}

final sessionProvider = NotifierProvider<SessionController, Session>(
  SessionController.new,
);

class SessionController extends Notifier<Session> {
  MechiApi? get _api => ref.read(apiProvider);
  FirebaseAuth get auth => _api!.auth;
  CancelToken? _pending;
  String? _uid;

  @override
  Session build() {
    final api = ref.watch(apiProvider);
    if (api == null) return const Session(SessionStage.signedOut);
    final stream = api.auth.authStateChanges().listen(
      (user) => unawaited(_resolve(user)),
    );
    final restrictions = api.restrictedUsers.listen((uid) {
      if (_uid == uid && auth.currentUser?.uid == uid) {
        _pending?.cancel();
        state = const Session(SessionStage.restricted);
      }
    });
    ref.onDispose(() {
      unawaited(restrictions.cancel());
      _pending?.cancel();
      unawaited(stream.cancel());
    });
    return const Session(SessionStage.initializing);
  }

  Future<void> _resolve(User? user) async {
    _pending?.cancel();
    _uid = user?.uid;
    if (user == null) {
      state = const Session(SessionStage.signedOut);
      return;
    }
    final pending = _pending = CancelToken();
    state = const Session(SessionStage.firebaseIdentity);
    try {
      if (user.email != null &&
          !user.emailVerified &&
          user.phoneNumber == null) {
        state = const Session(SessionStage.verification);
        return;
      }
      state = const Session(SessionStage.bootstrapping);
      Account account;
      try {
        account = Account.fromJson(
          await _api!.request<Json>('GET', 'auth/me', cancelToken: pending),
        );
      } on DioException catch (error) {
        if (ApiFailure.of(error).code != 'ACCOUNT_UNPROVISIONED') rethrow;
        account = Account.fromJson(
          await _api!.request<Json>(
            'POST',
            'auth/bootstrap',
            cancelToken: pending,
          ),
        );
      }
      if (pending.isCancelled || _uid != user.uid) return;
      if (account.status != AccountStatus.active) {
        state = Session(SessionStage.restricted, account: account);
      } else if (account.contexts.length == 1 &&
          account.contexts.single.role != AccountRole.admin) {
        await select(
          account.contexts.single.role,
          account: account,
          cancel: pending,
        );
      } else {
        state = Session(SessionStage.roleSelection, account: account);
      }
    } catch (error) {
      if (pending.isCancelled || _uid != user.uid) return;
      final failure = ApiFailure.of(error);
      state = Session(switch (failure.code) {
        'VERIFIED_IDENTITY_REQUIRED' => SessionStage.verification,
        'ACCOUNT_RESTRICTED' => SessionStage.restricted,
        _ => failure.recoverable ? SessionStage.retry : SessionStage.failed,
      }, failure: failure);
    }
  }

  Future<void> retry() async {
    final user = auth.currentUser;
    if (user != null) {
      await user.reload();
      await auth.currentUser?.getIdToken(true);
    }
    await _resolve(auth.currentUser);
  }

  Future<void> signIn(
    String email,
    String password, {
    bool register = false,
  }) async {
    state = const Session(SessionStage.authenticating);
    try {
      if (register) {
        final result = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await result.user?.sendEmailVerification();
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
    } catch (error) {
      state = Session(SessionStage.failed, failure: ApiFailure.of(error));
    }
  }

  Future<void> signInPhone(String verificationId, String code) =>
      auth.signInWithCredential(
        PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code,
        ),
      );

  Future<void> select(
    AccountRole role, {
    Account? account,
    CancelToken? cancel,
  }) async {
    final current = account ?? state.account!;
    final uid = auth.currentUser?.uid;
    final context = RoleContext.fromJson(
      await _api!.request<Json>(
        'POST',
        'auth/select-role',
        body: {'role': role.name.toUpperCase()},
        cancelToken: cancel,
      ),
    );
    if (uid != _uid ||
        auth.currentUser?.uid != uid ||
        cancel?.isCancelled == true) {
      return;
    }
    state = Session(
      role == AccountRole.mechanic
          ? SessionStage.mechanicOnboarding
          : context.profileComplete
          ? SessionStage.ready
          : SessionStage.driverOnboarding,
      account: current,
      role: context,
    );
  }

  Future<void> enrol(AccountRole role, Json names) async {
    final account = Account.fromJson(
      await _api!.request<Json>(
        'POST',
        'auth/enrol-role',
        body: {'role': role.name.toUpperCase(), ...names},
      ),
    );
    await select(role, account: account);
  }

  void chooseRole() =>
      state = Session(SessionStage.roleSelection, account: state.account);

  Future<void> sync() async {
    await auth.currentUser?.reload();
    await auth.currentUser?.getIdToken(true);
    final uid = auth.currentUser?.uid;
    final account = Account.fromJson(
      await _api!.request<Json>('POST', 'auth/sync-identity'),
    );
    if (auth.currentUser?.uid != uid ||
        _uid != uid ||
        account.id != state.account?.id) {
      return;
    }
    state = Session(state.stage, account: account, role: state.role);
  }

  Future<void> completeDriver() async {
    final uid = auth.currentUser?.uid;
    final account = Account.fromJson(
      await _api!.request<Json>('GET', 'auth/me'),
    );
    if (uid != _uid || account.id != state.account?.id) return;
    await select(AccountRole.driver, account: account);
  }

  Future<void> refreshMechanic() async {
    final owner = state.account?.id;
    final uid = auth.currentUser?.uid;
    final account = Account.fromJson(
      await _api!.request<Json>('GET', 'auth/me'),
    );
    if (uid != _uid ||
        account.id != owner ||
        state.role?.role != AccountRole.mechanic) {
      return;
    }
    if (account.status != AccountStatus.active) {
      state = Session(SessionStage.restricted, account: account);
      return;
    }
    final role = account.contexts
        .where((context) => context.role == AccountRole.mechanic)
        .firstOrNull;
    state = role == null
        ? Session(SessionStage.roleSelection, account: account)
        : Session(
            SessionStage.mechanicOnboarding,
            account: account,
            role: role,
          );
  }

  Future<void> signOut() async {
    _pending?.cancel();
    try {
      await ref.read(pushRegistrationProvider).revoke();
    } finally {
      await auth.signOut();
    }
  }

  Future<void> revoke() async {
    await _api!.request<Json>('POST', 'auth/revoke-sessions');
    await signOut();
  }
}
