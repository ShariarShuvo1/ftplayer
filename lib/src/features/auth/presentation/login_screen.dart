import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbars.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/card_container.dart';
import '../../../state/auth/auth_controller.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const path = '/login';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.isLoading;
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'Login',
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                MediaQuery.of(context).size.height -
                (kToolbarHeight + MediaQuery.of(context).padding.top + 24),
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Welcome back', style: textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(
                  'Use your account credentials to continue.',
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                CardContainer(
                  child: FormBuilder(
                    key: _formKey,
                    child: Column(
                      children: [
                        FormBuilderTextField(
                          name: 'email',
                          enabled: !isLoading,
                          autofillHints: const [AutofillHints.email],
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                          validator: FormBuilderValidators.compose([
                            FormBuilderValidators.required(),
                            FormBuilderValidators.email(),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        FormBuilderTextField(
                          name: 'password',
                          enabled: !isLoading,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: isLoading
                                  ? null
                                  : () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: FormBuilderValidators.compose([
                            FormBuilderValidators.required(),
                            FormBuilderValidators.minLength(6),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Login',
                  icon: Icons.login,
                  isLoading: isLoading,
                  onPressed: isLoading
                      ? null
                      : () async {
                          final state = _formKey.currentState;
                          if (state == null) return;
                          if (!state.saveAndValidate()) return;
                          final values = state.value;
                          final email = (values['email'] as String).trim();
                          final password = (values['password'] as String);

                          try {
                            final message = await ref
                                .read(authControllerProvider.notifier)
                                .login(email: email, password: password);
                            if (!context.mounted) return;
                            AppSnackbars.showSuccess(context, message);
                          } catch (e) {
                            if (!context.mounted) return;
                            AppSnackbars.showError(
                              context,
                              ApiError.from(e).message,
                            );
                          }
                        },
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'Create account',
                  icon: Icons.person_add_alt_1_outlined,
                  onPressed: isLoading
                      ? null
                      : () => context.go(SignupScreen.path),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
