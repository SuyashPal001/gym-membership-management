import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class VoiceLogScreen extends StatefulWidget {
  @override
  _VoiceLogScreenState createState() => _VoiceLogScreenState();
}

class _VoiceLogScreenState extends State<VoiceLogScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isChatMode = false;
  String _currentQuery = '';
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleQuery(String query) {
    setState(() {
      _isChatMode = true;
      _currentQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Gym Assistant", style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isChatMode ? _buildChatInterface() : _buildListeningInterface(),
      ),
    );
  }

  Widget _buildListeningInterface() {
    return Column(
      children: [
        SizedBox(height: 60),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: 150 + (_controller.value * 50),
              height: 150 + (_controller.value * 50),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withOpacity(0.1 + (_controller.value * 0.2)),
              ),
              child: Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                  ),
                  child: Icon(Icons.mic, size: 60, color: Colors.white),
                ),
              ),
            );
          },
        ),
        SizedBox(height: 40),
        Text(
          "Listening...",
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 40),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Try Asking:",
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 24),
                _buildSuggestedQuery("How many members have payments due?"),
                _buildSuggestedQuery("Who checked in this morning?"),
                _buildSuggestedQuery("Log a \$50 payment for Alex Johnson."),
                _buildSuggestedQuery("Which memberships expire this week?"),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestedQuery(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () => _handleQuery(text),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: AppColors.accent, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '"$text"',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatInterface() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(20),
            children: [
              // User Query Bubble
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(left: 40, bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(20).copyWith(topRight: Radius.zero),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    _currentQuery,
                    style: TextStyle(color: AppColors.primaryText, fontSize: 16),
                  ),
                ),
              ),
              
              // AI Response Bubble
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.only(right: 40, bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20).copyWith(topLeft: Radius.zero),
                    border: Border.all(color: AppColors.accent.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: AppColors.accent, size: 16),
                          SizedBox(width: 8),
                          Text("Gym AI", style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        "You have 2 members with pending dues totaling \$100.00. Here are the actionable profiles:",
                        style: TextStyle(color: AppColors.primaryText, fontSize: 16, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),

              // Rich UI Card Result
              _buildAIResultCard("Mike Davis", "Pending: \$50", "3 Days Overdue"),
              SizedBox(height: 12),
              _buildAIResultCard("Jordan Lee", "Pending: \$50", "1 Week Overdue"),
            ],
          ),
        ),
        
        // Chat Input Area
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text("Speak or type a query...", style: TextStyle(color: AppColors.secondaryText)),
                  ),
                ),
              ),
              SizedBox(width: 12),
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.accent,
                child: Icon(Icons.mic, color: Colors.white),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildAIResultCard(String name, String amount, String overdue) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 18)),
              Text(amount, style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          SizedBox(height: 4),
          Text(overdue, style: TextStyle(color: AppColors.secondaryText, fontSize: 14)),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.chat, size: 16),
                  label: Text("WhatsApp"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.campaign, size: 16),
                  label: Text("AI Call", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
