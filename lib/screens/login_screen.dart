import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _logoAsset =
      'assets/images/sharknet_hris_logo.png';

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final FormState? form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // AuthGate will detect the authenticated user
      // and open the correct Admin, HR, or Employee portal.
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      String message = 'Unable to sign in.';

      switch (error.code) {
        case 'invalid-email':
          message =
              'Please enter a valid email address.';
          break;

        case 'user-disabled':
          message =
              'This account has been disabled.';
          break;

        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          message =
              'Incorrect email address or password.';
          break;

        case 'too-many-requests':
          message =
              'Too many login attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message =
              'Please check your internet connection.';
          break;

        default:
          message =
              error.message ?? 'Unable to sign in.';
      }

      _showError(message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError('Unexpected error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF9CB5D6),
        fontSize: 14,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: const Color(0xFF76A8EA),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF0F6FF),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFFD9E8FB),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFFD9E8FB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFF2878EC),
          width: 1.8,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.8,
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF397FD8),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets viewInsets =
        MediaQuery.viewInsetsOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (
          BuildContext context,
          BoxConstraints constraints,
        ) {
          final bool wideLayout =
              constraints.maxWidth >= 900;

          if (wideLayout) {
            return _buildWideLayout(
              constraints,
              viewInsets,
            );
          }

          return _buildCompactLayout(
            constraints,
            viewInsets,
          );
        },
      ),
    );
  }

  Widget _buildCompactLayout(
    BoxConstraints constraints,
    EdgeInsets viewInsets,
  ) {
    final double width = constraints.maxWidth;
    final bool verySmallPhone = width < 350;
    final bool smallPhone = width < 390;
    final bool tablet = width >= 600;

    final double horizontalPadding = tablet
        ? 48
        : verySmallPhone
            ? 14
            : 20;

    final double overlap = tablet
        ? 58
        : smallPhone
            ? 34
            : 42;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          bottom: viewInsets.bottom > 0
              ? viewInsets.bottom + 16
              : 0,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _BrandHeader(
                logoAsset: _logoAsset,
                screenWidth: width,
                tablet: tablet,
                smallPhone: smallPhone,
              ),
              Transform.translate(
                offset: Offset(0, -overlap),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 470,
                      ),
                      child: _buildLoginCard(
                        compact: verySmallPhone,
                      ),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(
                  0,
                  -overlap + 16,
                ),
                child: const _SecurityFooter(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(
    BoxConstraints constraints,
    EdgeInsets viewInsets,
  ) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: _DesktopBrandPanel(
            logoAsset: _logoAsset,
          ),
        ),
        Expanded(
          flex: 6,
          child: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                48,
                40,
                48,
                viewInsets.bottom + 40,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 80,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 480,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Welcome back',
                                style: TextStyle(
                                  color: Color(0xFF101828),
                                  fontSize: 32,
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 7),
                              Text(
                                'Sign in to access SharkNet HRIS.',
                                style: TextStyle(
                                  color: Color(0xFF667085),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildLoginCard(
                          compact: false,
                          desktop: true,
                        ),
                        const SizedBox(height: 22),
                        const _SecurityFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard({
    required bool compact,
    bool desktop = false,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 17 : 26,
        desktop ? 30 : compact ? 22 : 27,
        compact ? 17 : 26,
        desktop ? 30 : compact ? 22 : 27,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: desktop
            ? Border.all(
                color: const Color(0xFFE4E7EC),
              )
            : null,
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1A17345C),
            blurRadius: 25,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!desktop) ...<Widget>[
                Text(
                  'Secure Sign In',
                  style: TextStyle(
                    color: const Color(0xFF101828),
                    fontSize: compact ? 19 : 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Use your assigned HRIS account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8EA0B9),
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: compact ? 18 : 23),
              ],
              _fieldLabel('EMAIL ADDRESS'),
              const SizedBox(height: 9),
              TextFormField(
                controller: _emailController,
                enabled: !_isLoading,
                keyboardType:
                    TextInputType.emailAddress,
                textInputAction:
                    TextInputAction.next,
                autofillHints: const <String>[
                  AutofillHints.email,
                  AutofillHints.username,
                ],
                decoration: _inputDecoration(
                  hintText:
                      'e.g. admin@sharknet.ph',
                  prefixIcon: Icons.person_outline,
                ),
                validator: (String? value) {
                  final String email =
                      value?.trim() ?? '';

                  if (email.isEmpty) {
                    return 'Please enter your email address.';
                  }

                  final RegExp emailPattern = RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  );

                  if (!emailPattern.hasMatch(email)) {
                    return 'Please enter a valid email address.';
                  }

                  return null;
                },
              ),
              SizedBox(height: compact ? 16 : 20),
              _fieldLabel('PASSWORD'),
              const SizedBox(height: 9),
              TextFormField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: _hidePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[
                  AutofillHints.password,
                ],
                onFieldSubmitted: (_) => _login(),
                decoration: _inputDecoration(
                  hintText: 'Enter password',
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    tooltip: _hidePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _hidePassword =
                                  !_hidePassword;
                            });
                          },
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons
                              .visibility_off_outlined,
                      color: const Color(0xFF76A8EA),
                    ),
                  ),
                ),
                validator: (String? value) {
                  if (value == null ||
                      value.isEmpty) {
                    return 'Please enter your password.';
                  }

                  return null;
                },
              ),
              SizedBox(height: compact ? 20 : 25),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed:
                      _isLoading ? null : _login,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF2878EC),
                    disabledBackgroundColor:
                        const Color(0xFF9ABFF4),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox.shrink()
                      : const Icon(
                          Icons.login_rounded,
                          color: Colors.white,
                        ),
                  label: _isLoading
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.logoAsset,
    required this.screenWidth,
    required this.tablet,
    required this.smallPhone,
  });

  final String logoAsset;
  final double screenWidth;
  final bool tablet;
  final bool smallPhone;

  @override
  Widget build(BuildContext context) {
    final double topSafeArea =
        MediaQuery.paddingOf(context).top;

    final double logoSize = tablet
        ? 174
        : smallPhone
            ? (screenWidth * 0.29)
                .clamp(96.0, 116.0)
            : (screenWidth * 0.32)
                .clamp(116.0, 142.0);

    final double titleFontSize =
        tablet ? 31 : smallPhone ? 23 : 26;

    final double topPadding =
        topSafeArea + (smallPhone ? 16 : 22);

    final double bottomPadding =
        tablet ? 82 : smallPhone ? 58 : 68;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        topPadding,
        20,
        bottomPadding,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF1554DC),
            Color(0xFF398CFA),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ResponsiveLogo(
            assetPath: logoAsset,
            size: logoSize,
            borderRadius: logoSize * 0.18,
          ),
          SizedBox(
            height: smallPhone ? 10 : 13,
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'SharkNet HRIS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: titleFontSize,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 5),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'People • Payroll • Performance',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFDCEAFF),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopBrandPanel
    extends StatelessWidget {
  const _DesktopBrandPanel({
    required this.logoAsset,
  });

  final String logoAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(54),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF1149C8),
            Color(0xFF388DFA),
          ],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 560,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _ResponsiveLogo(
                assetPath: logoAsset,
                size: 280,
                borderRadius: 46,
              ),
              const SizedBox(height: 28),
              const Text(
                'SharkNet HRIS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Attendance, payroll, leave, and workforce performance in one secure system.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFDCEAFF),
                  fontSize: 17,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsiveLogo extends StatelessWidget {
  const _ResponsiveLogo({
    required this.assetPath,
    required this.size,
    required this.borderRadius,
  });

  final String assetPath;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(borderRadius),
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x38000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            borderRadius - 2,
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.035),
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
              ) {
                return const Center(
                  child: Icon(
                    Icons.badge_outlined,
                    color: Color(0xFF2779EE),
                    size: 58,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SecurityFooter extends StatelessWidget {
  const _SecurityFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        26,
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.shield_outlined,
            color: Color(0xFF8EA6C5),
            size: 20,
          ),
          SizedBox(height: 6),
          Text(
            'Authorized personnel only',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8EA6C5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
