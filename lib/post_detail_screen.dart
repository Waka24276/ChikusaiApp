import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert'; // For base64Decode
import 'package:flutter/foundation.dart'; // kIsWeb を使うため

class PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final String classInfo = post['class'] ?? '';
    final String deductionPoints = post['deductionPoints'] ?? '';
    final String deductionReason = post['deductionReason'] ?? '';
    final String remarks = post['remarks'] ?? '';
    final String timestamp = post['timestamp'] != null
        ? DateTime.parse(post['timestamp']!)
            .toLocal()
            .toString()
            .substring(0, 16) // YYYY-MM-DD HH:MM
            .replaceAll('-', '/')
        : '';
    final String name = post['name'] ?? '不明';
    final String imagePath = post['imagePath'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('投稿詳細'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('クラス: $classInfo', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$deductionPoints点', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('理由: $deductionReason', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('備考: ${remarks.isNotEmpty ? remarks : "なし"}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('日時: $timestamp', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('投稿者: $name', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            if (imagePath.isNotEmpty)
              _buildDetailImage(imagePath),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailImage(String imagePath) {
    if (kIsWeb) {
      try {
        return Image.memory(base64Decode(imagePath), fit: BoxFit.cover);
      } catch (_) {
        return const Icon(Icons.broken_image, size: 100);
      }
    }
    // アプリ版ではBase64とファイルパスの両方を試行
    try {
      final bytes = base64Decode(imagePath);
      return Image.memory(bytes, fit: BoxFit.cover);
    } catch (_) {
      return Image.file(File(imagePath), fit: BoxFit.cover, 
          errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 100));
    }
  }
}