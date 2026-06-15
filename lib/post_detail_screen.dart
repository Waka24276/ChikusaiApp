import 'package:flutter/material.dart';
import 'dart:convert'; // For base64Decode
import 'package:flutter/foundation.dart'; // kIsWeb を使うため

import 'date_helpers.dart'; // インポートパスを修正
class PostDetailScreen extends StatelessWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final String classInfo = post['class'] ?? '';
    final String deductionPoints = post['deductionPoints'] ?? '';
    final String deductionReason = post['deductionReason'] ?? '';
    final String remarks = post['remarks'] ?? '';
    final bool isHidden = post['isHidden'] ?? false;
    String timestamp = '';
    try {
      if (post['timestamp'] != null) {
        final dt = DateTime.parse(post['timestamp']!);
        timestamp = dt.toLocal().toString().substring(0, 16).replaceAll('-', '/');
      }
    } catch (e) {
      timestamp = '日時不明';
    }
    final String name = post['name'] ?? '不明';
    final String imagePath = post['imagePath'] ?? '';
    final String hiddenReasonImage = post['hiddenReasonImage'] ?? '';
    final String restoreReason = post['restoreReason'] ?? ''; // 新しく追加された復元理由
    final List<dynamic> history = post['statusHistory'] ?? [];

    // 議論状況と期限の計算
    final String? status = post['discussionStatus'];
    final String? discussionTimestampStr = post['discussionTimestamp'];
    String statusLabel = '';
    String remainingTimeText = '';
    Color statusColor = Colors.grey;

    bool isExpired = false;
    if (status == 'deduction') {
      if (discussionTimestampStr != null) {
        try {
          final dt = DateTime.parse(discussionTimestampStr);
          final deadline = addWorkingDays(dt, 3).add(const Duration(days: 1)); // 期限は3営業日後の終わり
          final remaining = deadline.difference(DateTime.now());
          if (remaining.isNegative) {
            isExpired = true;
          } else {
            remainingTimeText = '残り ${remaining.inDays}日 ${remaining.inHours % 24}時間 ${remaining.inMinutes % 60}分';
          }
        } catch (_) {}
      }
      if (!isExpired) {
        statusLabel = '口頭可能 (審議中)';
        statusColor = Colors.red;
      }
    } else if (status == 'cancelled') {
      try {
        // 詳細画面でも同様に「減点確定」イベントを起点に期限を計算
        final cancelEvent = history.reversed.firstWhere((e) => e is Map && e['type'] == 'finalized_deduction', orElse: () => null);
        if (cancelEvent != null && cancelEvent['timestamp'] != null) {
          final dt = DateTime.parse(cancelEvent['timestamp']);
          isExpired = DateTime.now().isAfter(addWorkingDays(dt, 3).add(const Duration(days: 1)));
        }
      } catch (_) {}
      if (!isExpired) {
        statusLabel = '口頭可能';
        statusColor = Colors.orange;
      }
    } else if (isHidden && status == null) {
      try {
        final archiveEvent = history.reversed.firstWhere((e) => e is Map && e['type'] == 'archived_undiscussed', orElse: () => null);
        if (archiveEvent != null && archiveEvent['timestamp'] != null) {
          final dt = DateTime.parse(archiveEvent['timestamp']);
          isExpired = DateTime.now().isAfter(addWorkingDays(dt, 3).add(const Duration(days: 1)));
        }
      } catch (_) {}
      
      if (!isExpired) {
        statusLabel = '口頭可能';
        statusColor = Colors.orange; // 視認性のため少し濃い色
      }
    }

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
            if (statusLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(4)),
                    child: Text(statusLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  if (remainingTimeText.isNotEmpty) ...[const SizedBox(width: 8), Text(remainingTimeText, style: TextStyle(fontSize: 13, color: statusColor, fontWeight: FontWeight.bold))],
                ],
              ),
            ],
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
              const Text('取り消し時の弁明書写真:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 8),
              _buildDetailImage(hiddenReasonImage),
            ],
            if (history.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              _buildTimeline(history),
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
          
          try {
            if (imagePath.isEmpty) {
              return const Icon(Icons.image_not_supported, size: 100);
            }
            if (imagePath.startsWith('http')) {
              return Image.network(
                imagePath,
                fit: BoxFit.cover,
              );
            }
            return Image.memory(
              base64Decode(imagePath),
              fit: BoxFit.cover,
              cacheWidth: cacheSize.toInt() > 0 ? cacheSize.toInt() : null,
            );
          } catch (_) {
            return const Icon(Icons.broken_image, size: 100);
          }
        },
      ),
    );
  }

  Widget _buildTimeline(List<dynamic> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ステータス変更履歴', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 16),
        ...history.asMap().entries.map((entry) {
          final int index = entry.key;
          final Map<String, dynamic> event = Map<String, dynamic>.from(entry.value);
          final bool isLast = index == history.length - 1;

          String typeLabel = '';
          IconData icon = Icons.circle;
          Color color = Colors.grey;

          switch (event['type']) {
            case 'created':
              typeLabel = '減点警告書';
              icon = Icons.add_circle_outline;
              color = Colors.blue;
              break;
            case 'discussion_started':
              typeLabel = '減点通知書発行う';
              icon = Icons.forum_outlined;
              color = Colors.red;
              break;
            case 'finalized_deduction':
              typeLabel = '減点確定';
              icon = Icons.check_circle;
              color = Colors.orange;
              break;
            case 'cancelled':
              typeLabel = '減点取り消し確定';
              icon = Icons.not_interested;
              color = Colors.green;
              break;
            case 'archived_undiscussed':
              typeLabel = '減点確定';
              icon = Icons.archive_outlined;
              color = Colors.orange;
              break;
            case 'archived':
              typeLabel = '減点通知書発行';
              icon = Icons.undo;
              color = Colors.blueGrey;
              break;
          }

          final String eventTime = event['timestamp'] != null
              ? DateTime.parse(event['timestamp']).toLocal().toString().substring(5, 16).replaceAll('-', '/')
              : '';

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(icon, size: 20, color: color),
                  if (!isLast) Container(width: 2, height: 40, color: Colors.grey[300]),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(typeLabel, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                        Text(eventTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    if (event['reason'] != null && event['reason'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(event['reason'], style: const TextStyle(fontSize: 14, color: Colors.black87)),
                      ),
                    if (event['tags'] != null && (event['tags'] as List).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: (event['tags'] as List).map((tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blueGrey[200]!),
                            ),
                            child: Text(tag.toString(), style: TextStyle(fontSize: 11, color: Colors.blueGrey[700])),
                          )).toList(),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }
}