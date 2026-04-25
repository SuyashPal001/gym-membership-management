import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/growth_models.dart';
import '../services/api_service.dart';
import '../services/api_exception.dart';

class MembersGrowthScreen extends StatefulWidget {
  const MembersGrowthScreen({Key? key}) : super(key: key);

  @override
  _MembersGrowthScreenState createState() => _MembersGrowthScreenState();
}

class _MembersGrowthScreenState extends State<MembersGrowthScreen> {
  GrowthData? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiService.fetchMemberGrowth();
      if (mounted) setState(() { _data = data; _isLoading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Something went wrong'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'MEMBERS GROWTH',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.secondaryText, size: 20),
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryBlue, strokeWidth: 2))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: AppColors.error.withOpacity(0.6), size: 48),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: AppColors.secondaryText)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('RETRY', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    final monthly = d.monthly;
    final totals = d.totals;

    final currNew = monthly.length >= 1 ? monthly.last.newMembers : 0;
    final prevNew = monthly.length >= 2 ? monthly[monthly.length - 2].newMembers : 0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Neural Pulse Header (Profile Sync)
          _buildNeuralHeader(totals, currNew, prevNew),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                _sectionLabel('GROWTH TRAJECTORY'),
                const SizedBox(height: 20),
                _buildRoyalChart(monthly),
                
                const SizedBox(height: 32),
                _sectionLabel('MONTHLY ENROLLMENT TRENDS'),
                const SizedBox(height: 20),
                _buildMonthRow(monthly),
                
                const SizedBox(height: 32),
                _sectionLabel('STUDIO COMPOSITION'),
                const SizedBox(height: 20),
                _buildStatusGrid(totals),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Neural Header ────────────────────────────────────────────────────────

  Widget _buildNeuralHeader(GrowthTotals totals, int currNew, int prevNew) {
    final hasPrev = prevNew > 0;
    final momPct = hasPrev ? ((currNew - prevNew) / prevNew * 100) : 0.0;
    final isPositive = currNew >= prevNew;

    String momLabel;
    if (!hasPrev && currNew > 0) {
      momLabel = '+$currNew new';
    } else if (!hasPrev) {
      momLabel = '--';
    } else {
      momLabel = '${momPct >= 0 ? '+' : ''}${momPct.toStringAsFixed(1)}%';
    }

    final retentionPct = totals.total > 0
        ? ((totals.active + totals.trial) / totals.total * 100).round()
        : 0;
    const gold = Color(0xFFC9992A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVE STUDIO COUNT',
                style: GoogleFonts.outfit(
                  color: gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isPositive ? AppColors.emerald : AppColors.error).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.north_east_rounded : Icons.south_east_rounded,
                      color: isPositive ? AppColors.emerald : AppColors.error,
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      momLabel,
                      style: GoogleFonts.outfit(
                        color: isPositive ? AppColors.emerald : AppColors.error,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            totals.total.toString(),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 72,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _headerMetric('RECRUITED', currNew.toString(), AppColors.infoBlue),
              const SizedBox(width: 32),
              _headerMetric('RETENTION', '$retentionPct%', AppColors.emerald),
              const SizedBox(width: 32),
              _headerMetric('LIFE TIME VALUE', '₹${totals.totalLtv.toInt()}', gold),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ─── Royal Chart ───────────────────────────────────────────────────────────

  Widget _buildRoyalChart(List<MonthlyGrowth> monthly) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1115),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
      ),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      child: CustomPaint(
        painter: _RoyalAreaPainter(
          values: monthly.map((m) => m.newMembers).toList(),
          labels: monthly.map((m) => m.monthShort).toList(),
        ),
      ),
    );
  }

  // ─── Month Momentum ────────────────────────────────────────────────────────

  Widget _buildMonthRow(List<MonthlyGrowth> monthly) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (int i = 0; i < monthly.length; i++) ...[
            _buildBoutiqueMonthCard(
              monthly[i],
              isCurrent: i == monthly.length - 1,
            ),
            if (i < monthly.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildBoutiqueMonthCard(MonthlyGrowth m, {bool isCurrent = false}) {
    const gold = Color(0xFFC9992A);
    return Container(
      width: 120,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? gold.withOpacity(0.4) : Colors.white.withOpacity(0.05),
          width: isCurrent ? 1.0 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.monthShort.toUpperCase(),
            style: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            m.newMembers.toString(),
            style: GoogleFonts.outfit(
              color: isCurrent ? gold : Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'JOINED',
            style: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Composition Grid ──────────────────────────────────────────────────────

  Widget _buildStatusGrid(GrowthTotals t) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildRoyalModule('ACTIVE', t.active, t.total, AppColors.emerald)),
            const SizedBox(width: 12),
            Expanded(child: _buildRoyalModule('TRIAL', t.trial, t.total, AppColors.infoBlue)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildRoyalModule('EXPIRED', t.expired, t.total, AppColors.error)),
            const SizedBox(width: 12),
            Expanded(child: _buildRoyalModule('INACTIVE', t.inactive, t.total, const Color(0xFFA855F7))),
          ],
        ),
      ],
    );
  }

  Widget _buildRoyalModule(String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 0.5),
        gradient: RadialGradient(
          center: const Alignment(-0.8, -0.8),
          radius: 1.5,
          colors: [
            color.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            count.toString(),
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white.withOpacity(0.03),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 2,
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFFC9992A),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ─── Royal Area Painter ───────────────────────────────────────────────────────

class _RoyalAreaPainter extends CustomPainter {
  final List<int> values;
  final List<String> labels;

  _RoyalAreaPainter({required this.values, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxVal == 0) return;

    final path = Path();
    final fillPath = Path();
    
    const horizontalPadding = 24.0;
    const bottomBuffer = 24.0; // Room for labels
    
    final width = size.width - (horizontalPadding * 2);
    final height = size.height - bottomBuffer; // The height available for the graph itself
    final stepX = width / (values.length - 1);

    const gold = Color(0xFFC9992A);

    for (int i = 0; i < values.length; i++) {
      final x = horizontalPadding + i * stepX;
      // Letting the graph go higher (1.1x instead of 1.2x)
      final y = height - (values[i] / (maxVal * 1.1)) * height;
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = horizontalPadding + (i - 1) * stepX;
        final prevY = height - (values[i - 1] / (maxVal * 1.1)) * height;
        
        // Cubic bezier for royal smooth curves
        final cp1x = prevX + (x - prevX) / 2;
        final cp1y = prevY;
        final cp2x = prevX + (x - prevX) / 2;
        final cp2y = y;
        
        path.cubicTo(cp1x, cp1y, cp2x, cp2y, x, y);
        fillPath.cubicTo(cp1x, cp1y, cp2x, cp2y, x, y);
      }
      
      if (i == values.length - 1) {
        fillPath.lineTo(x, height);
        fillPath.close();
      }
    }

    // Paint the floor gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        gold.withOpacity(0.2),
        gold.withOpacity(0.0),
      ],
    );
    canvas.drawPath(fillPath, Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, height)));

    // Paint the primary royal curve
    canvas.drawPath(
      path,
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Paint Data Nodes
    for (int i = 0; i < values.length; i++) {
      final x = horizontalPadding + i * stepX;
      final y = height - (values[i] / (maxVal * 1.2)) * height;
      final isLast = i == values.length - 1;
      
      if (isLast) {
        // Glowing Pulse Node
        canvas.drawCircle(Offset(x, y), 8, Paint()..color = gold.withOpacity(0.2));
        canvas.drawCircle(Offset(x, y), 4, Paint()..color = gold);
        canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(Offset(x, y), 3, Paint()..color = gold);
      }

      // Month Label
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i].toUpperCase(),
          style: GoogleFonts.outfit(
            color: Colors.white.withOpacity(0.4),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, height + 10));
    }
  }

  @override
  bool shouldRepaint(covariant _RoyalAreaPainter old) => old.values != values;
}
