import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/design_system/design_system.dart';
import 'backend.dart';
import 'session.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final phone = TextEditingController();
  final otp = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final workshop = TextEditingController();
  bool busy = false, phoneMode = false, register = false;
  String? error, notice, verificationId;
  AccountRole? enrolment;

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await action();
    } catch (failure) {
      if (mounted) setState(() => error = ApiFailure.of(failure).message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      email,
      password,
      phone,
      otp,
      firstName,
      lastName,
      workshop,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _phoneAuth(SessionController controller) async {
    final verification = verificationId;
    if (verification != null) {
      await controller.signInPhone(verification, otp.text.trim());
      return;
    }
    var value = phone.text.replaceAll(RegExp(r'[ ()-]'), '');
    if (RegExp(r'^07[0-9]{8}$').hasMatch(value)) {
      value = '+263${value.substring(1)}';
    }
    if (!RegExp(r'^\+[1-9][0-9]{1,14}$').hasMatch(value)) {
      setState(
        () => error = 'Enter a Zimbabwean mobile or international number.',
      );
      return;
    }
    await controller.auth.verifyPhoneNumber(
      phoneNumber: value,
      verificationCompleted: (credential) async {
        try {
          await controller.auth.signInWithCredential(credential);
        } on FirebaseAuthException catch (failure) {
          if (mounted) setState(() => error = ApiFailure.of(failure).message);
        }
      },
      verificationFailed: (failure) {
        if (mounted) setState(() => error = ApiFailure.of(failure).message);
      },
      codeSent: (id, _) {
        if (mounted) {
          setState(() {
            verificationId = id;
            notice = 'Enter the verification code.';
          });
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider.select((session) => session.stage), (
      previous,
      stage,
    ) {
      if (stage != SessionStage.signedOut ||
          previous == SessionStage.signedOut ||
          !mounted) {
        return;
      }
      for (final field in [
        email,
        password,
        phone,
        otp,
        firstName,
        lastName,
        workshop,
      ]) {
        field.clear();
      }
      setState(() {
        register = false;
        phoneMode = false;
        verificationId = null;
        enrolment = null;
        error = null;
        notice = null;
      });
    });
    final session = ref.watch(sessionProvider);
    final controller = ref.read(sessionProvider.notifier);
    final stage = session.stage;
    final signingIn =
        stage == SessionStage.signedOut ||
        (stage == SessionStage.failed && controller.auth.currentUser == null);
    final choosing = stage == SessionStage.roleSelection;
    final mechanic = stage == SessionStage.mechanicOnboarding;
    final account = session.account;
    final actions = <Widget>[];
    void button(
      String label,
      Future<void> Function() action, {
      bool secondary = false,
    }) => actions.add(
      ActionButton(
        label,
        busy ? null : () => _run(action),
        secondary: secondary,
      ),
    );
    if (signingIn) {
      if (phoneMode) {
        actions.add(
          MechiFormField(
            controller: phone,
            label: 'Phone number',
            keyboardType: TextInputType.phone,
          ),
        );
        if (verificationId != null) {
          actions.add(
            MechiFormField(
              controller: otp,
              label: 'Verification code',
              keyboardType: TextInputType.number,
            ),
          );
        }
        button(
          verificationId == null ? 'Send verification code' : 'Verify phone',
          () => _phoneAuth(controller),
        );
        button(
          'Use email',
          () async => setState(() {
            phoneMode = false;
            verificationId = null;
          }),
          secondary: true,
        );
      } else {
        actions.add(
          MechiFormField(
            controller: email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),
        );
        actions.add(
          MechiFormField(
            controller: password,
            label: 'Password',
            obscureText: true,
          ),
        );
        button(register ? 'Create account' : 'Sign in', () async {
          if (email.text.trim().isEmpty || password.text.isEmpty) {
            setState(() => error = 'Enter an email address and password.');
            return;
          }
          try {
            await controller.signIn(
              email.text.trim(),
              password.text,
              register: register,
            );
          } finally {
            if (mounted) password.clear();
          }
        });
        button(
          register ? 'Return to sign in' : 'Create an account',
          () async => setState(() => register = !register),
          secondary: true,
        );
        button(
          'Use phone',
          () async => setState(() => phoneMode = true),
          secondary: true,
        );
        if (!register) {
          button('Reset password', () async {
            await controller.auth.sendPasswordResetEmail(
              email: email.text.trim(),
            );
            if (mounted) {
              setState(
                () => notice =
                    'If that account exists, check your email for reset instructions.',
              );
            }
          }, secondary: true);
        }
      }
    } else if (stage == SessionStage.verification) {
      actions.add(
        const InformationNotice(
          'Open the verification link in your email, then continue.',
        ),
      );
      button('I verified my email', controller.retry);
      button('Send verification email', () async {
        await controller.auth.currentUser?.sendEmailVerification();
        if (mounted) {
          setState(
            () => notice = 'Check your email for the verification link.',
          );
        }
      }, secondary: true);
      button('Sign out', controller.signOut, secondary: true);
    } else if (choosing) {
      for (final role in [AccountRole.driver, AccountRole.mechanic]) {
        final label = role == AccountRole.driver ? 'Driver' : 'Mechanic';
        if (account?.contexts.any((context) => context.role == role) == true) {
          button(label, () => controller.select(role));
        } else {
          button(
            'Enrol as $label',
            () async => setState(() => enrolment = role),
          );
        }
      }
      if (enrolment == AccountRole.driver) {
        actions.add(
          MechiFormField(
            controller: firstName,
            label: 'First name',
            maxLength: 80,
          ),
        );
        actions.add(
          MechiFormField(
            controller: lastName,
            label: 'Last name',
            maxLength: 80,
          ),
        );
        button(
          'Save Driver role',
          () => controller.enrol(AccountRole.driver, {
            'firstName': firstName.text.trim(),
            'lastName': lastName.text.trim(),
          }),
        );
      } else if (enrolment == AccountRole.mechanic) {
        actions.add(
          MechiFormField(
            controller: workshop,
            label: 'Display name',
            maxLength: 100,
          ),
        );
        button(
          'Save Mechanic role',
          () => controller.enrol(AccountRole.mechanic, {
            'displayName': workshop.text.trim(),
          }),
        );
      }
      button('Sign out', controller.signOut, secondary: true);
    } else if (mechanic) {
      actions.add(
        InformationNotice(
          'Mechanic verification: ${session.role?.verificationStatus?.name ?? 'pending'}. Mechanic operations are unavailable in this release.',
        ),
      );
      button('Choose role', () async => controller.chooseRole());
      button('Sign out', controller.signOut, secondary: true);
    } else if (stage == SessionStage.restricted ||
        stage == SessionStage.retry ||
        stage == SessionStage.failed) {
      actions.add(
        InformationNotice(
          stage == SessionStage.restricted
              ? 'Your Mechi account is restricted. Contact support if you need help.'
              : 'Your account could not be loaded.',
        ),
      );
      button('Retry', controller.retry);
      button('Sign out', controller.signOut, secondary: true);
    } else {
      actions.add(const InformationNotice('Connecting to Mechi…'));
    }

    return Screen(
      title: choosing
          ? 'Choose role'
          : mechanic
          ? 'Mechanic onboarding'
          : 'Mechi account',
      children: [
        const Center(child: MechiLogo(height: 42)),
        if (error != null || session.failure != null)
          InformationNotice(error ?? session.failure!.message),
        if (notice != null) InformationNotice(notice!),
        ...actions,
      ],
    );
  }
}
