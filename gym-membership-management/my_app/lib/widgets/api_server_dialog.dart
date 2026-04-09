import 'package:flutter/material.dart';

import '../config/api_config.dart';

/// Lets the user save the backend URL on-device (needed for physical phones).
Future<void> showApiServerDialog(BuildContext context) async {
  final controller = TextEditingController(text: ApiConfig.baseUrl);
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('API server'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Use your PC’s Wi‑Fi IP and port (same network as this phone).\n'
                'Example: 192.168.1.10:5000',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: '192.168.x.x:5000',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ApiConfig.clearSavedBaseUrl();
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Clear saved'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ApiConfig.setSavedBaseUrl(controller.text);
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
  if (!context.mounted) return;
  if (saved == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Using API: ${ApiConfig.baseUrl}')),
    );
  }
}
