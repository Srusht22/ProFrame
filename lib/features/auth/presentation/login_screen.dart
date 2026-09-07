import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/demo/demo_data_seeder.dart';
import '../../../domain/auth/permission.dart';
import '../../../shared/providers/auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _obscure = true;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await ref.read(authNotifierProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          rememberMe: _rememberMe,
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  void _fillDemo(UserRole role) {
    _emailController.text = '${role.name}@proframe.demo';
    _passwordController.text = DemoDataSeeder.demoPassword;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppSpacing.breakpointMedium;

    final form = SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isWide) ...[
                const _BrandMark(),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text('Sign in to ProFrame', style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Factory operations, quotations and production — in one place.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Work email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v ?? true)),
                        const Text('Remember me'),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Contact your administrator to reset your password.')),
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
              ],
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.brandDarkGreenDeep),
                        )
                      : const Text('Sign in'),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _DemoAccountsPanel(onSelect: _fillDemo),
            ],
          ),
        ),
      ),
    );

    if (!isWide) {
      return Scaffold(body: form);
    }

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              color: AppColors.brandDarkGreen,
              child: const Center(child: _BrandHero()),
            ),
          ),
          Expanded(flex: 4, child: Center(child: form)),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.brandDarkGreen, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.window_rounded, color: AppColors.brandCream),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Text('ProFrame', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: AppColors.brandCream, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.window_rounded, color: AppColors.brandDarkGreenDeep, size: 30),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'ProFrame',
            style: TextStyle(color: AppColors.brandCream, fontSize: 34, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: 380,
            child: Text(
              'Configure, price and manufacture doors and windows — from first sketch to production floor.',
              style: TextStyle(color: AppColors.textOnDark.withOpacity(0.85), fontSize: 16, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoAccountsPanel extends StatelessWidget {
  final void Function(UserRole role) onSelect;
  const _DemoAccountsPanel({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Demo accounts', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            'Tap a role to fill in its demo sign-in (password: ${DemoDataSeeder.demoPassword}).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final role in UserRole.values)
                ActionChip(label: Text(role.label), onPressed: () => onSelect(role)),
            ],
          ),
        ],
      ),
    );
  }
}
