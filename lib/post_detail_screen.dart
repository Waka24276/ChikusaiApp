import 'package:flutter/material.dart';
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
    final String hiddenReasonImage = post['hiddenReasonImage'] ?? '';

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
            if (hiddenReasonImage.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text('非表示理由の写真:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 8),
              _buildDetailImage(hiddenReasonImage),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailImage(String imagePath) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 画面幅に合わせてキャッシュサイズを最適化（メモリ節約）
          final double cacheSize = constraints.maxWidth * 2;
          
          if (kIsWeb) {
            try {
              return Image.memory(
                base64Decode(imagePath),
                fit: BoxFit.cover,
                cacheWidth: cacheSize.toInt(),
              );
            } catch (_) {
              return const Icon(Icons.broken_image, size: 100);
            }
          }
          return Image.memory(
            base64Decode(imagePath),
            fit: BoxFit.cover,
            cacheWidth: cacheSize.toInt(),
            errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 100),
          );
        },
      ),
    );
  }
}