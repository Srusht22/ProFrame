import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../infrastructure/cloud/backend.dart';
import '../../l10n/l10n.dart';
import '../../state/cloud.dart';
import 'account_ui.dart';

/// Whether [email] looks like an address — the provider checks it again.
bool looksLikeEmail(String email) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());

/// The shortest password the application asks for. The provider may ask
/// for more, and says so.
const shortestPassword = 8;

/// Signing in — an owner or a worker; which one is the backend's answer,
/// never something chosen here.
class SignInScreen extends ConsumerStatefulWidget {
  /// Said over the form: a session that ended, an account suspended.
  final String? notice;

  const SignInScreen({super.key, this.notice});

  static const emailKey = ValueKey('sign-in-email');
  static const passwordKey = ValueKey('sign-in-password');
  static const submitKey = ValueKey('sign-in-submit');
  static const signUpKey = ValueKey('sign-in-sign-up');
  static const joinKey = ValueKey('sign-in-join');
  static const forgotKey = ValueKey('sign-in-forgot');

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  String? _problem;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (!looksLikeEmail(_email.text)) {
      setState(() => _problem = l.clEmailInvalid);
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _problem = l.clPasswordNeeded);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .signIn(_email.text.trim(), _password.text);
    } on Object catch (e) {
      if (mounted) setState(() => _problem = problemOf(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AccountScaffold(
      title: l.appTitle,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeading(heading: l.clSignInHeading, lead: l.clSignInLead),
            if (widget.notice != null) ...[
              FormProblem(widget.notice),
              const SizedBox(height: 12),
            ],
            FormCard(
              children: [
                TextField(
                  key: SignInScreen.emailKey,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: l.clEmail),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: SignInScreen.passwordKey,
                  controller: _password,
                  obscureText: _hidden,
                  autofillHints: const [AutofillHints.password],
                  textDirection: TextDirection.ltr,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: l.clPassword,
                    suffixIcon: IconButton(
                      tooltip: _hidden ? l.clShowPassword : l.clHidePassword,
                      icon: Icon(
                        _hidden ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    ),
                  ),
                ),
                FormProblem(_problem),
                const SizedBox(height: 16),
                BusyButton(
                  key: SignInScreen.submitKey,
                  label: l.clSignIn,
                  busy: _busy,
                  icon: Icons.login,
                  onPressed: _submit,
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    key: SignInScreen.forgotKey,
                    onPressed: () => _open(const RecoverScreen()),
                    child: Text(l.clForgotPassword),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              key: SignInScreen.signUpKey,
              onPressed: () => _open(const SignUpScreen()),
              icon: const Icon(Icons.storefront_outlined),
              label: Text(l.clCreateOwner),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: SignInScreen.joinKey,
              onPressed: () => _open(const JoinScreen()),
              icon: const Icon(Icons.badge_outlined),
              label: Text(l.clJoinWithInvite),
            ),
          ],
        ),
      ),
    );
  }
}

/// The fields a new account shares: a name, an address and a password
/// typed twice. What the account will be is not among them.
class _NewAccountFields {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final again = TextEditingController();

  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    again.dispose();
  }

  String? problem(AppLocalizations l) {
    if (name.text.trim().isEmpty) return l.clNameNeeded;
    if (!looksLikeEmail(email.text)) return l.clEmailInvalid;
    if (password.text.length < shortestPassword) {
      return l.clPasswordShort(shortestPassword);
    }
    if (password.text != again.text) return l.clPasswordsDiffer;
    return null;
  }

  List<Widget> build(AppLocalizations l, {required String nameLabel}) => [
    TextField(
      key: const ValueKey('new-account-name'),
      controller: name,
      autofillHints: const [AutofillHints.name],
      decoration: InputDecoration(labelText: nameLabel),
    ),
    const SizedBox(height: 12),
    TextField(
      key: const ValueKey('new-account-email'),
      controller: email,
      keyboardType: TextInputType.emailAddress,
      textDirection: TextDirection.ltr,
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(labelText: l.clEmail),
    ),
    const SizedBox(height: 12),
    TextField(
      key: const ValueKey('new-account-password'),
      controller: password,
      obscureText: true,
      textDirection: TextDirection.ltr,
      autofillHints: const [AutofillHints.newPassword],
      decoration: InputDecoration(
        labelText: l.clPassword,
        helperText: l.clPasswordShort(shortestPassword),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      key: const ValueKey('new-account-again'),
      controller: again,
      obscureText: true,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(labelText: l.clPasswordAgain),
    ),
  ];
}

