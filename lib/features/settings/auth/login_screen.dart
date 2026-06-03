import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/providers/server_url_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController();
  
  bool _isLoginMode = true;
  bool _showPassword = false;
  bool _showAdvanced = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _isLoginMode = _tabController.index == 0;
      });
    });
    
    // Pre-fill server URL controller with current config
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _serverUrlController.text = ref.read(serverUrlProvider);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Save server URL if custom URL is shown and changed
    final customUrl = _serverUrlController.text.trim();
    if (customUrl.isNotEmpty) {
      await ref.read(serverUrlProvider.notifier).setUrl(customUrl);
    }

    final notifier = ref.read(authProvider.notifier);
    if (_isLoginMode) {
      await notifier.login(_emailController.text, _passwordController.text);
    } else {
      await notifier.register(_emailController.text, _passwordController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);

    // Watch for success (authenticated) state to close screen
    ref.listen<AuthState>(authProvider, (previous, next) {
      next.maybeWhen(
        authenticated: (_, __) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isLoginMode ? 'Welcome back! 👋' : 'Account created successfully! 🚀'),
              backgroundColor: theme.colorScheme.primary,
            ),
          );
          context.pop();
        },
        error: (message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        },
        orElse: () {},
      );
    });

    final isLoading = authState.maybeWhen(loading: () => true, orElse: () => false);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand / Logo area
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_sync_rounded,
                            size: 64,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'StudyHabit Sync',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Access your study history anywhere',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Custom Card for Auth Form
                    Card(
                      elevation: 4,
                      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Sliding Tabs
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                indicator: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                labelColor: theme.colorScheme.primary,
                                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                tabs: const [
                                  Tab(text: 'Log In'),
                                  Tab(text: 'Sign Up'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Email Field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              enabled: !isLoading,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_showPassword,
                              textInputAction: TextInputAction.done,
                              enabled: !isLoading,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outlined),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showPassword = !_showPassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Advanced / Server URL (Expandable)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                _showAdvanced ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                color: theme.colorScheme.primary,
                              ),
                              title: Text(
                                'Self-Hosted / Advanced',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  _showAdvanced = !_showAdvanced;
                                });
                              },
                            ),
                            
                            if (_showAdvanced) ...[
                              TextFormField(
                                controller: _serverUrlController,
                                keyboardType: TextInputType.url,
                                enabled: !isLoading,
                                decoration: InputDecoration(
                                  labelText: 'Server URL',
                                  helperText: 'Default: https://studyhabit.schuelken.uk',
                                  prefixIcon: const Icon(Icons.dns_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                validator: (value) {
                                  if (value != null && value.trim().isNotEmpty) {
                                    if (!value.startsWith('http://') && !value.startsWith('https://')) {
                                      return 'URL must start with http:// or https://';
                                    }
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            const SizedBox(height: 8),

                            // Submit Button
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: isLoading ? null : _submit,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      _isLoginMode ? 'Log In' : 'Create Account',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Back / Offline Link
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Continue Offline'),
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
