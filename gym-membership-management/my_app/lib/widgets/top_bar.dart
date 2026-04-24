import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../screens/profile_screen.dart';

class TopBar extends StatelessWidget {
  final String? name;
  final bool isFirstVisit;

  const TopBar({Key? key, this.name, this.isFirstVisit = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // PRESTIGE: No fallback text while loading to prevent "Studio Owner" flash
    final displayName = name ?? '';
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 40.0, 20.0, 10.0),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(onBack: () => Navigator.pop(context)),
          ),
        ),
        child: Container(
          color: Colors.transparent, 
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Liquid Gold Avatar Core
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.12), width: 1),
                    ),
                  ),
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primaryBlue.withOpacity(0.15),
                          AppColors.background,
                        ],
                      ),
                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.25), width: 1),
                    ),
                    child: Center(
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            AppColors.primaryBlue,
                          ],
                        ).createShader(bounds),
                        child: const Icon(
                          Icons.fitness_center_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 9), // PRECISION: 9px for ultra-tight density
              // Greeting Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isFirstVisit ? 'Welcome,' : 'Welcome back,',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withOpacity(0.6), // CALIBRATED: Balanced visibility
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.1,
                        height: 1.1,
                      ),
                    ),
                    if (displayName.isNotEmpty)
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [Colors.white, Colors.white.withOpacity(0.9), AppColors.primaryBlue.withOpacity(0.8)],
                          stops: const [0.0, 0.4, 1.0],
                        ).createShader(bounds),
                        child: Text(
                          displayName.toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.1, // Clean stacking
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.white.withOpacity(0.08),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