/// What happens after a new account is asked for: signed in where the
/// provider allowed it at once, or told to confirm the address.
Future<void> _afterSignUp(
  BuildContext context,
  WidgetRef ref, {
  required bool confirm,
  required String email,
}) async {
  if (!confirm) {
    await ref.read(sessionProvider.notifier).adopt();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      key: const ValueKey('confirm-email-sent'),
      title: Text(dialog.l10n.clConfirmTitle),
      content: Text(dialog.l10n.clConfirmBody(email)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: Text(dialog.l10n.fwOk),
        ),
      ],
    ),
  );
  if (context.mounted) Navigator.of(context).pop();
}

/// A new owner: a public sign-up, which the backend gives a factory of its
/// own. The role is the backend's to assign; nothing here says it.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  static const factoryKey = ValueKey('sign-up-factory');
  static const submitKey = ValueKey('sign-up-submit');

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _fields = _NewAccountFields();
  final _factory = TextEditingController();
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _fields.dispose();
    _factory.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final problem = _factory.text.trim().isEmpty
        ? l.clFactoryNeeded
        : _fields.problem(l);
    setState(() => _problem = problem);
    if (problem != null) return;
    setState(() => _busy = true);
    try {
      final confirm = await ref
          .read(backendProvider)!
          .signUpOwner(
            name: _fields.name.text,
            factoryName: _factory.text,
            email: _fields.email.text,
            password: _fields.password.text,
          );
      if (!mounted) return;
      // Not working any more: the answer is shown, and nothing spins
      // behind it.
      setState(() => _busy = false);
      await _afterSignUp(
        context,
        ref,
        confirm: confirm,
        email: _fields.email.text.trim(),
      );
    } on Object catch (e) {
      if (mounted) setState(() => _problem = problemOf(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AccountScaffold(
      title: l.clCreateOwner,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeading(heading: l.clCreateOwner, lead: l.clSignUpLead),
          FormCard(
            children: [
              TextField(
                key: SignUpScreen.factoryKey,
                controller: _factory,
                decoration: InputDecoration(labelText: l.clFactoryName),
              ),
              const SizedBox(height: 12),
              ..._fields.build(l, nameLabel: l.clYourName),
              FormProblem(_problem),
              const SizedBox(height: 16),
              BusyButton(
                key: SignUpScreen.submitKey,
                label: l.clCreateAccount,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A worker joining by an owner's invitation: the code they were given,
/// and the address it was made for.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  static const codeKey = ValueKey('join-code');
  static const submitKey = ValueKey('join-submit');

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _fields = _NewAccountFields();
  final _code = TextEditingController();
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _fields.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final problem = _code.text.trim().isEmpty
        ? l.clCodeNeeded
        : _fields.problem(l);
    setState(() => _problem = problem);
    if (problem != null) return;
    setState(() => _busy = true);
    try {
      final confirm = await ref
          .read(backendProvider)!
          .joinAsWorker(
            name: _fields.name.text,
            email: _fields.email.text,
            password: _fields.password.text,
            code: _code.text,
          );
      if (!mounted) return;
      // Not working any more: the answer is shown, and nothing spins
      // behind it.
      setState(() => _busy = false);
      await _afterSignUp(
        context,
        ref,
        confirm: confirm,
        email: _fields.email.text.trim(),
      );
    } on Object catch (e) {
      if (mounted) setState(() => _problem = problemOf(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AccountScaffold(
      title: l.clJoinWithInvite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeading(heading: l.clJoinWithInvite, lead: l.clJoinLead),
          FormCard(
            children: [
              TextField(
                key: JoinScreen.codeKey,
                controller: _code,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: l.clInviteCode),
              ),
              const SizedBox(height: 12),
              ..._fields.build(l, nameLabel: l.clYourName),
              FormProblem(_problem),
              const SizedBox(height: 16),
              BusyButton(
                key: JoinScreen.submitKey,
                label: l.clJoin,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A password forgotten: the provider sends the link, and says nothing
/// about whether the address has an account.
class RecoverScreen extends ConsumerStatefulWidget {
  const RecoverScreen({super.key});

  static const emailKey = ValueKey('recover-email');
  static const submitKey = ValueKey('recover-submit');
  static const sentKey = ValueKey('recover-sent');

  @override
  ConsumerState<RecoverScreen> createState() => _RecoverScreenState();
}

class _RecoverScreenState extends ConsumerState<RecoverScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _problem;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (!looksLikeEmail(_email.text)) {
      setState(() => _problem = l.clEmailInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await ref.read(backendProvider)!.recover(_email.text);
      if (mounted) setState(() => _sent = true);
    } on Object catch (e) {
      if (mounted) setState(() => _problem = problemOf(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AccountScaffold(
      title: l.clForgotPassword,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeading(heading: l.clForgotPassword, lead: l.clRecoverLead),
          FormCard(
            children: [
              if (_sent)
                Text(
                  l.clRecoverSent(_email.text.trim()),
                  key: RecoverScreen.sentKey,
                )
              else ...[
                TextField(
                  key: RecoverScreen.emailKey,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: l.clEmail),
                ),
                FormProblem(_problem),
                const SizedBox(height: 16),
                BusyButton(
                  key: RecoverScreen.submitKey,
                  label: l.clSendLink,
                  busy: _busy,
                  icon: Icons.mail_outline,
                  onPressed: _submit,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A new password, after the provider's reset link was opened.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  static const submitKey = ValueKey('new-password-submit');

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _password = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final problem = _password.text.length < shortestPassword
        ? l.clPasswordShort(shortestPassword)
        : _password.text != _again.text
        ? l.clPasswordsDiffer
        : null;
    setState(() => _problem = problem);
    if (problem != null) return;
    setState(() => _busy = true);
    try {
      await ref.read(backendProvider)!.setPassword(_password.text);
      ref.read(recoveryProvider.notifier).on = false;
      await ref.read(sessionProvider.notifier).adopt();
    } on Object catch (e) {
      if (mounted) setState(() => _problem = problemOf(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AccountScaffold(
      title: l.clNewPassword,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeading(heading: l.clNewPassword),
          FormCard(
            children: [
              TextField(
                controller: _password,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: l.clPassword),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _again,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: l.clPasswordAgain),
              ),
              FormProblem(_problem),
              const SizedBox(height: 16),
              BusyButton(
                key: NewPasswordScreen.submitKey,
                label: l.clSavePassword,
                busy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An owner signing in on a device that holds records from before there
/// were accounts: brought into their factory, or kept aside on the device.
/// Never deleted, and never sent without this answer.
class UnclaimedDataScreen extends ConsumerStatefulWidget {
  const UnclaimedDataScreen({super.key});

  static const bringKey = ValueKey('unclaimed-bring');
  static const keepKey = ValueKey('unclaimed-keep');

  @override
  ConsumerState<UnclaimedDataScreen> createState() =>
      _UnclaimedDataScreenState();
}

class _UnclaimedDataScreenState extends ConsumerState<UnclaimedDataScreen> {
  bool _busy = false;

  Future<void> _settle(bool bringIn) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .settleUnclaimed(bringIn: bringIn);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final factory = ref.watch(sessionProvider).value?.factoryName ?? '';
    return AccountScaffold(
      title: l.clUnclaimedTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeading(
            heading: l.clUnclaimedTitle,
            lead: l.clUnclaimedBody(factory),
          ),
          BusyButton(
            key: UnclaimedDataScreen.bringKey,
            label: l.clUnclaimedBring(factory),
            busy: _busy,
            icon: Icons.cloud_upload_outlined,
            onPressed: () => _settle(true),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: UnclaimedDataScreen.keepKey,
            onPressed: _busy ? null : () => _settle(false),
            child: Text(l.clUnclaimedKeep),
          ),
        ],
      ),
    );
  }
}

/// The error a backend refusal carries, for a test to read.
String? codeOf(Object error) => error is BackendError ? error.code : null;
