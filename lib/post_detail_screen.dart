import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'home_screen.dart'; 
import 'package:flutter/cupertino.dart';

import 'date_helpers.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Map<String, dynamic> _post;
  Stream<DocumentSnapshot>? _postStream;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _migrateOldImageIfNeeded();

    // リアルタイムで投稿の変更を監視
    _postStream = FirebaseFirestore.instance.collection('posts').doc(_post['id'] as String).snapshots();
    _postStream!.listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = Map<String, dynamic>.from(snapshot.data() as Map<String, dynamic>);
        setState(() => _post = {...data, 'id': snapshot.id, '_cachedUint8List': _post['_cachedUint8List']});
      }
    });
  }

  /// 古い形式(Base64)の画像を検出し、新しいURL形式に自動で変換・更新する
  Future<void> _migrateOldImageIfNeeded() async {
    final String imagePath = _post['imagePath'] ?? '';
    // Base64形式の画像（httpで始まらない）で、まだ変換処理中でない場合
    if (imagePath.isNotEmpty && !imagePath.startsWith('http')) {
      if (!mounted) return;
      setState(() => _isUploading = true); // 変換中インジケーターを表示

      try {
        final bytes = base64Decode(imagePath);
        _post['_cachedUint8List'] = bytes; // まずはメモリにキャッシュして表示

        // Firebase Storageにアップロードして新しいURLを取得
        final ref = FirebaseStorage.instance.ref().child('post_images/${_post['id']}-${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        final newImageUrl = await ref.getDownloadURL();

        // Firestoreの投稿データを新しい画像URLで更新
        await FirebaseFirestore.instance.collection('posts').doc(_post['id'] as String).update({
          'imagePath': newImageUrl,
        });

      } catch (e) {
        debugPrint('画像形式の自動変換に失敗しました: $e');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String classInfo = _post['class'] ?? '';
    final String deductionPoints = _post['deductionPoints'] ?? '';
    final String deductionReason = _post['deductionReason'] ?? '';
    final String remarks = _post['remarks'] ?? '';
    final bool isHidden = _post['isHidden'] ?? false;
    String timestamp = '';
    try {
      if (_post['timestamp'] != null) {
        final dt = DateTime.parse(_post['timestamp']!);
        timestamp = dt.toLocal().toString().substring(0, 16).replaceAll('-', '/');
      }
    } catch (e) {
      timestamp = '日時不明';
    }
    final String name = _post['name'] ?? '不明';
    final String imagePath = _post['imagePath'] ?? '';
    final String hiddenReasonImage = _post['hiddenReasonImage'] ?? '';
    final List<dynamic> history = _post['statusHistory'] ?? [];

    final String? status = _post['discussionStatus'];
    final String? discussionTimestampStr = _post['discussionTimestamp'];
    String statusLabel = '';
    String remainingTimeText = '';
    Color statusColor = Colors.grey;

    bool isExpired = false;

    String? refTimestampStr = discussionTimestampStr;
    if (refTimestampStr == null) {
      final refEvent = history.reversed.firstWhere(
        (e) => e is Map && (e['type'] == 'finalized_deduction' || e['type'] == 'archived_undiscussed' || e['type'] == 'discussion_started'),
        orElse: () => null
      );
      if (refEvent != null) refTimestampStr = refEvent['timestamp'] as String?;
    }
    refTimestampStr ??= _post['timestamp'];

    if (refTimestampStr != null) {
      try {
        final dt = DateTime.parse(refTimestampStr);
        final deadline = addWorkingDays(dt, 3).add(const Duration(days: 1));
        final remaining = deadline.difference(DateTime.now());
        if (remaining.isNegative) {
          isExpired = true;
        } else if (status == 'deduction' || (isHidden && status == null)) {
          final lastDay = deadline.subtract(const Duration(days: 1));
          remainingTimeText = '${lastDay.month}/${lastDay.day}まで';
        }
      } catch (_) {}
    }

    // 表示判定：審議中(deduction) または 初期アーカイブ(status==null) で期限内の場合
    // 減点確定(finalized)は含めないように修正
    if ((status == 'deduction' || (isHidden && status == null)) && !isExpired) {
      statusLabel = '口頭可能';
      statusColor = Colors.pink;
    } else if (status == 'finalized') {
      statusLabel = '減点確定';
      statusColor = Colors.orange;
    } else if (status == 'cancelled') {
      statusLabel = '減点取り消し確定';
      statusColor = Colors.green;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('投稿詳細'),
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _addOrUpdateImage, tooltip: '写真を追加/変更'),
        ],
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
            // --- 理由と点数を変更するボタンを追加 ---
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isUploading ? null : _editDeductionDetails,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('理由/点数を変更'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blueGrey,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
            ),
            // --- ここまで ---
            Text('備考: ${remarks.isNotEmpty ? remarks : "なし"}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('日時: $timestamp', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('投稿者: $name', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            if (imagePath.isNotEmpty)
              _buildDetailImage(imagePath)
            else
              Center(
                child: OutlinedButton.icon(
                  onPressed: _isUploading ? null : _addOrUpdateImage,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('写真を追加'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.grey[700]),
                ),
              ),
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

  Future<void> _editDeductionDetails() async {
    // '1年1組' から '1' を抽出
    final gradeString = (_post['class']?.toString() ?? '1').substring(0, 1);
    final int grade = int.tryParse(gradeString) ?? 1;

    // 現在の理由と一致するViolationItemを探す
    final categories = getViolationDataForGrade(grade);
    ViolationItem? currentViolation;
    int initialCategoryIndex = 0;
    for (int i = 0; i < categories.length; i++) {
      for (var item in categories[i].items) {
        if (item.name == _post['deductionReason']) {
          currentViolation = item;
          initialCategoryIndex = i;
          break;
        }
      }
      if (currentViolation != null) break;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _ReasonSelectionDialog(
            categories: categories,
            initialCategoryIndex: initialCategoryIndex,
            initialViolation: currentViolation,
            initialPoints: int.tryParse(_post['deductionPoints']?.toString() ?? '1') ?? 1,
          ),
    );

    if (result != null) {
      final newReason = result['reason'] as String;
      final newPoints = result['points'] as int;

      setState(() => _isUploading = true);
      try {
        await FirebaseFirestore.instance.collection('posts').doc(_post['id'] as String).update({
          'deductionReason': newReason,
          'deductionPoints': newPoints.toString(),
          'statusHistory': FieldValue.arrayUnion([{
            'type': 'edited',
            'timestamp': DateTime.now().toIso8601String(),
            'reason': '理由/点数を変更 (旧: ${_post['deductionReason']} / ${_post['deductionPoints']}点)',
          }]),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('減点の理由と点数を更新しました。')),
          );
        }
      } catch (e) {
        debugPrint('更新エラー: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新に失敗しました。')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _addOrUpdateImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await pickedFile.readAsBytes();
      final ref = FirebaseStorage.instance.ref().child('post_images/${_post['id']}-${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final imageUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('posts').doc(_post['id'] as String).update({
        'imagePath': imageUrl,
      });

      if (mounted) setState(() {
        _post['imagePath'] = imageUrl;
        _post.remove('_cachedUint8List'); // 古いキャッシュを削除
      });
    } catch (e) {
      debugPrint('写真のアップロードエラー: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('エラーが発生しました。')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _buildDetailImage(String imagePath) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: _isUploading ? null : _addOrUpdateImage,
        child: Stack(
          alignment: Alignment.center,
          children: [
            LayoutBuilder(
        builder: (context, constraints) {
          final Uint8List? cachedBytes = _post['_cachedUint8List'] as Uint8List?;
          // 画面幅に合わせてキャッシュサイズを最適化（メモリ節約）
          final int? cacheWidth = (constraints.maxWidth > 0 && constraints.maxWidth.isFinite)
              ? (constraints.maxWidth * 2.0).toInt()
              : null;

          try {
            if (imagePath.isEmpty) {
              return const Icon(Icons.image_not_supported, size: 100);
            }
            if (imagePath.startsWith('http')) {
              return Image.network(
                imagePath,
                fit: BoxFit.contain,
                cacheWidth: cacheWidth,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Image.network error: $error'); // エラーをコンソールに出力
                  return const Icon(Icons.broken_image, size: 100, color: Colors.red);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
              );
            }
            // Base64形式の文字列をデコードして表示
            // ホーム画面と同様に、まずキャッシュされたバイトデータ（_cachedUint8List）を試す
            if (cachedBytes != null && cachedBytes.isNotEmpty) {
              return Image.memory(
                cachedBytes,
                fit: BoxFit.contain,
                cacheWidth: cacheWidth,
              );
            }
            // キャッシュがない場合、imagePathがBase64文字列であると仮定してデコードを試みる
            try {
              final bytes = base64Decode(imagePath);
              return Image.memory(
                bytes,
                fit: BoxFit.contain,
                cacheWidth: cacheWidth,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100, color: Colors.red),
              );
            } catch (e) {
              return const Icon(Icons.broken_image, size: 100); // デコード失敗
            }
          } catch (e) {
            return const Icon(Icons.broken_image, size: 100);
          }
        },
      ),
            if (_isUploading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            else
              const Icon(
                Icons.edit,
                color: Colors.white,
                size: 40,
                shadows: [Shadow(color: Colors.black, blurRadius: 15.0)],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(List<dynamic> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('履歴', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
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
              typeLabel = '減点通知書発行';
              icon = Icons.forum_outlined;
              color = const Color.fromARGB(255, 228, 125, 66);
              break;
            case 'finalized_deduction':
              typeLabel = '減点確定';
              icon = Icons.check_circle;
              color = const Color.fromARGB(255, 211, 36, 12);
              break;
            case 'edited':
              typeLabel = '内容変更';
              icon = Icons.edit;
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
              color = const Color.fromARGB(255, 207, 43, 14);
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
                    if (event['tags'] is List && (event['tags'] as List).isNotEmpty)
                      Builder(builder: (context) {
                        final List<dynamic> tags = event['tags'];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: tags.map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blueGrey[200]!),
                              ),
                              child: Text(tag.toString(), style: TextStyle(fontSize: 11, color: Colors.blueGrey[700])),
                            )).toList(),
                          ),
                        );
                      }),
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

/// 減点理由と点数を選択するためのダイアログ
class _ReasonSelectionDialog extends StatefulWidget {
  final List<ViolationCategory> categories;
  final int initialCategoryIndex;
  final ViolationItem? initialViolation;
  final int initialPoints;

  const _ReasonSelectionDialog({
    required this.categories,
    required this.initialCategoryIndex,
    this.initialViolation,
    required this.initialPoints,
  });

  @override
  State<_ReasonSelectionDialog> createState() => _ReasonSelectionDialogState();
}

class _ReasonSelectionDialogState extends State<_ReasonSelectionDialog> {
  late int _selectedCategoryIndex;
  late ViolationItem? _selectedViolation;
  late int _selectedPoints;
  late FixedExtentScrollController _pointsPickerController;

  @override
  void initState() {
    super.initState();
    _selectedCategoryIndex = widget.initialCategoryIndex;
    _selectedViolation = widget.initialViolation;
    _selectedPoints = widget.initialPoints;

    int initialPickerIndex = 0;
    if (_selectedViolation != null) {
      initialPickerIndex = _selectedPoints - _selectedViolation!.minPoints;
      if (initialPickerIndex < 0) initialPickerIndex = 0;
    }
    _pointsPickerController = FixedExtentScrollController(initialItem: initialPickerIndex);
  }

  @override
  void dispose() {
    _pointsPickerController.dispose();
    super.dispose();
  }

  void _onViolationSelected(ViolationItem item) {
    setState(() {
      _selectedViolation = item;
      _selectedPoints = item.minPoints;
    });
    if (_pointsPickerController.hasClients) {
      _pointsPickerController.jumpToItem(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCategoryItems = widget.categories[_selectedCategoryIndex].items;

    return AlertDialog(
      title: const Text('理由/点数の変更'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // カテゴリ選択
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: List.generate(widget.categories.length, (index) {
                  final category = widget.categories[index];
                  final isSelected = index == _selectedCategoryIndex;
                  return ChoiceChip(
                    label: Text(category.title),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategoryIndex = index;
                          _selectedViolation = null; // カテゴリ変更で項目選択をリセット
                        });
                      }
                    },
                  );
                }),
              ),
              const Divider(height: 24),
              // 項目選択
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: currentCategoryItems.map((item) {
                  final isSelected = _selectedViolation == item;
                  return ChoiceChip(
                    label: Text(item.name),
                    selected: isSelected,
                    onSelected: (_) => _onViolationSelected(item),
                    selectedColor: Theme.of(context).primaryColor,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                  );
                }).toList(),
              ),
              if (_selectedViolation != null && _selectedViolation!.minPoints != _selectedViolation!.maxPoints) ...[
                const SizedBox(height: 16),
                const Text('点数選択:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(
                  height: 100,
                  child: CupertinoPicker(
                    scrollController: _pointsPickerController,
                    itemExtent: 32.0,
                    onSelectedItemChanged: (index) {
                      setState(() => _selectedPoints = _selectedViolation!.minPoints + index);
                    },
                    children: List.generate(
                      _selectedViolation!.maxPoints - _selectedViolation!.minPoints + 1,
                          (index) => Center(child: Text('${_selectedViolation!.minPoints + index}')),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
        ElevatedButton(
          onPressed: _selectedViolation == null ? null : () {
            Navigator.pop(context, {'reason': _selectedViolation!.name, 'points': _selectedPoints});
          },
          child: const Text('変更を保存'),
        ),
      ],
    );
  }
}