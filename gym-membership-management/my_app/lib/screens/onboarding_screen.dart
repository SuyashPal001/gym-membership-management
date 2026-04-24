import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import 'main_scaffold.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const _gold = Color(0xFFC9992A);
const _surface = Color(0xFF0F1115);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  final _keys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  final _studioNameCtrl = TextEditingController();
  final _ownerNameCtrl  = TextEditingController();
  final _cityCtrl       = TextEditingController();
  final _stateCtrl      = TextEditingController();
  final _phoneCtrl      = TextEditingController();

  int  _page    = 0;
  bool _loading = false;

  late AnimationController _enterCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _fadeAnim  = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    for (final c in [
      _studioNameCtrl, _ownerNameCtrl,
      _cityCtrl, _stateCtrl, _phoneCtrl
    ]) { c.dispose(); }
    super.dispose();
  }

  void _next() {
    if (!_keys[_page].currentState!.validate()) return;
    if (_page == 2) { _launch(); return; }
    _enterCtrl.reset();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuint,
    );
    _enterCtrl.forward();
  }

  void _prev() {
    if (_page == 0) return;
    _enterCtrl.reset();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuint,
    );
    _enterCtrl.forward();
  }

  Future<void> _launch() async {
    setState(() => _loading = true);
    try {
      final setup = await ApiService.setupGym({
        'gym_name':   _studioNameCtrl.text.trim(),
        'owner_name': _ownerNameCtrl.text.trim(),
        'phone':      _phoneCtrl.text.trim(),
        'city':       _cityCtrl.text.trim(),
        'state':      _stateCtrl.text.trim(),
      });
      final id = setup['gym_id']?.toString();
      if (id != null) await AuthService.storeGymId(id);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainScaffold()),
          (_) => false,
        );
      }
    } catch (e) {
      debugPrint('[Onboarding] setup failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 24),
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.error.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e is ApiException ? e.message : 'Setup failed — please try again',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          duration: const Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF382714), Color(0xFF161A22)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _buildPage(
                      formKey : _keys[0],
                      stepNum : '01',
                      headline: 'What should we\ncall your studio?',
                      sub     : 'Give your studio a name and owner.',
                      fields  : [
                        _buildField(
                          label: 'STUDIO NAME',
                          ctrl: _studioNameCtrl,
                          hint: 'e.g. Iron Paradise Gym',
                          icon: Icons.storefront_outlined,
                        ),
                        _buildField(
                          label: 'OWNER NAME',
                          ctrl: _ownerNameCtrl,
                          hint: 'e.g. Rahul Sharma',
                          icon: Icons.person_outline_rounded,
                        ),
                      ],
                    ),
                    _buildPage(
                      formKey : _keys[1],
                      stepNum : '02',
                      headline: 'Where are you\nlocated?',
                      sub     : 'Help your members find you.',
                      fields  : [
                        _buildField(
                          label: 'CITY',
                          ctrl: _cityCtrl,
                          hint: 'e.g. Mumbai',
                          icon: Icons.location_city_outlined,
                        ),
                        _buildField(
                          label: 'STATE / REGION',
                          ctrl: _stateCtrl,
                          hint: 'e.g. Maharashtra',
                          icon: Icons.map_outlined,
                        ),
                      ],
                    ),
                    _buildPage(
                      formKey : _keys[2],
                      stepNum : '03',
                      headline: 'How can we\nreach you?',
                      sub     : 'Share your business contact number.',
                      fields  : [
                        _buildField(
                          label: 'PHONE NUMBER',
                          ctrl: _phoneCtrl,
                          hint: 'e.g. 9876543210',
                          icon: Icons.phone_outlined,
                          keyboard: TextInputType.phone,
                          isPhone: true,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildCta(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Top Bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: back + brand + counter
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedOpacity(
                opacity: _page > 0 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: GestureDetector(
                  onTap: _page > 0 ? _prev : null,
                  child: Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.08), width: 0.5),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white70, size: 14),
                  ),
                ),
              ),
              if (_page > 0) const SizedBox(width: 14),
              Text(
                'GYM OPS',
                style: GoogleFonts.outfit(
                  color: _gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.07), width: 0.5),
                ),
                child: Text(
                  '${_page + 1}  OF  3',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Three-segment progress bar
          Row(
            children: List.generate(3, (i) {
              final active = i == _page;
              final done   = i < _page;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    height: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: active
                          ? _gold
                          : done
                              ? _gold.withOpacity(0.3)
                              : Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── Page ─────────────────────────────────────────────────────────────────

  Widget _buildPage({
    required GlobalKey<FormState> formKey,
    required String stepNum,
    required String headline,
    required String sub,
    required List<Widget> fields,
  }) {
    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero step number (Growth-screen style) ─────────────────
                Text(
                  stepNum,
                  style: GoogleFonts.outfit(
                    fontSize: 100,
                    fontWeight: FontWeight.w900,
                    color: _gold.withOpacity(0.25),
                    height: 1,
                    letterSpacing: -4,
                  ),
                ),

                const SizedBox(height: 4),

                // ── Headline ───────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    headline,
                    style: GoogleFonts.outfit(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Subtitle ───────────────────────────────────────────────
                Text(
                  sub,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 36),

                // ── Gold-bar section label ─────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 2,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _gold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'ENTER YOUR DETAILS',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Fields ─────────────────────────────────────────────────
                ...fields,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Input Field ──────────────────────────────────────────────────────────

  Widget _buildField({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool isPhone = false,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(
            children: [
              Icon(icon,
                  color: Colors.white.withOpacity(0.6), size: 11),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.75),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Input
          TextFormField(
            controller: ctrl,
            keyboardType: keyboard,
            inputFormatters: formatters,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.1,
            ),
            cursorColor: _gold,
            cursorWidth: 1.5,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              hintText: hint,
              hintStyle: GoogleFonts.outfit(
                color: Colors.white.withOpacity(0.4),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.07), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _gold, width: 1.2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: AppColors.error.withOpacity(0.55), width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.error, width: 1.2),
              ),
              errorStyle: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.error.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'This field is required';
              if (isPhone &&
                  (v.length < 10 || !RegExp(r'^\d+$').hasMatch(v))) {
                return 'Enter a valid 10-digit number';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ─── CTA + Footer ─────────────────────────────────────────────────────────

  Widget _buildCta() {
    final isLast = _page == 2;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider
          Container(
            height: 0.5,
            margin: const EdgeInsets.only(bottom: 20),
            color: Colors.white.withOpacity(0.06),
          ),

          // Full-width CTA — gold outlined premium style
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast ? _gold : Colors.transparent,
                foregroundColor: isLast ? Colors.black : Colors.white,
                disabledBackgroundColor: _gold.withOpacity(0.35),
                elevation: 0,
                side: isLast
                    ? BorderSide.none
                    : const BorderSide(color: _gold, width: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ).copyWith(
                overlayColor: WidgetStateProperty.all(
                  isLast
                      ? Colors.black.withOpacity(0.08)
                      : _gold.withOpacity(0.08),
                ),
              ),
              child: _loading
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: isLast ? Colors.black : _gold,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLast ? 'LAUNCH STUDIO' : 'CONTINUE',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: isLast ? Colors.black : _gold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          isLast
                              ? Icons.rocket_launch_rounded
                              : Icons.arrow_forward_rounded,
                          size: 16,
                          color: isLast ? Colors.black : _gold,
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 14),

          // Hint row
          Center(
            child: Text(
              isLast
                  ? 'Your studio goes live instantly'
                  : 'You can update these later from settings',
              style: GoogleFonts.outfit(
                color: Colors.white.withOpacity(0.22),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
