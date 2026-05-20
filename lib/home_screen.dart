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
  final _violationSearchController = TextEditingController(); // 項目検索用
  String _violationSearchQuery = ''; // 検索クエリ保持用
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
  late FixedExtentScrollController _searchYearPicker;
  late FixedExtentScrollController _searchClassPicker;

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
  int _searchFilterYear = 1; // Default selected year for search
  String _searchFilterClass = '1'; // Default selected class for search
  bool _isSearchFilterActive = false; // Flag to indicate if a search filter is applied
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
    _violationSearchController.dispose();
    _tabController?.dispose(); // null-aware operator を使用して安全に破棄
    _yearController.dispose();
    _classController.dispose();
    _deductionPointsPicker.dispose();
    _searchYearPicker.dispose();
    _searchClassPicker.dispose();
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
    // Initialize search filter controllers
    _searchYearPicker = FixedExtentScrollController(
      initialItem: _searchFilterYear - 1,
    );
    _searchClassPicker = FixedExtentScrollController(
      initialItem: int.parse(_searchFilterClass) - 1,
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
        .limit(30) // スマホ向けに取得件数を30件に絞ってさらに高速化
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _posts = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; // ドキュメントIDを保持(削除や更新に必要)
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
                  decoration: const InputDecoration(labelText: '復元理由 (任意)', border: OutlineInputBorder()),
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
              forceElevated: innerBoxIsScrolled,
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
                isScrollable: true, // タブの文字が隠れないようにする
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
    // 表示する投稿のリストを事前に準備(ソート・フィルタリング)
    final categories = _getViolationData(_selectedValue1);

    // カテゴリごとの合計利用回数に基づいて並び替え(多い順)
    categories.sort((a, b) {
      final usageA = a.items.fold(0, (sum, item) => sum + (_violationUsageCounts[item.name] ?? 0));
      final usageB = b.items.fold(0, (sum, item) => sum + (_violationUsageCounts[item.name] ?? 0));
      return usageB.compareTo(usageA);
    });

    final List<Map<String, dynamic>> displayedPosts = [];
    int totalDeductionPoints = 0;
    final Map<int, int> classTotals = {};
    if (tabIndex > 0) {
      for (int i = 1; i <= 9; i++) classTotals[i] = 0;
    }

    // 1回のループで番号付け、フィルタリング、集計を同時に行う (高速化)
    final String? searchTarget = _isSearchFilterActive && tabIndex == 0 
        ? '${_searchFilterYear}年${_searchFilterClass}組' : null;
    final String? targetYear = tabIndex > 0 ? '${tabIndex}年' : null;
    final activeFilter = _gradeClassFilters[tabIndex];
    final String? tabClassFilter = (tabIndex > 0 && activeFilter != null) 
        ? '${tabIndex}年${activeFilter}組' : null;
    
    // 比較用ターゲットをクリーンアップ
    final String? cleanSearchTarget = searchTarget?.trim();
    final String? cleanTargetYear = targetYear?.trim();

    for (int i = 0; i < _posts.length; i++) {
      final post = _posts[i];
      
      // 基本条件(取り消し済みかどうか)
      if ((post['isHidden'] ?? false) != _showHiddenOnly) continue;

      // タブごとの条件
      final String postClass = (post['class']?.toString() ?? '').trim();
      if (cleanSearchTarget != null && postClass != cleanSearchTarget) continue;
      if (cleanTargetYear != null && !postClass.startsWith(cleanTargetYear)) continue;

      final int postNo = _posts.length - i;

      // 集計
      final int points = int.tryParse(post['deductionPoints']?.toString() ?? '0') ?? 0;
      totalDeductionPoints += points;
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
                  color: const Color.fromARGB(255, 249, 254, 255),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      const Row(
                        children: [
                          Icon(Icons.search, size: 20, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('項目を検索', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // ドロップダウン検索機能 (Autocomplete)
                      LayoutBuilder(
                        builder: (context, constraints) => Autocomplete<ViolationItem>(
                          displayStringForOption: (option) => option.name,
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<ViolationItem>.empty();
                            }
                            // 全カテゴリーから検索対象の項目を収集
                            final allItems = categories.expand((cat) => cat.items).toList();
                            final queries = textEditingValue.text.toLowerCase().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
                            
                            return allItems.where((item) {
                              return queries.every((q) =>
                                  item.name.toLowerCase().contains(q) ||
                                  item.tags.any((tag) => tag.toLowerCase().contains(q)));
                            });
                          },
                          onSelected: (ViolationItem selection) {
                            _onViolationSelected(selection);
                            // 選択後はフォーカスを外してキーボードを閉じる
                            FocusScope.of(context).unfocus();
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search, size: 20),
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                                suffixIcon: controller.text.isNotEmpty 
                                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => controller.clear()) 
                                  : null,
                              ),
                            );
                          },
                          // ドロップダウンのデザイン
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: constraints.maxWidth,
                                  constraints: const BoxConstraints(maxHeight: 250),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final option = options.elementAt(index);
                                      return ListTile(
                                      title: Text(option.name, style: const TextStyle(fontSize: 14)), // 項目名のみ表示
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
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
                      // カテゴリ選択(横スクロールチップ形式に変更:項目が増えても対応可能)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 234, 242, 247), // 全体の薄い背景色
                            borderRadius: BorderRadius.circular(12),
                          ),
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width - 64,
                          ), // ここにカンマが必要です
                          child: Row(
                          children: List<Widget>.generate(categories.length, (i) {
                            final isSelected = _selectedCategoryIndex == i;
                            return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryIndex = i;
                                    _selectedViolation = null;
                                    _selectedDeductionReason = '未選択';
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.blueAccent : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? Colors.blueAccent : Colors.transparent,
                                    ),
                                    boxShadow: isSelected ? [
                                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                                    ] : null,
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
                              ); // ここは return なのでセミコロン (;) が適切です
                          }),
                        ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _submitPost,
                            icon: const Icon(Icons.send),
                            label: const Text('登録する'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
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
            ),
            if (tabIndex == 0) ...[
              const SizedBox(height: 16),
              _buildSearchFilterSection(totalDeductionPoints),
            ],
            if (tabIndex > 0) ...[
              const SizedBox(height: 16),
              _buildGradeSummarySection(tabIndex, classTotals),
            ],
            const SizedBox(height: 16),
            const _SectionHeader(icon: Icons.history_edu, title: '投稿履歴'),
          ], // Columnのchildrenリストを閉じるカッコ
        ), // Columnを閉じるカッコ
      ), // SliverToBoxAdapterを閉じるカッコ
    ), // SliverPaddingを閉じるカッコ
        if (_isTableView)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverToBoxAdapter(child: _buildSummaryTable(displayedPosts)),
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

  // 検索フィルター部分をメソッド化してコードを整理
  Widget _buildSearchFilterSection(int totalDeductionPoints) {
    return Card(
              color: const Color.fromARGB(255, 242, 249, 255), // 検索欄であることがわかりやすい背景色
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blueGrey.withOpacity(0.1)),
              ),
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list, size: 18, color: Colors.blueGrey),
                    const SizedBox(width: 4),
                    // 合計点数表示エリア:Expandedを使って、ピッカーの位置が左右に動かないように固定
                    Expanded(
                      child: _isSearchFilterActive
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '$totalDeductionPoints点',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700],
                                    fontSize: 24, // 枠内で最大級に大きく
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (!_isSearchFilterActive) const Spacer(), // 検索前はピッカーを右に寄せる

                    // ホイールピッカー部分 (右側のアイコン横に寄せる)
                    AbsorbPointer(
                      absorbing: _isSearchFilterActive, // 検索中は操作を無効化(固定)
                      child: Opacity(
                        opacity: _isSearchFilterActive ? 0.5 : 1.0, // 固定されていることがわかるよう半透明に
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPickerContainer(
                              width: 42,
                              picker: CupertinoPicker(
                                scrollController: _searchYearPicker,
                                itemExtent: 32.0,
                                onSelectedItemChanged: (int index) {
                                  setState(() {
                                    _searchFilterYear = index + 1;
                                  });
                                },
                                children: List<Widget>.generate(3, (int index) => Center(child: Text('${index + 1}'))),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 2.0), // 間隔を縮小
                              child: Text('年', style: TextStyle(fontSize: 12, color: Colors.blueGrey)), 
                            ),
                            _buildPickerContainer(
                              width: 42,
                              picker: CupertinoPicker(
                                scrollController: _searchClassPicker,
                                itemExtent: 32.0,
                                onSelectedItemChanged: (int index) {
                                  setState(() {
                                    _searchFilterClass = (index + 1).toString();
                                  });
                                },
                                children: List<Widget>.generate(9, (int index) => Center(child: Text('${index + 1}'))),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 2.0), // 間隔を縮小
                              child: Text('組', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _isSearchFilterActive = true),
                      icon: const Icon(Icons.search, color: Colors.blueAccent),
                      tooltip: '検索',
                    ),
                    if (_isSearchFilterActive)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() {
                            _isSearchFilterActive = false;
                            // クリア時にピッカーをリセットせず、現在の位置を保持(勝手に動かさない)
                          });
                        },
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        tooltip: 'クリア',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
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
                        color: isSelected ? Colors.blue : Colors.blueGrey.withOpacity(0.1),
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

    if (_isLargeImageMode && imagePath.isNotEmpty) {
      return Card(
        clipBehavior: Clip.antiAlias,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 16),
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
              _buildImageWidget(imagePath, width: double.infinity, height: 200),
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
      margin: const EdgeInsets.only(bottom: 12),
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
              child: _buildImageWidget(item['imagePath'], size: 50),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        key: ValueKey('table_${displayedPosts.length}'),
        columnSpacing: 16.0,
        columns: const [
          DataColumn(label: Text('No.', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('クラス', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('減点数', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('理由', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('備考', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('名前', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: List<DataRow>.generate(displayedPosts.length, (index) {
          final item = displayedPosts[index];
          return DataRow(
            cells: [
              DataCell(Text('${item['_uiNumber'] ?? 0}'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(post: item)))),
              DataCell(Text(item['class']?.toString() ?? '')),
              DataCell(Text(item['deductionPoints']?.toString() ?? '')),
              DataCell(Text(item['deductionReason']?.toString() ?? '')),
              DataCell(SizedBox(width: 100, child: Text(item['remarks']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis))),
              DataCell(Text(item['name']?.toString() ?? '不明')),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildImageWidget(String? imagePath, {double? size, double? width, double? height}) {
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
                errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: iconSize),
              )
            : (imagePath.length > 50) // Base64として妥当な長さか簡易チェック
                ? Image.memory(
                    base64Decode(imagePath),
                    width: w, height: h, fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    gaplessPlayback: true,
                    // Webや制約なしの場合に 0 にならないよう保護
                    cacheWidth: (cacheW != null && cacheW > 0) ? cacheW : null,
                    cacheHeight: (cacheH != null && cacheH > 0) ? cacheH : null,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: iconSize),
                  )
                : Icon(Icons.broken_image, size: iconSize),
      );
    } catch (_) {
      return Icon(Icons.broken_image, size: iconSize);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Row(children: [Icon(icon, color: Colors.blueGrey), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]));
  }
}
