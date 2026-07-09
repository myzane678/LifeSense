import 'dart:async';

import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/life_entry_provider.dart';
import '../state/profile_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final verifyCodeController = TextEditingController();
  Timer? verifyCodeTimer;
  bool isRegisterMode = false;
  bool isSubmitting = false;
  bool isSendingCode = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool confirmPasswordTouched = false;
  int verifyCodeCooldown = 0;

  @override
  void dispose() {
    verifyCodeTimer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    verifyCodeController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;
    final verifyCode = verifyCodeController.text.trim();
    if (email.isEmpty) {
      showMessage('邮箱不能为空');
      return;
    }
    if (password.isEmpty) {
      showMessage('密码不能为空');
      return;
    }
    if (isRegisterMode && confirmPassword.isEmpty) {
      showMessage('请再次输入密码');
      return;
    }
    if (isRegisterMode && confirmPassword != password) {
      showMessage('两次输入的密码不一致');
      return;
    }
    if (isRegisterMode && verifyCode.isEmpty) {
      showMessage('请输入邮箱验证码');
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final authService = context.read<AuthService>();
      final entryProvider = context.read<LifeEntryProvider>();
      final profileProvider = context.read<ProfileProvider>();
      if (isRegisterMode) {
        await authService.register(
          email: email,
          password: password,
          verifyCode: verifyCode,
        );
      } else {
        await authService.signIn(email: email, password: password);
      }
      await entryProvider.loadEntries();
      await profileProvider.loadCloudProfile();
    } on AGCAuthException catch (error) {
      if (!mounted) return;
      showMessage(authErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      showMessage('网络连接失败，请检查网络后重试。');
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> sendVerifyCode() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      showMessage('请先输入邮箱');
      return;
    }
    if (verifyCodeCooldown > 0) {
      showMessage('验证码已发送，请稍后再试');
      return;
    }
    setState(() => isSendingCode = true);
    try {
      await context.read<AuthService>().requestEmailVerifyCode(email);
      if (!mounted) return;
      startVerifyCodeCooldown();
      showMessage('验证码已发送，请查看邮箱');
    } on AGCAuthException catch (error) {
      if (!mounted) return;
      showMessage(authErrorMessage(error));
    } catch (error) {
      if (!mounted) return;
      showMessage(authErrorText(error));
    } finally {
      if (mounted) setState(() => isSendingCode = false);
    }
  }

  void startVerifyCodeCooldown() {
    verifyCodeTimer?.cancel();
    setState(() => verifyCodeCooldown = 60);
    verifyCodeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (verifyCodeCooldown <= 1) {
        timer.cancel();
        setState(() => verifyCodeCooldown = 0);
      } else {
        setState(() => verifyCodeCooldown--);
      }
    });
  }

  void switchMode() {
    verifyCodeTimer?.cancel();
    emailController.clear();
    passwordController.clear();
    confirmPasswordController.clear();
    verifyCodeController.clear();
    setState(() {
      isRegisterMode = !isRegisterMode;
      confirmPasswordTouched = false;
      verifyCodeCooldown = 0;
      obscurePassword = true;
      obscureConfirmPassword = true;
    });
  }

  bool get shouldShowConfirmPasswordError {
    return isRegisterMode &&
        confirmPasswordTouched &&
        confirmPasswordController.text.isNotEmpty &&
        confirmPasswordController.text != passwordController.text;
  }

  Future<void> continueAsGuest() async {
    setState(() => isSubmitting = true);
    final authService = context.read<AuthService>();
    final entryProvider = context.read<LifeEntryProvider>();
    await authService.continueAsGuest();
    entryProvider.setGuestMode(true);
    await entryProvider.loadGuestEntries();
    setState(() => isSubmitting = false);
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String authErrorMessage(AGCAuthException error) {
    return authErrorText(error);
  }

  String authErrorText(Object error) {
    final text = error.toString();
    if (text.contains('Lock time remaining')) {
      return '验证码发送过于频繁，请稍后再试。';
    }
    if (error is! AGCAuthException) {
      return '网络连接失败，请检查网络后重试。';
    }
    return switch (error.exceptionCode) {
      AuthExceptionCode.invalidEmail => '邮箱格式不正确。',
      AuthExceptionCode.passwordStrengthLow => '密码强度太低，请换一个更复杂的密码。',
      AuthExceptionCode.accountHaveBeenRegistered ||
      AuthExceptionCode.userHaveBeenRegistered => '这个邮箱已经注册过，请直接登录。',
      AuthExceptionCode.signInUserPasswordError ||
      AuthExceptionCode.passwordVerifyCodeError ||
      AuthExceptionCode.userNotRegistered => '邮箱或密码不正确。',
      AuthExceptionCode.verifyCodeError ||
      AuthExceptionCode.verifyCodeFormatError => '验证码不正确。',
      AuthExceptionCode.verifyCodeIntervalLimit => '验证码发送太频繁，请稍后再试。',
      _ => error.message ?? '登录失败，错误码：${error.exceptionCode}。',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'LifeSense',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                isRegisterMode ? '注册账号后，记录会同步到云端。' : '登录账号，同步你的 LifeSense 记录。',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '邮箱'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                onChanged: (_) {
                  if (confirmPasswordTouched) setState(() {});
                },
                obscureText: obscurePassword,
                obscuringCharacter: '*',
                decoration: InputDecoration(
                  labelText: '密码',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => obscurePassword = !obscurePassword),
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              if (isRegisterMode) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  onChanged: (_) =>
                      setState(() => confirmPasswordTouched = true),
                  obscureText: obscureConfirmPassword,
                  obscuringCharacter: '*',
                  decoration: InputDecoration(
                    labelText: '确认密码',
                    errorText: shouldShowConfirmPasswordError
                        ? '两次输入的密码不一致'
                        : null,
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => obscureConfirmPassword = !obscureConfirmPassword,
                      ),
                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: verifyCodeController,
                  decoration: const InputDecoration(labelText: '邮箱验证码'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: isSendingCode || verifyCodeCooldown > 0
                      ? null
                      : sendVerifyCode,
                  child: Text(
                    isSendingCode
                        ? '发送中...'
                        : verifyCodeCooldown > 0
                        ? '重新发送 ${verifyCodeCooldown}s'
                        : '发送验证码',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: isSubmitting ? null : submit,
                child: Text(isRegisterMode ? '注册并登录' : '登录'),
              ),
              TextButton(
                onPressed: isSubmitting ? null : switchMode,
                child: Text(isRegisterMode ? '已有账号，去登录' : '没有账号，去注册'),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 4),
              TextButton(
                onPressed: isSubmitting ? null : continueAsGuest,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                child: const Text('暂不登录，以访客身份使用'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '访客模式下数据仅存本机，换机或卸载后无法恢复。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
