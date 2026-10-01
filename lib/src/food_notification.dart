import 'package:flutter/material.dart';

void showFoodNotification(
  BuildContext context, {
  required String title,
  required String message,
  bool success = true,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.white,
      elevation: 8,
      margin: const EdgeInsets.all(14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      duration: const Duration(seconds: 5),
      content: Row(
        children: [
          CircleAvatar(
            backgroundColor: success
                ? const Color(0xFFE0F8ED)
                : const Color(0xFFFFF0DA),
            child: Icon(
              success ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              color: success ? const Color(0xFF079669) : Colors.deepOrange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF253043),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
