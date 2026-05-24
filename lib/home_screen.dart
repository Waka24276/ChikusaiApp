import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:typed_data'; // Uint8Listのため
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestoreのインポート
import 'package:firebase_storage/firebase_storage.dart'; // Storageのインポート
import 'dart:async'; // StreamSubscriptionのため
import 'package:flutter/foundation.dart'; // kIsWeb を使うため
import 'post_detail_screen.dart'; // Import the new detail screen
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class HomeScreen extends StatefulWidget {
  final String username;

  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// 違反項目のデータ構造
class ViolationItem {
  final String name;
  final int minPoints;
  final int maxPoints;
  final bool isCommon; // よく使う項目かどうか
  final List<String> tags; // 検索用キーワード

  ViolationItem(this.name, this.minPoints, {int? maxPoints, this.isCommon = false, this.tags = const []})
      : maxPoints = maxPoints ?? minPoints; 

  // ドロップダウンでの比較を正しく行うための定義
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViolationItem &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          minPoints == other.minPoints &&
          maxPoints == other.maxPoints;

  @override
  int get hashCode => name.hashCode ^ minPoints.hashCode ^ maxPoints.hashCode;
}

// カテゴリー構造
class ViolationCategory {
  final String title;
  final List<ViolationItem> items;
  ViolationCategory(this.title, this.items);
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _remarksController = TextEditingController();
  List<Map<String, dynamic>> _posts = []; // Firestoreから取得したデータを保持
  StreamSubscription? _postsSubscription; // リアルタイム更新の購読
  int _selectedValue1 = 1;
  String _selectedValue2 = '1';
  Uint8List? _imageBytes; // 画像データを保持
  final ImagePicker _picker = ImagePicker();
  TabController? _tabController; // late を削除し、nullable に変更
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _classController;
  late FixedExtentScrollController _deductionPointsPicker;

  ViolationItem? _selectedViolation; // 選択された違反項目の詳細を保持
  int _selectedCategoryIndex = 0; // 選択中のカテゴリーインデックス
  Map<String, int> _violationUsageCounts = {}; // 各項目の利用回数を保持
  int _selectedDeductionPoints = 1; // Default to 1
  String _selectedDeductionReason = '未選択';

  // 違反データの定義 (学年ごとにリストを分ける)
  List<ViolationCategory> _getViolationData(int grade) {
    if (grade == 3) {
      // 3年生用の33項目 (サンプル)
      return [
        ViolationCategory('ステージ', [
          ViolationItem('リハで時間超過', 7),
          ViolationItem('舞台撤退時忘れ物', 1,),
          ViolationItem('危険な大道具の使用', 12,),
          ViolationItem('無届での割れ物の使用', 8,),
          ViolationItem('上演時刻超過', 20,),
        ]),
        ViolationCategory('学校祭', [   
          ViolationItem('退校時間後北館、中館にいる', 1,),
          ViolationItem('外出届を携帯せず外出', 20),
          ViolationItem('指定時間外での作業', 3),
          ViolationItem('指定場所以外での作業', 3),
          ViolationItem('本校生徒、職員以外の参加', 15),
        ]),
        ViolationCategory('資材', [
          ViolationItem('クラス工具紛失、未返却', 5),
          ViolationItem('生徒会工具未返却', 3),
          ViolationItem('生徒会工具紛失', 8),
          ViolationItem('役員以外が生徒会工具を借りる', 1),
          ViolationItem('生徒会工具の又貸し、無断借用', 1),
          ViolationItem('許可無し電動工具使用', 15),
          ViolationItem('私物工具使用許可証への違反行為', 10),
          ViolationItem('電動工具による危険行為', 10,),
          ViolationItem('不必要な時間、長時間の盗電行為', 5),
          ViolationItem('ミシンの不適切な取扱い', 3),
          ViolationItem('作業場所の清掃不備', 3, tags: ['ペンキ','ガムテープ', '汚れ']),
          ViolationItem('下校時刻後に危険物を放置', 5),
          ViolationItem('ペンキを指定場所以外に流す', 12, tags: ['水道', '排水', '汚染']),
          ViolationItem('使用禁止物の使用', 10),
          ViolationItem('ごみの分別不備、不適切廃棄', 3),
          ViolationItem('隠蔽、虚偽の報告、認めない', 10, maxPoints: 20),
          ViolationItem('設備、備品、工具の破損、落書き', 3, maxPoints: 20, tags: ['壊した', '机', '椅子', '壁']),
        ]),
        ViolationCategory('PR', [
          ViolationItem('垂れ幕、装飾が展示中に落下', 20),
          ViolationItem('学実の印が無い看板等の使用', 5),
          ViolationItem('景品を配布する', 10, tags: ['お菓子', 'プレゼント']),
          ViolationItem('安全性に欠けたPR', 5),
          ViolationItem('15役から許可の無いPR', 4),
        ]),
      ];
    } else {
      // 1,2年生用の32項目 (サンプル)
      return [
        ViolationCategory('展示', [
          ViolationItem('提出した設計図と異なる構造で制作', 20),
          ViolationItem('許可なしにポール以外の支柱を使用', 17, tags: ['15役']),
          ViolationItem('廊下へ30㎝以上はみ出した制作', 5, tags: ['建築物']),
          ViolationItem('会場時に来場者が入場できない状態', 5),
        ]),
        ViolationCategory('学校祭', [
          ViolationItem('退校時刻後北館、中館にいる', 1,),
          ViolationItem('外出届を携帯せず外出', 20),
          ViolationItem('指定時間外での作業', 3),
          ViolationItem('指定場所以外での作業', 3),
          ViolationItem('本校生徒、職員以外の参加', 15),
        ]),
        ViolationCategory('資材', [
          ViolationItem('クラス工具紛失、未返却', 5),
          ViolationItem('生徒会工具未返却', 3),
          ViolationItem('生徒会工具紛失', 8),
          ViolationItem('役員以外が生徒会工具を借りる', 1),
          ViolationItem('生徒会工具の又貸し、無断借用', 1),
          ViolationItem('許可無し電動工具使用', 15),
          ViolationItem('私物工具使用許可証への違反行為', 10),
          ViolationItem('電動工具による危険行為', 10,),
          ViolationItem('不必要な時間、長時間の盗電行為', 5),
          ViolationItem('ミシンの不適切な取扱い', 3),
          ViolationItem('作業場所の清掃不備', 3, maxPoints: 20, tags: ['ペンキ', 'ガムテープ', '汚れ']),
          ViolationItem('下校時刻後に危険物を放置', 5),
          ViolationItem('ペンキを指定場所以外に流す', 12, tags: ['水道', '排水', '汚染']),
          ViolationItem('使用禁止物の使用', 10),
          ViolationItem('ごみの分別不備、不適切廃棄', 3),
          ViolationItem('隠蔽、虚偽の報告、認めない', 10, maxPoints: 20),
          ViolationItem('設備、備品、工具の破損、落書き', 3, maxPoints: 20, tags: ['壊した', '机', '椅子', '壁']),
        ]),
        ViolationCategory('PR', [
          ViolationItem('垂れ幕、装飾が展示中に落下', 10),
          ViolationItem('学実の印が無い看板等の使用', 5),
          ViolationItem('景品を配布する', 10, tags: ['お菓子', 'プレゼント']),
          ViolationItem('安全性に欠けたPR', 5),
          ViolationItem('15役から許可の無いPR', 4),
        ]),
      ];
    }
  }

  // よく使う項目だけを抽出するヘルパー
  // 利用回数が多い項目をクイック選択用に抽出する
  List<ViolationItem> _getQuickSelectItems() {
    final List<ViolationItem> allItems = [];
    // 全ての学年のカテゴリーから項目を収集
    for (int grade = 1; grade <= 3; grade++) {
      final categories = _getViolationData(grade);
      for (var category in categories) {
        allItems.addAll(category.items);
      }
    }

    // 重複を排除 (ViolationItem の == と hashCode が正しく実装されている前提)
    final uniqueItems = allItems.toSet().toList();

    // 利用回数に基づいてソート
    uniqueItems.sort((a, b) {
      final countA = _violationUsageCounts[a.name] ?? 0;
      final countB = _violationUsageCounts[b.name] ?? 0;
      return countB.compareTo(countA); // 多い順
    });

    // 利用回数が0でない上位5件を返す
    return uniqueItems.where((item) => (_violationUsageCounts[item.name] ?? 0) > 0)
                      .take(5)
                      .toList();
  }

  // 利用回数を増やす処理
  Future<void> _incrementViolationCount(String reason) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _violationUsageCounts[reason] = (_violationUsageCounts[reason] ?? 0) + 1;
    });
    await prefs.setString('violationUsageCounts', jsonEncode(_violationUsageCounts));
  }

  // 保存された利用回数を読み込む
  Future<void> _loadUsageCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? countsJson = prefs.getString('violationUsageCounts');
    if (countsJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(countsJson);
        setState(() {
          _violationUsageCounts = decoded.map((key, value) => MapEntry(key, value as int));
        });
      } catch (e) {
        debugPrint('利用回数データの読み込みエラー: $e');
      }
    }
  }

  // 項目選択時に点数を連動させる
  void _onViolationSelected(ViolationItem item) {
    setState(() {
      _selectedViolation = item;
      _selectedDeductionReason = item.name;
      
      // 選択された項目がどのカテゴリに属するかを特定し、そのカテゴリをアクティブにする
      // これにより、Autocompleteで選択された項目が、下のチップリストでもハイライトされる
      final allCategories = _getViolationData(_selectedValue1);
      for (int i = 0; i < allCategories.length; i++) {
        if (allCategories[i].items.contains(item)) {
          _selectedCategoryIndex = i;
          break;
        }
      }
      _selectedDeductionPoints = item.minPoints;
    });
    // 点数に幅がある場合、描画後にピッカーを先頭(最小点数)に戻す
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_deductionPointsPicker.hasClients) {
        _deductionPointsPicker.jumpToItem(0);
      }
    });
  }

  bool _sortNewestFirst = true; // Added state for sorting order
  // Search filter state
  bool _isTableView = false; // 集計表表示かどうかの状態
  bool _isLargeImageMode = false; // 画像を大きく表示するかどうかの状態
  bool _showHiddenOnly = false; // 非表示(アーカイブ)された投稿のみを表示するかどうか
  bool _isPostFormExpanded = true; // 減点登録フォームが開いているかどうか
  final Map<int, int> _gradeClassFilters = {}; // 学年ごとのクラスフィルター状態 (tabIndex: classNum)

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUsageCounts(); // 利用回数の読み込み
    _listenToPosts(); // 起動時にFirestoreの監視を開始
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _tabController?.dispose(); // null-aware operator を使用して安全に破棄
    _yearController.dispose();
    _classController.dispose();
    _deductionPointsPicker.dispose();
    _postsSubscription?.cancel(); // 画面を閉じるときに購読を解除
    super.dispose();
  }

  void _initializeControllers() {
    // dispose 済みの古いコントローラがあれば破棄
    _tabController?.dispose();
    _tabController = TabController(
      length: 4,
      vsync: this,
    );
    _yearController = FixedExtentScrollController(
      initialItem: _selectedValue1 - 1,
    );
    _classController = FixedExtentScrollController(
      initialItem: int.parse(_selectedValue2) - 1,
    );
    _deductionPointsPicker = FixedExtentScrollController(
      initialItem: _selectedDeductionPoints - 1,
    );
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, // 軽量化:画像を最大800pxにリサイズ
      maxHeight: 800,
      imageQuality: 70, // 軽量化:画質を少し落として容量削減
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes(); // 画像をバイトデータとして読み込む
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  // Firestoreのデータをリアルタイムで監視する
  void _listenToPosts() {
    _postsSubscription = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('timestamp', descending: true) // 新しい順に取得
        .limit(20) // 取得件数を20件に制限して動作を軽量化
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _posts = snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id; // ドキュメントIDを保持(削除や更新に必要)
          
          // 画像がBase64の場合、ここで一度だけデコードしてバイトデータとして保持しておく
          final String imagePath = data['imagePath'] ?? '';
          if (imagePath.isNotEmpty && !imagePath.startsWith('http')) {
            try {
              data['_cachedUint8List'] = base64Decode(imagePath);
            } catch (_) {}
          }
          return data;
        }).toList();
      });
    }, onError: (e) => debugPrint('Firestoreエラー: $e'));
  }

  void _deletePost(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('削除の確認'),
          content: const Text('この投稿を削除してもよろしいですか?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () async {
                // Firestoreから削除
                await FirebaseFirestore.instance.collection('posts').doc(item['id']).delete();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('削除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _toggleHidePost(Map<String, dynamic> item) async {
    if (item['isHidden'] == true) {
      // すでに非表示の場合は、単に表示に戻す
      final TextEditingController restoreReasonController = TextEditingController();
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('この減点取り消しを無効にして、減点を復元しますか?'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: restoreReasonController,
                  decoration: const InputDecoration(labelText: '弁明を受け付けた人は誰ですか？', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('復元'),
              ),
            ],
          );
        },
      );

      if (confirm != true) {
        restoreReasonController.dispose(); // キャンセル時はコントローラを破棄
        return;
      }

      // Firestoreのデータを更新
      final Map<String, dynamic> updateData = {
        'isHidden': false,
      };
      if (restoreReasonController.text.isNotEmpty) {
        updateData['restoreReason'] = restoreReasonController.text;
      } else {
        updateData['restoreReason'] = FieldValue.delete(); // 理由が空ならフィールドも削除
      }
      await FirebaseFirestore.instance.collection('posts').doc(item['id']).update(updateData);
      restoreReasonController.dispose(); // 使用後はコントローラを破棄
      
      return;
    }

    // 非表示にする際の画像選択ダイアログ
    Uint8List? tempBytes;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('減点取り消し'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('弁明書の写真を添付してください'),
                  const SizedBox(height: 16),
                  if (tempBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Image.memory(tempBytes!, height: 150, fit: BoxFit.cover),
                    ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final XFile? pickedFile = await _picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 800,
                        maxHeight: 800,
                        imageQuality: 50,
                      );
                      if (pickedFile != null) {
                        final bytes = await pickedFile.readAsBytes();
                        setDialogState(() => tempBytes = bytes);
                      }
                    },
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('写真を選択'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String hiddenImageUrl = '';
                    if (tempBytes != null) {
                      final ref = FirebaseStorage.instance
                          .ref()
                          .child('hidden_reasons/${DateTime.now().millisecondsSinceEpoch}.jpg');
                      await ref.putData(tempBytes!);
                      hiddenImageUrl = await ref.getDownloadURL();
                    }
                    // Firestoreのデータを更新
                    await FirebaseFirestore.instance.collection('posts').doc(item['id']).update({
                      'isHidden': true,
                      'hiddenReasonImage': hiddenImageUrl,
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('減点を取り消しする'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitPost() async {
    // 備考に入力がある、画像が選択されている、または減点数が設定されている場合に投稿を許可
    if (_remarksController.text.isNotEmpty ||
        _imageBytes != null ||
        _selectedDeductionPoints > 0) {
      
      // 統計情報の更新 (非同期で実行)
      if (_selectedDeductionReason != '未選択') {
        _incrementViolationCount(_selectedDeductionReason);
      }

      String imageUrl = '';
      if (_imageBytes != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('post_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putData(_imageBytes!);
        imageUrl = await ref.getDownloadURL();
      }

      // Firestoreに新規追加
      await FirebaseFirestore.instance.collection('posts').add({
        'class': '$_selectedValue1年$_selectedValue2組',
        'deductionPoints': _selectedDeductionPoints.toString(),
        'deductionReason': _selectedDeductionReason,
        'remarks': _remarksController.text,
        'imagePath': imageUrl,
        'timestamp': DateTime.now().toIso8601String(),
        'name': widget.username,
        'isHidden': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '投稿しました: $_selectedDeductionPoints点, 理由: $_selectedDeductionReason',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0), // 角丸の半径を調整
            ),
          ),
        );
      }

      // フォームをリセット
      _selectedValue1 = 1;
      _selectedValue2 = '1';
      _yearController.jumpToItem(0);
      _classController.jumpToItem(0);
      _selectedCategoryIndex = 0;
      _selectedDeductionPoints = 1;
      _selectedDeductionReason = '未選択';
      _selectedViolation = null;
      if (_deductionPointsPicker.hasClients) _deductionPointsPicker.jumpToItem(0);
      _remarksController.clear();
      _imageBytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // コントローラが初期化されていない場合は読み込み中を表示
    if (_tabController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: _showHiddenOnly ? const Color.fromARGB(255, 255, 244, 246) : Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              title: Text(_showHiddenOnly ? '取り消した減点' : 'ホーム'),
              leading: IconButton(
                icon: const Icon(Icons.meeting_room),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('isLoggedIn'); // ログイン保持設定をクリア
                  if (mounted) Navigator.pop(context);
                },
                tooltip: 'ログアウト',
              ),
              backgroundColor: _showHiddenOnly ? Colors.red[100] : const Color.fromARGB(255, 208, 249, 255),
              floating: true, // 上にスクロールした時にすぐ表示される
              pinned: true,
              snap: true,
              elevation: 0,
              forceElevated: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: () => setState(() => _showHiddenOnly = !_showHiddenOnly),
                  tooltip: _showHiddenOnly ? '有効な減点を表示' : '取り消しした減点を表示',
                  color: _showHiddenOnly ? const Color.fromARGB(255, 214, 116, 109) : Colors.blueGrey,
                ),
                IconButton(
                  icon: Icon(_isTableView ? Icons.list : Icons.table_chart),
                  onPressed: () {
                    setState(() {
                      _isTableView = !_isTableView;
                    });
                  },
                  tooltip: _isTableView ? 'リスト表示' : '集計表表示',
                ),
                IconButton(
                  icon: Icon(
                    _isTableView
                        ? Icons.image_not_supported
                        : (_isLargeImageMode ? Icons.image : Icons.image_outlined),
                  ),
                  onPressed: _isTableView
                      ? null
                      : () => setState(() => _isLargeImageMode = !_isLargeImageMode),
                  tooltip: _isTableView ? '集計表表示中は画像サイズを変更できません' : (_isLargeImageMode ? '画像を小さく表示' : '画像を大きく表示'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _sortNewestFirst = !_sortNewestFirst;
                    });
                  },
                  child: Text(
                    _sortNewestFirst ? '古い順' : '新しい順',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              bottom: TabBar(
                isScrollable: false, // 画面幅いっぱいに均等に配置
                controller: _tabController!, // ! を追加
                onTap: (index) {
                  // すでに選択されているタブをもう一度押した時にフィルターをリセット
                  if (_tabController != null && index == _tabController!.index) {
                    setState(() {
                      _gradeClassFilters.remove(index);
                    });
                  }
                },
                labelColor: const Color.fromARGB(255, 20, 112, 187),
                unselectedLabelColor: Colors.black54,
                indicatorColor: const Color.fromARGB(255, 20, 112, 187),
                tabs: const [
                  Tab(text: '全体'),
                  Tab(text: '1年'),
                  Tab(text: '2年'),
                  Tab(text: '3年'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController!, // ! を追加
          children: [
            _buildTabContent(isPostForm: true, tabIndex: 0),
            _buildTabContent(isPostForm: false, tabIndex: 1),
            _buildTabContent(isPostForm: false, tabIndex: 2),
            _buildTabContent(isPostForm: false, tabIndex: 3),
          ],
        ),
      ),
    );
  }

  static final RegExp _classRegex = RegExp(r'(\d+)組');

  Widget _buildTabContent({required bool isPostForm, required int tabIndex}) {
    // 表示用データの準備
    // メモ: categoriesのソートは本来State更新時に行うのが理想ですが、
    // ここではまず計算量を減らすために、必要なリスト作成を効率化します。
    final List<ViolationCategory> categories = _getViolationData(_selectedValue1);
    if (_violationUsageCounts.isNotEmpty) {
      // 簡易的な並び替えに留めるか、頻繁に変わらないならそのままにする
    }

    final List<Map<String, dynamic>> displayedPosts = [];
    final Map<int, int> classTotals = {};
    if (tabIndex > 0) {
      for (int i = 1; i <= 9; i++) classTotals[i] = 0;
    }

    // 1回のループで番号付け、フィルタリング、集計を同時に行う (高速化)
    final String? targetYear = tabIndex > 0 ? '${tabIndex}年' : null;
    final activeFilter = _gradeClassFilters[tabIndex];
    final String? tabClassFilter = (tabIndex > 0 && activeFilter != null) 
        ? '${tabIndex}年${activeFilter}組' : null;
    
    // 比較用ターゲットをクリーンアップ
    final String? cleanTargetYear = targetYear?.trim();

    for (int i = 0; i < _posts.length; i++) {
      final post = _posts[i];
      
      // 基本条件(取り消し済みかどうか)
      if ((post['isHidden'] ?? false) != _showHiddenOnly) continue;

      // タブごとの条件
      final String postClass = (post['class']?.toString() ?? '').trim();
      if (cleanTargetYear != null && !postClass.startsWith(cleanTargetYear)) continue;

      final int postNo = _posts.length - i;

      // 集計
      final int points = int.tryParse(post['deductionPoints']?.toString() ?? '0') ?? 0;
      if (tabIndex > 0) {
        final String? classStr = post['class']?.toString();
        if (classStr != null) {
          final match = _classRegex.firstMatch(classStr);
          if (match != null) {
            final classNum = int.tryParse(match.group(1)!);
            if (classNum != null && classTotals.containsKey(classNum)) {
              classTotals[classNum] = classTotals[classNum]! + points;
            }
          }
        }
      }

      // リスト表示用の絞り込み(集計には含めるがリストからは外す場合)
      if (tabClassFilter != null && postClass != tabClassFilter) continue;

    // 表示用データを作成(元のデータを汚染しないようコピーを作成)
    final decoratedPost = Map<String, dynamic>.from(post);
    decoratedPost['_uiNumber'] = postNo;
    displayedPosts.add(decoratedPost);
    }

    // 並び替え (null安全な比較に修正)
    displayedPosts.sort((a, b) {
      final String timeA = a['timestamp']?.toString() ?? '';
      final String timeB = b['timestamp']?.toString() ?? '';
      if (_sortNewestFirst) return timeB.compareTo(timeA);
      return timeA.compareTo(timeB);
    });

    // CustomScrollView を使用することで、大量のリストアイテムを効率的に描画(Recycling)できるようにします
    return CustomScrollView(
      key: PageStorageKey<String>('tab_$tabIndex'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverToBoxAdapter( // SliverToBoxAdapter を使用して単一のウィジェットをSliverとして表示
            child: Column( // Column で複数のウィジェットを縦に並べる
              children: [
              if (isPostForm && !_showHiddenOnly)
                Card(
                  color: const Color.fromARGB(255, 249, 252, 255), // ← ここをお好きな色に変更してください
                  elevation: 2, // 少し浮かせてリッチに
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                padding: EdgeInsets.all(_isPostFormExpanded ? 16.0 : 8.0),
                    child: Column(
                      children: [
                    InkWell(
                      onTap: () => setState(() => _isPostFormExpanded = !_isPostFormExpanded),
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.edit_note, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          const Text(
                            '減点登録',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Icon(
                            _isPostFormExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                    if (_isPostFormExpanded) ...[
                      const Divider(height: 32),
                      const Row(
                        children: [
                          Icon(Icons.school_outlined, size: 20, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('対象クラス', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildPickerContainer(
                            width: 70,
                            picker: CupertinoPicker(
                              scrollController: _yearController,
                              itemExtent: 32.0,
                              onSelectedItemChanged: (int index) {
                                setState(() {
                                  _selectedValue1 = index + 1;
                                  // 学年が変わったら選択中の理由をリセット(ミスの防止)
                                  _selectedCategoryIndex = 0;
                                  _selectedDeductionReason = '未選択';
                                  _selectedViolation = null;
                                  _selectedDeductionPoints = 1;
                                  if (_deductionPointsPicker.hasClients) {
                                    _deductionPointsPicker.jumpToItem(0);
                                  }
                                });
                              },
                              children: List<Widget>.generate(3, (int index) => Center(child: Text('${index + 1}'))),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('年', style: TextStyle(fontSize: 16)),
                          ),
                          _buildPickerContainer(
                            width: 70,
                            picker: CupertinoPicker(
                              scrollController: _classController,
                              itemExtent: 32.0,
                              onSelectedItemChanged: (int index) => setState(() => _selectedValue2 = (index + 1).toString()),
                              children: List<Widget>.generate(9, (int index) => Center(child: Text('${index + 1}'))),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('組', style: TextStyle(fontSize: 16)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // クイック選択セクション
                      const Row(
                        children: [
                          Icon(Icons.star_border, size: 20, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('よく使う項目', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, // 2列に固定
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 3.5, // ボタンの横長具合を調整
                        ),
                        itemCount: _getQuickSelectItems().length,
                        itemBuilder: (context, index) {
                          final item = _getQuickSelectItems()[index];
                          final isSelected = _selectedViolation == item;
                          return InkWell(
                            onTap: () => _onViolationSelected(item),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.orangeAccent : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? Colors.orangeAccent : Colors.grey[300]!,
                                ),
                              ),
                              child: Text(
                                item.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24), // カテゴリ選択との間にスペース
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 232, 241, 252), // ← 1. セグメント全体の背景色（後ろの色）
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: List<Widget>.generate(categories.length, (i) {
                            final isSelected = _selectedCategoryIndex == i;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryIndex = i;
                                    _selectedViolation = null;
                                    _selectedDeductionReason = '未選択';
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color.fromARGB(255, 127, 187, 236) : Colors.transparent, // ← 2. 選択された項目の色
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    categories[i].title,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black87,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 内容選択(チップ形式:セグメントを選んだらすぐに表示される)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 3.2, // 少し高さを出して押しやすく
                        ),
                        itemCount: categories[(_selectedCategoryIndex < categories.length ? _selectedCategoryIndex : 0)].items.length,
                        itemBuilder: (context, index) {
                          final item = categories[(_selectedCategoryIndex < categories.length ? _selectedCategoryIndex : 0)].items[index];
                          final isSelected = _selectedViolation == item;
                          return InkWell(
                            onTap: () => _onViolationSelected(item),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blueAccent : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? Colors.blueAccent : Colors.grey[300]!,
                                ),
                              ),
                              child: Text(
                                item.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (_selectedViolation != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('減点数:', style: TextStyle(color: Colors.grey)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                              ),
                              child: Text(
                                _selectedViolation!.name == '隠蔽、虚偽の報告、認めない'
                                    ? '10点 + ${_selectedDeductionPoints - 10}行為数'
                                    : '$_selectedDeductionPoints',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                            if (_selectedViolation!.minPoints != _selectedViolation!.maxPoints) ...[
                              const SizedBox(width: 12),
                              _buildPickerContainer(
                                width: 60,
                                picker: CupertinoPicker(
                                  scrollController: _deductionPointsPicker,
                                  itemExtent: 32.0,
                                  onSelectedItemChanged: (int index) {
                                    setState(() {
                                      _selectedDeductionPoints = _selectedViolation!.minPoints + index;
                                    });
                                  },
                                  children: List<Widget>.generate(
                                    _selectedViolation!.maxPoints - _selectedViolation!.minPoints + 1,
                                    (int index) => Center(child: Text('${_selectedViolation!.minPoints + index}')),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      TextField(
                        controller: _remarksController,
                        decoration: const InputDecoration(
                          labelText: '備考',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.comment_outlined),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.add_a_photo),
                            label: Text(_imageBytes == null ? '写真' : '写真を変更'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              foregroundColor: Colors.black87,
                              elevation: 0,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _submitPost,
                            icon: const Icon(Icons.send),
                            label: const Text('登録する'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                      if (_imageBytes != null) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(_imageBytes!, height: 100, fit: BoxFit.cover),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ), // End Card
            if (tabIndex > 0) ...[
              const SizedBox(height: 16),
              _buildGradeSummarySection(tabIndex, classTotals),
            ],
            const SizedBox(height: 16),
            const _SectionHeader(icon: Icons.history_edu, title: '投稿履歴'), // constを追加
          ], // Columnのchildrenリストを閉じるカッコ
        ), // Columnを閉じるカッコ
      ), // SliverToBoxAdapterを閉じるカッコ
    ), // SliverPaddingを閉じるカッコ
        if (_isTableView)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () => _exportPostsToPdf(displayedPosts, tabIndex),
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('PDF出力 (A4)', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red[700], elevation: 0),
                      ),
                    ),
                    _buildSummaryTable(displayedPosts),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildPostCard(displayedPosts[index]),
                  childCount: displayedPosts.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildGradeSummarySection(int tabIndex, Map<int, int> classTotals) {
    return Column(
      children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.5,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                final classNum = index + 1;
                final total = classTotals[classNum] ?? 0;
                final isSelected = _gradeClassFilters[tabIndex] == classNum;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _gradeClassFilters.remove(tabIndex);
                      } else {
                        _gradeClassFilters[tabIndex] = classNum;
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.blueGrey.withOpacity(0.4),
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          ? Colors.blue[50]
                          : (total > 0 ? Colors.red[50] : Colors.white),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$classNum組',
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? Colors.blue[700] : Colors.blueGrey[700],
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            )),
                        Text(
                          '$total',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.blue[800] : (total > 0 ? Colors.red[700] : Colors.blueGrey),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
      ],
    );
  }

  // 個別の投稿カードを生成。大量リストでも高速に動作するように分離。
  Widget _buildPostCard(Map<String, dynamic> item) {
    final String imagePath = item['imagePath'] ?? '';
    final int postNumber = item['_uiNumber'] ?? 0;
    final Uint8List? cachedBytes = item['_cachedUint8List'] as Uint8List?;

    if (_isLargeImageMode && imagePath.isNotEmpty) {
      return Card(
        clipBehavior: Clip.antiAlias,
        color: Colors.white,
        elevation: 1, // 控えめな影
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PostDetailScreen(post: item)),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImageWidget(imagePath, width: double.infinity, height: 200, cachedBytes: cachedBytes),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'No. $postNumber  ${item['class']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Row(
                          children: [
                            Text(
                              item['timestamp'] != null
                                  ? DateTime.parse(item['timestamp']!)
                                      .toLocal()
                                      .toString()
                                      .substring(5, 16)
                                      .replaceAll('-', '/')
                                  : '',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(item['isHidden'] == true ? Icons.restore : Icons.undo, size: 20, color: Colors.grey),
                              onPressed: () => _toggleHidePost(item),
                              tooltip: item['isHidden'] == true ? '減点を戻す' : '減点を取り消す',
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                              onPressed: () => _deletePost(item),
                            ),
                          ],
                        ),
                      ],
                    ),
                    _buildPostContentSnippet(item),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.white,
      elevation: 1, // 控えめな影
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$postNumber',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _buildImageWidget(item['imagePath'], size: 50, cachedBytes: cachedBytes),
            ),
          ],
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${item['class']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              item['timestamp'] != null
                  ? DateTime.parse(item['timestamp']!)
                      .toLocal()
                      .toString()
                      .substring(5, 16)
                      .replaceAll('-', '/')
                  : '',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: _buildPostContentSnippet(item),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(item['isHidden'] == true ? Icons.restore : Icons.undo, color: Colors.grey),
              onPressed: () => _toggleHidePost(item),
              tooltip: item['isHidden'] == true ? '減点を戻す' : '減点を取り消す',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () => _deletePost(item),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PostDetailScreen(post: item)),
          );
        },
      ),
    );
  }

  // 投稿内容(減点数、理由、備考)のUIパーツ
  Widget _buildPostContentSnippet(Map<String, dynamic> item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${item['deductionPoints']}点',
                style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '理由: ${item['deductionReason']}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        if (item['remarks'] != null && item['remarks'].toString().isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4.0), child: Text('備考: ${item['remarks']}', style: const TextStyle(fontSize: 13, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  // ピッカーを包む共通のデザインコンテナ
  Widget _buildPickerContainer({required double width, required Widget picker}) {
    return Container(
      height: 60,
      width: width,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
      child: picker,
    );
  }

  // 集計表表示
  Widget _buildSummaryTable(List<Map<String, dynamic>> displayedPosts) {
    // 折衷案: FittedBoxのscaleDownを使用して、画面幅に収まる場合は等倍、はみ出す場合のみ縮小表示します。
    // alignmentをcenterLeftにすることで、縮小時も左に寄らず自然な配置になります。
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.grey[200]),
        child: DataTable(
          key: ValueKey('table_${displayedPosts.length}'),
          columnSpacing: 12.0, // 列間の余白を詰める
          horizontalMargin: 12, // 端の余白を詰める
          headingRowHeight: 44,
          columns: const [
            DataColumn(label: Text('No', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('クラス', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('点数', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('理由', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('名前', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('日時', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: List<DataRow>.generate(displayedPosts.length, (index) {
            final item = displayedPosts[index];
            return DataRow(
              cells: [
                DataCell(Text('${item['_uiNumber'] ?? 0}'), 
                         onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(post: item)))),
                DataCell(
                  Text(item['timestamp'] != null
                      ? DateTime.parse(item['timestamp']!)
                          .toLocal()
                          .toString()
                          .substring(5, 16)
                          .replaceAll('-', '/')
                      : ''),
                ),
                DataCell(Text(item['class']?.toString() ?? '')),
                DataCell(Text(item['deductionPoints']?.toString() ?? '')),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(item['deductionReason']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                  ),
                ),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(item['name']?.toString() ?? '不明', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  /// 表示中のデータをA4サイズのPDFプレビューとして表示する
  Future<void> _exportPostsToPdf(List<Map<String, dynamic>> posts, int tabIndex) async {
    final int? activeClass = _gradeClassFilters[tabIndex];
    final bool isClassView = tabIndex > 0 && activeClass != null;
    String title = tabIndex == 0 ? '全学年 減点集計表' : '$tabIndex年 減点集計表';
    if (isClassView) {
      title = '$tabIndex年$activeClass組 減点集計表';
    }
    final int totalPoints = posts.fold(0, (sum, item) => sum + (int.tryParse(item['deductionPoints']?.toString() ?? '0') ?? 0));

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text('$title - プレビュー'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            body: PdfPreview(
              canDebug: false,
              canChangePageFormat: false,
              build: (format) async {
                final pdf = pw.Document();
                final font = await PdfGoogleFonts.notoSansJPRegular();
                final boldFont = await PdfGoogleFonts.notoSansJPBold();

                pdf.addPage(
                  pw.MultiPage(
                    pageFormat: PdfPageFormat.a4,
                    margin: const pw.EdgeInsets.all(20),
                    theme: pw.ThemeData.withFont(base: font, bold: boldFont),
                    footer: (pw.Context context) {
                      return pw.Container(
                        alignment: pw.Alignment.centerRight,
                        margin: const pw.EdgeInsets.only(top: 10),
                        child: pw.Text(
                          '${context.pageNumber} / ${context.pagesCount} ページ',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      );
                    },
                    build: (pw.Context context) {
                      return [
                        pw.Header(
                          level: 0,
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(title, style: pw.TextStyle(fontSize: 18, font: boldFont)),
                              pw.Text('出力日: ${DateTime.now().toString().substring(0, 16)}', style: const pw.TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 20),
                        pw.Table.fromTextArray(
                          headerStyle: pw.TextStyle(font: boldFont, fontSize: 10),
                          cellStyle: const pw.TextStyle(fontSize: 9),
                          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300), // モノクロのグレー
                          headers: ['No.', '日時', 'クラス', '減点数', '理由', '名前'],
                          columnWidths: {
                            0: const pw.FixedColumnWidth(25),  // No.
                            1: const pw.FixedColumnWidth(75),  // 日時
                            2: const pw.FixedColumnWidth(55),  // クラス
                            3: const pw.FixedColumnWidth(35),  // 減点数
                            4: const pw.FlexColumnWidth(3),    // 理由 (可変・広め)
                            5: const pw.FlexColumnWidth(1.5),  // 名前 (可変)
                          },
                          cellAlignment: pw.Alignment.centerLeft,
                          headerAlignment: pw.Alignment.center,
                          data: [
                            ...posts.map((p) => [
                              p['_uiNumber']?.toString() ?? '',
                              p['timestamp'] != null
                                  ? DateTime.parse(p['timestamp']!)
                                      .toLocal()
                                      .toString()
                                      .substring(5, 16)
                                      .replaceAll('-', '/')
                                  : '',
                              p['class']?.toString() ?? '',
                              p['deductionPoints']?.toString() ?? '',
                              p['deductionReason']?.toString() ?? '',
                              p['name']?.toString() ?? '',
                            ]).toList(),
                            if (isClassView)
                              ['', '', '合計', totalPoints.toString(), '', ''],
                          ],
                        ),
                      ];
                    },
                  ),
                );
                return pdf.save();
              },
              pdfFileName: '${title}_${DateTime.now().millisecondsSinceEpoch}.pdf',
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('PDFプレビューエラー: $e');
    }
  }

  Widget _buildImageWidget(String? imagePath, {double? size, double? width, double? height, Uint8List? cachedBytes}) {
    if (imagePath == null || imagePath.isEmpty) return const SizedBox.shrink();
    final double? w = width ?? size;
    final double? h = height ?? size;
    final double iconSize = size ?? 40; // デフォルトのアイコンサイズ
    try {
      final bool isNetwork = imagePath.startsWith('http');
      final int? cacheW = (w != null && w > 0 && w.isFinite) ? (w * 2.0).toInt() : null;
      final int? cacheH = (h != null && h > 0 && h.isFinite) ? (h * 2.0).toInt() : null;

      return RepaintBoundary(
        child: isNetwork
            ? Image.network(
                imagePath,
                width: w, height: h, fit: BoxFit.cover,
                cacheWidth: cacheW, cacheHeight: cacheH,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: iconSize),
              )
            : _buildMemoryImage(imagePath, cachedBytes, w, h, cacheW, cacheH, iconSize), // 分離したメソッドを呼ぶ
      );
    } catch (_) {
      return Icon(Icons.broken_image, size: iconSize);
    }
  }

  // メソッドを独立させる（構文エラーの修正）
  Widget _buildMemoryImage(String imagePath, Uint8List? fallbackBytes, double? w, double? h, int? cacheW, int? cacheH, double iconSize) {
    // fallbackBytesがあればデコード不要
    final bytes = fallbackBytes ?? (imagePath.length > 50 ? base64Decode(imagePath) : null);
    if (bytes == null) return Icon(Icons.broken_image, size: iconSize);
    
    return Image.memory(
      bytes,
      width: w, height: h, fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      cacheWidth: (cacheW != null && cacheW > 0) ? cacheW : null,
      cacheHeight: (cacheH != null && cacheH > 0) ? cacheH : null,
      errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: iconSize),
    );
  }
} // _HomeScreenState を閉じるカッコ（重要）

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Row(children: [Icon(icon, color: Colors.blueGrey), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]));
  }
}
