import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'dart:typed_data'; // Uint8Listのため
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestoreのインポート
import 'package:firebase_storage/firebase_storage.dart'; // Storageのインポート
import 'package:firebase_auth/firebase_auth.dart'; // Authのインポート
import 'package:flutter/foundation.dart'; // kIsWeb を使うため
import 'post_detail_screen.dart'; // Import the new detail screen
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'date_helpers.dart'; // インポートパスを修正

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

  const ViolationItem(this.name, this.minPoints, {int? maxPoints, this.isCommon = false, this.tags = const []})
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

// 違反項目の定義
const ViolationItem _rehaJikanChoka = ViolationItem('リハで時間超過', 7);
const ViolationItem _butaiWasuremono = ViolationItem('舞台撤退時忘れ物', 1);
const ViolationItem _kikenNaOdogu = ViolationItem('危険な大道具の使用', 12);
const ViolationItem _mutodokeWaremono = ViolationItem('無届での割れ物の使用', 8);
const ViolationItem _jyoenJikokuChoka = ViolationItem('上演時刻超過', 20);

const ViolationItem _taikoGoKitaChukan = ViolationItem('退校時間後北館、中館にいる', 1);
const ViolationItem _gaishutsuTodoke = ViolationItem('外出届を携帯せず外出', 20);
const ViolationItem _jikanGaiSagyoo = ViolationItem('指定時間外での作業', 3);
const ViolationItem _bashoGaiSagyoo = ViolationItem('指定場所以外での作業', 3);
const ViolationItem _igaiSanka = ViolationItem('本校生徒、職員以外の参加', 15);

const ViolationItem _koguFunshitsu = ViolationItem('クラス工具紛失、未返却', 5);
const ViolationItem _seitoKaiKoguMiHenkyaku = ViolationItem('生徒会工具未返却', 3);
const ViolationItem _seitoKaiKoguFunshitsu = ViolationItem('生徒会工具紛失', 8);
const ViolationItem _yakuinIgaiKariiru = ViolationItem('役員以外が生徒会工具を借りる', 1);
const ViolationItem _mataKashiMudai = ViolationItem('生徒会工具の又貸し、無断借用', 1);
const ViolationItem _kyokaNashiDenko = ViolationItem('許可無し電動工具使用', 15);
const ViolationItem _shibutsuKoguViolation = ViolationItem('私物工具使用許可証への違反行為', 10);
const ViolationItem _denkoKiken = ViolationItem('電動工具による危険行為', 10);
const ViolationItem _fuyonaToden = ViolationItem('不必要な時間、長時間の盗電行為', 5);
const ViolationItem _mishinFuteki = ViolationItem('ミシンの不適切な取扱い', 3);
const ViolationItem _seisoFubi = ViolationItem('作業場所の清掃不備', 3, maxPoints: 20, tags: ['ペンキ', 'ガムテープ', '汚れ']);
const ViolationItem _kikenbutsuHouchi = ViolationItem('下校時刻後に危険物を放置', 5);
const ViolationItem _penkiIgaiNagashi = ViolationItem('ペンキを指定場所以外に流す', 12, tags: ['水道', '排水', '汚染']);
const ViolationItem _shiyoKinshi = ViolationItem('使用禁止物の使用', 10);
const ViolationItem _gomiBunbetsu = ViolationItem('ごみの分別不備、不適切廃棄', 3);
const ViolationItem _inpeiKyogi = ViolationItem('隠蔽、虚偽の報告、認めない', 10, maxPoints: 20);
const ViolationItem _sonshoRakugaki = ViolationItem('設備、備品、工具の破損、落書き', 3, maxPoints: 20, tags: ['壊した', '机', '椅子', '壁']);

const ViolationItem _tareMakuRakka_3rd = ViolationItem('垂れ幕、装飾が展示中に落下', 20);
const ViolationItem _tareMakuRakka_1_2nd = ViolationItem('垂れ幕、装飾が展示中に落下', 10);
const ViolationItem _gakujitsuInNashi = ViolationItem('学実の印が無い看板等の使用', 5);
const ViolationItem _keihinHaifu = ViolationItem('景品を配布する', 10, tags: ['お菓子', 'プレゼント']);
const ViolationItem _anzenKake = ViolationItem('安全性に欠けたPR', 5);
const ViolationItem _jyuGoYakuKyokaNashi = ViolationItem('15役から許可の無いPR', 4);

const ViolationItem _sekkeiZutoKotonaru = ViolationItem('提出した設計図と異なる構造で制作', 20);
const ViolationItem _kyokaNashiPoleIgai = ViolationItem('許可なしにポール以外の支柱を使用', 17, tags: ['15役']);
const ViolationItem _rokaHamiDashi = ViolationItem('廊下へ30㎝以上はみ出した制作', 5, tags: ['建築物']);
const ViolationItem _kaijoJiniNyujoFukano = ViolationItem('会場時に来場者が入場できない状態', 5);

List<ViolationCategory> getViolationDataForGrade(int grade) {
  if (grade == 3) {
    
    return [
      ViolationCategory('ステージ', [
        _rehaJikanChoka,
        _butaiWasuremono,
        _kikenNaOdogu,
        _mutodokeWaremono,
        _jyoenJikokuChoka,
      ]),
      ViolationCategory('学校祭', [
        _taikoGoKitaChukan,
        _gaishutsuTodoke,
        _jikanGaiSagyoo,
        _bashoGaiSagyoo,
        _igaiSanka,
      ]),
      ViolationCategory('資材', [
        _koguFunshitsu,
        _seitoKaiKoguMiHenkyaku,
        _seitoKaiKoguFunshitsu,
        _yakuinIgaiKariiru,
        _mataKashiMudai,
        _kyokaNashiDenko,
        _shibutsuKoguViolation,
        _denkoKiken,
        _fuyonaToden,
        _mishinFuteki,
        _seisoFubi,
        _kikenbutsuHouchi,
        _penkiIgaiNagashi,
        _shiyoKinshi,
        _gomiBunbetsu,
        _inpeiKyogi,
        _sonshoRakugaki,
      ]),
      ViolationCategory('PR', [
        _tareMakuRakka_3rd,
        _gakujitsuInNashi,
        _keihinHaifu,
        _anzenKake,
        _jyuGoYakuKyokaNashi,
      ]),
    ];
  } else {
    // 1,2年生用の32項目 (サンプル)
    return [
      ViolationCategory('展示', [
        _sekkeiZutoKotonaru,
        _kyokaNashiPoleIgai,
        _rokaHamiDashi,
        _kaijoJiniNyujoFukano,
      ]),
      ViolationCategory('学校祭', [ _taikoGoKitaChukan, _gaishutsuTodoke, _jikanGaiSagyoo, _bashoGaiSagyoo, _igaiSanka, ]),
      ViolationCategory('資材', [ _koguFunshitsu, _seitoKaiKoguMiHenkyaku, _seitoKaiKoguFunshitsu, _yakuinIgaiKariiru, _mataKashiMudai, _kyokaNashiDenko, _shibutsuKoguViolation, _denkoKiken, _fuyonaToden, _mishinFuteki, _seisoFubi, _kikenbutsuHouchi, _penkiIgaiNagashi, _shiyoKinshi, _gomiBunbetsu, _inpeiKyogi, _sonshoRakugaki, ]),
      ViolationCategory('PR', [ _tareMakuRakka_1_2nd, _gakujitsuInNashi, _keihinHaifu, _anzenKake, _jyuGoYakuKyokaNashi, ]),
    ];
  }
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _remarksController = TextEditingController();
  final _postNumberController = TextEditingController(); // 投稿番号入力用
  final _nameController = TextEditingController(); // 投稿者名入力用
  List<Map<String, dynamic>> _posts = []; // Firestoreから取得したデータを保持
  Map<String, dynamic>? _editingPost; // 編集中の投稿データを保持
  DateTime? _selectedPostDate; // ユーザーが選択した違反日
  
  final List<List<Map<String, dynamic>>> _filteredPostsCache = [[], [], [], []];
  final List<Map<int, int>> _classTotalsCache = [{}, {}, {}, {}];
  final List<Map<int, int>> _archivedClassTotalsCache = [{}, {}, {}, {}];
  StreamSubscription? _postsSubscription; // リアルタイム更新の購読
  int _selectedValue1 = 1;
  String _selectedValue2 = '1';
  bool _isPosting = false; // 投稿中かどうかを管理するフラグ
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

  // よく使う項目だけを抽出するヘルパー
  // 利用回数が多い項目をクイック選択用に抽出する
  List<ViolationItem> _getQuickSelectItems() {
    final List<ViolationItem> allItems = [];
    // 全ての学年のカテゴリーから項目を収集
    for (int grade = 1; grade <= 3; grade++) {
      final categories = getViolationDataForGrade(grade);
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
      final allCategories = getViolationDataForGrade(_selectedValue1);
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

  static const int _minRequiredTags = 5; // 担当者タグの最低選択数

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
    _postNumberController.dispose();
    _nameController.dispose();
    // _selectedPostDate は DateTime なので dispose は不要
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
      imageQuality: 80, // 軽量化と画質維持のバランスを調整
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes(); // 画像をバイトデータとして読み込む
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  // 日付選択ダイアログを表示する
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedPostDate ?? DateTime.now(),
      firstDate: DateTime(2023), // 過去の日付を選択可能に
      lastDate: DateTime.now(),   // 未来の日付は選択不可
    );
    if (picked != null && picked != _selectedPostDate) {
      setState(() {
        _selectedPostDate = picked;
      });
    }
  }

  // 3日以上経過した未処理の投稿をチェックして履歴を更新する
  Future<void> _checkForOverduePosts(List<QueryDocumentSnapshot> docs) async {
    final now = DateTime.now();
    final batch = FirebaseFirestore.instance.batch();
    int updates = 0;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      // 1. 審議中や処理済み(非表示)の投稿はスキップ
      final String? status = data['discussionStatus'];
      final bool isHidden = data['isHidden'] ?? false;
      if (status != null || isHidden) {
        continue;
      }

      // 2. 違反日または投稿日から3日経過しているかチェック
      final String? referenceDateStr = data['violationDate'] ?? data['timestamp'];
      if (referenceDateStr == null) continue;
      
      try {
        final referenceDate = DateTime.parse(referenceDateStr);
        if (now.difference(referenceDate).inDays < 3) {
          continue; // 3日未満なのでスキップ
        }
      } catch (e) {
        continue; // 日付の解析に失敗したらスキップ
      }

      // 3. 既に履歴が追加されていないかチェック
      final List<dynamic> history = data['statusHistory'] ?? [];
      final bool alreadyIssued = history.any((h) => h is Map && h['type'] == 'notification_issued');
      if (alreadyIssued) {
        continue;
      }

      // 4. 更新対象としてバッチに追加
      updates++;
      batch.update(doc.reference, {
        'statusHistory': FieldValue.arrayUnion([
          {'type': 'notification_issued', 'timestamp': now.toIso8601String(), 'reason': '減点通知書発行 (3日経過)'}
        ])
      });
    }

    // 更新対象があればバッチ処理を実行
    if (updates > 0) {
      debugPrint('$updates 件の投稿に「減点通知書発行」の履歴を追加します。');
      await batch.commit();
    }
  }

  // Firestoreのデータをリアルタイムで監視する
  void _listenToPosts() {
    _postsSubscription = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('postNumber', descending: true) // 番号の大きい順(新しい順)に取得
        .snapshots()
        .listen((snapshot) {
      // 3日経過した投稿がないかチェックして更新する
      _checkForOverduePosts(snapshot.docs);

      setState(() {
        _posts = snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id; // ドキュメントIDを保持(削除や更新に必要)
          
          // 古い 'image' フィールド(Base64)と新しい 'imagePath' (URL) の両方に対応
          final String imagePath = data['imagePath'] ?? data['image'] ?? '';
          if (imagePath.isNotEmpty) {
            data['imagePath'] = imagePath; // データを imagePath に統一
            // Base64形式の画像であればデコードしてキャッシュしておく
            if (!imagePath.startsWith('http')) {
              try {
                data['_cachedUint8List'] = base64Decode(imagePath);
              } catch (_) {}
            }
          }
          return data;
        }).toList();
        
        _precalculateTabData();
      });
    }, onError: (e) => debugPrint('Firestoreエラー: $e'));
  }

  // データを事前に計算してビルド時の負荷を減らす
  void _precalculateTabData() {
    for (int i = 0; i < 4; i++) {
      _filteredPostsCache[i] = [];
      _classTotalsCache[i] = {for (var k = 1; k <= 9; k++) k: 0};
      _archivedClassTotalsCache[i] = {for (var k = 1; k <= 9; k++) k: 0};
    }

    for (var post in _posts) {
      final String postClass = (post['class']?.toString() ?? '').trim();
      final int points = int.tryParse(post['deductionPoints']?.toString() ?? '0') ?? 0;
      
      for (int tabIndex = 0; tabIndex < 4; tabIndex++) {
        // タブごとの学年フィルタ
        if (tabIndex > 0) {
          if (!postClass.startsWith('${tabIndex}年')) continue;
          
          // クラス集計
          final match = _classRegex.firstMatch(postClass);
          if (match != null) {
            final classNum = int.tryParse(match.group(1)!);
            if (classNum != null) {
              final bool isHidden = post['isHidden'] ?? false;
              final bool isDeduction = post['discussionStatus'] == 'deduction';

              if (!isHidden && !isDeduction) {
                // 有効な減点を集計
                if (_classTotalsCache[tabIndex].containsKey(classNum)) {
                  _classTotalsCache[tabIndex][classNum] = (_classTotalsCache[tabIndex][classNum] ?? 0) + points;
                }
              } else {
                // 取り消し・審議中の減点を集計
                if (_archivedClassTotalsCache[tabIndex].containsKey(classNum)) {
                  _archivedClassTotalsCache[tabIndex][classNum] = (_archivedClassTotalsCache[tabIndex][classNum] ?? 0) + points;
                }
              }
            }
          }
        }
        
        _filteredPostsCache[tabIndex].add(post);
      }
    }
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
    final bool isDeductionState = item['discussionStatus'] == 'deduction';
    final List<String> tagOptions = [
      '中村', '本田', '中谷内', '若田',
      '小林', '黒瀬', '田島', '今井',
      '福田', '赤塚', '大石', '上野',
      '長窪', '曽根', '間瀬', '花植'
    ];
    List<String> selectedTags = [];
    bool isUploading = false;

    final TextEditingController reasonController = TextEditingController();
    if (isDeductionState) {
      // 「口頭可能」タグがついている場合の最終判断ダイアログ
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('議論結果の最終判断'),
                content: SingleChildScrollView( // スクロール可能にする
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isUploading) const Padding(padding: EdgeInsets.only(bottom: 16), child: CircularProgressIndicator()),
                      const Text('この項目の最終的な扱いを選択してください。'),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: reasonController,
                        decoration: const InputDecoration(labelText: '備考', border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('誰が担当しましたか？:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: tagOptions.map((tag) {
                          final isSelected = selectedTags.contains(tag);
                          return FilterChip(
                            label: Text(tag, style: const TextStyle(fontSize: 11)),
                            selected: isSelected,
                            onSelected: isUploading ? null : (bool selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedTags.add(tag);
                                } else {
                                  selectedTags.remove(tag);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: isUploading ? null : () => Navigator.pop(context), child: const Text('キャンセル')),
                  ElevatedButton(
                    onPressed: (isUploading || selectedTags.length < _minRequiredTags) ? null : () async {
                      setDialogState(() => isUploading = true);
                      try {
                        await FirebaseFirestore.instance.collection('posts').doc(item['id']).update({
                          'isHidden': true, // アーカイブに表示
                          'discussionStatus': 'cancelled', // ステータスを「取り消し済み」に設定
                          'cancellationTags': selectedTags,
                          'restoreReason': reasonController.text.isNotEmpty ? reasonController.text : FieldValue.delete(),
                          'statusHistory': FieldValue.arrayUnion([{
                            'type': 'cancelled', // 取り消し確定
                            'timestamp': DateTime.now().toIso8601String(),
                            'reason': '担当者: ${selectedTags.join(", ")}\n備考: ${reasonController.text}',
                          }]),
                        });
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        setDialogState(() => isUploading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
                    child: const Text('減点取り消し'),
                  ),
                  ElevatedButton(
                    onPressed: (isUploading || selectedTags.length < _minRequiredTags) ? null : () async {
                      setDialogState(() => isUploading = true);
                      try {
                        await FirebaseFirestore.instance.collection('posts').doc(item['id']).update({
                          'isHidden': false, // ホームへ移動
                          'discussionStatus': 'finalized', // ステータスを「確定済み」に設定
                          'discussionTimestamp': DateTime.now().toIso8601String(), // 3日間のカウントダウン開始
                          'cancellationTags': selectedTags,
                          'restoreReason': reasonController.text.isNotEmpty ? reasonController.text : FieldValue.delete(),
                          'statusHistory': FieldValue.arrayUnion([{
                            'type': 'finalized_deduction',
                            'timestamp': DateTime.now().toIso8601String(),
                            'reason': '担当者: ${selectedTags.join(", ")}\n備考: ${reasonController.text}',
                          }]),
                        });
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        setDialogState(() => isUploading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: const Text('減点'),
                  ),
                ],
              );
            },
          );
        },
      );
      reasonController.dispose();
      return;
    }

    // If the post is already hidden (yellow tag or cancelled)
    if (item['isHidden'] == true) {
      final TextEditingController reasonController = TextEditingController();
      // すでに非表示の場合は、単に表示に戻す
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('減点処理の選択'), // タイトル変更
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isUploading) const Padding(padding: EdgeInsets.only(bottom: 16), child: CircularProgressIndicator()),
                      const Text('この項目に対する対応を選択してください。'),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: reasonController,
                        decoration: const InputDecoration(labelText: '議論結果・担当者など', border: OutlineInputBorder()),
                        maxLines: 2, // 複数行入力可能
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('タグ選択 ($_minRequiredTagsつ以上選択してください):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: tagOptions.map((tag) {
                          final isSelected = selectedTags.contains(tag);
                          return FilterChip(
                            label: Text(tag, style: const TextStyle(fontSize: 11)),
                            selected: isSelected,
                            onSelected: isUploading ? null : (bool selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedTags.add(tag);
                                } else {
                                  selectedTags.remove(tag);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: isUploading ? null : () => Navigator.pop(context), child: const Text('キャンセル')),
                  ElevatedButton(
                    onPressed: (isUploading || selectedTags.length < _minRequiredTags) ? null : () async {
                      setDialogState(() => isUploading = true);
                      try {
                        await FirebaseFirestore.instance.collection('posts').doc(item['id']).update({
                          'isHidden': true, // アーカイブに表示
                          'discussionStatus': 'cancelled', // ステータスを「取り消し済み」に設定
                          'discussionTimestamp': FieldValue.delete(),
                          'cancellationTags': selectedTags,
                          'restoreReason': reasonController.text.isNotEmpty ? reasonController.text : FieldValue.delete(),
                          'statusHistory': FieldValue.arrayUnion([{
                            'type': 'cancelled',
                            'timestamp': DateTime.now().toIso8601String(),
                            'reason': '担当者: ${selectedTags.join(", ")}\n備考: ${reasonController.text}',
                          }]),
                        });
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        setDialogState(() => isUploading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
                    child: const Text('減点取り消し'),
                  ),
                  ElevatedButton(
                    onPressed: (isUploading || selectedTags.length < _minRequiredTags) ? null : () async {
                      setDialogState(() => isUploading = true);
                      try {
                        await FirebaseFirestore.instance.collection('posts').doc(item['id']).update({
                          'isHidden': false, // ホーム画面へ
                          'discussionStatus': 'finalized', // タグを表示しない
                          'discussionTimestamp': DateTime.now().toIso8601String(), // カウントダウン開始
                          'cancellationTags': selectedTags,
                          'restoreReason': reasonController.text.isNotEmpty ? reasonController.text : FieldValue.delete(),
                          'statusHistory': FieldValue.arrayUnion([{
                            'type': 'finalized_deduction', // 減点確定（アイコン非表示用）
                            'timestamp': DateTime.now().toIso8601String(),
                            'reason': '担当者: ${selectedTags.join(", ")}\n備考: ${reasonController.text}',
                          }]),
                        });
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        setDialogState(() => isUploading = false);
                      }
                    }, // 「減点取り消し」ボタンのロジック
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    child: const Text('減点'),
                  ),
                ],
              );
            },
          );
        },
      );
      reasonController.dispose();
      return;
    }

    // 非表示にする際の画像選択ダイアログ
    Uint8List? tempBytes;

    await showDialog(
      context: context, // コンテキスト
      barrierDismissible: false, // アップロード中の誤操作を防止
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('減点審議'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isUploading)
                        const Padding(padding: EdgeInsets.only(bottom: 16), child: CircularProgressIndicator()),
                      TextFormField(
                        controller: reasonController, // 理由入力コントローラ
                        decoration: const InputDecoration(
                          labelText: '備考',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('誰が担当しましたか？:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: tagOptions.map((tag) {
                          final isSelected = selectedTags.contains(tag);
                          return FilterChip(
                            label: Text(tag, style: const TextStyle(fontSize: 11)),
                            selected: isSelected,
                            onSelected: isUploading ? null : (bool selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedTags.add(tag);
                                } else {
                                  selectedTags.remove(tag);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // 以前の画像選択部分をここに移動
                      const Text('弁明書の写真を添付してください'),
                      const SizedBox(height: 12),
                      if (tempBytes != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Image.memory(tempBytes!, height: 120, fit: BoxFit.cover),
                        ),
                      OutlinedButton.icon(
                        onPressed: isUploading ? null : () async {
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
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: (isUploading || selectedTags.length < _minRequiredTags) ? null : () async {
                    setDialogState(() => isUploading = true);
                    try {
                      String hiddenImageUrl = '';
                      if (tempBytes != null) {
                        final ref = FirebaseStorage.instance
                            .ref()
                            .child('hidden_reasons/${DateTime.now().millisecondsSinceEpoch}.jpg');
                        await ref.putData(tempBytes!);
                        hiddenImageUrl = await ref.getDownloadURL();
                      }
                      await FirebaseFirestore.instance.collection('posts').doc(item['id']).update({
                        'isHidden': true, // 取り消した減点タブへ移動
                        'discussionStatus': 'cancelled', // ステータスを「取り消し済み」に設定
                        'discussionTimestamp': DateTime.now().toIso8601String(), // 3日間のカウントダウン開始
                        'hiddenReasonImage': hiddenImageUrl.isNotEmpty ? hiddenImageUrl : FieldValue.delete(), // 弁明書写真
                        'cancellationTags': selectedTags,
                        'restoreReason': reasonController.text,
                        'statusHistory': FieldValue.arrayUnion([{
                          'type': 'cancelled',
                          'timestamp': DateTime.now().toIso8601String(),
                          'reason': '担当者: ${selectedTags.join(", ")}\n備考: ${reasonController.text}',
                        }]),
                      });
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      setDialogState(() => isUploading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
                  child: const Text('減点取り消し'),
                ),
                ElevatedButton(
                  onPressed: (isUploading || selectedTags.length < _minRequiredTags) ? null : () async {
                    setDialogState(() => isUploading = true);
                    try {
                      String? hiddenImageUrl; // null許容型に変更
                      if (tempBytes != null) {
                        final ref = FirebaseStorage.instance
                            .ref()
                            .child('hidden_reasons/${DateTime.now().millisecondsSinceEpoch}.jpg');
                        await ref.putData(tempBytes!);
                        hiddenImageUrl = await ref.getDownloadURL();
                      }
                    // Firestoreのデータを更新
                    await FirebaseFirestore.instance.collection('posts').doc(item['id']).update({
                      'isHidden': false, // ホーム画面に表示 (赤タグ)
                      'discussionStatus': 'deduction', // ステータスを「審議中」に設定
                      'discussionTimestamp': DateTime.now().toIso8601String(), // 審議開始日時を記録
                      'hiddenReasonImage': hiddenImageUrl ?? FieldValue.delete(), // nullならフィールドごと削除
                      'cancellationTags': selectedTags,
                      'restoreReason': reasonController.text.isNotEmpty ? reasonController.text : FieldValue.delete(),
                      'statusHistory': FieldValue.arrayUnion([
                        {
                          'type': 'discussion_started',
                          'timestamp': DateTime.now().toIso8601String(),
                          'reason': '担当者: ${selectedTags.join(", ")}\n備考: ${reasonController.text}',
                        }
                      ]),
                    });
                    if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      debugPrint('取り消しエラー: $e');
                      setDialogState(() => isUploading = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('エラーが発生しました。通信環境を確認して再度お試しください。')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: const Text('減点'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 編集モードを開始する
  void _startEditing(Map<String, dynamic> post) {
    setState(() {
      _editingPost = post;
      _isPostFormExpanded = true; // フォームを開く

      // フォームに既存のデータを設定
      _postNumberController.text = (post['postNumber'] ?? '').toString();
      _remarksController.text = post['remarks'] ?? '';
      _nameController.text = post['name'] ?? ''; // 投稿者名をセット
      _selectedPostDate = post['violationDate'] != null ? DateTime.parse(post['violationDate']) : null;

      final String postClass = post['class'] ?? '1年1組';
      final gradeMatch = RegExp(r'(\d+)年').firstMatch(postClass);
      final classMatch = RegExp(r'(\d+)組').firstMatch(postClass);

      _selectedValue1 = int.tryParse(gradeMatch?.group(1) ?? '1') ?? 1;
      _selectedValue2 = classMatch?.group(1) ?? '1';

      _yearController.jumpToItem(_selectedValue1 - 1);
      _classController.jumpToItem(int.parse(_selectedValue2) - 1);

      final String reason = post['deductionReason'] ?? '未選択';
      final int points = int.tryParse(post['deductionPoints']?.toString() ?? '1') ?? 1;

      // 理由に一致するViolationItemを探す
      final allItems = getViolationDataForGrade(1).expand((cat) => cat.items).toList()
        ..addAll(getViolationDataForGrade(2).expand((cat) => cat.items))
        ..addAll(getViolationDataForGrade(3).expand((cat) => cat.items));
      
      final violation = allItems.firstWhere((item) => item.name == reason, orElse: () => allItems.first);

      _onViolationSelected(violation);
      _selectedDeductionPoints = points;

      // 点数ピッカーを更新
      if (violation.minPoints != violation.maxPoints) {
        final pickerIndex = points - violation.minPoints;
        if (_deductionPointsPicker.hasClients && pickerIndex >= 0) {
          _deductionPointsPicker.jumpToItem(pickerIndex);
        }
      }
      // 画像は編集不可とするため、クリア
      _imageBytes = null;
    });
  }
  Future<void> _submitPost() async {
    debugPrint('投稿処理を開始します...');
    if (_isPosting) return;

    // 備考に入力がある、画像が選択されている、または減点数が設定されている場合に投稿を許可
    // 投稿番号の手動入力チェック
    if (_postNumberController.text.isNotEmpty) {
      final postNumber = int.tryParse(_postNumberController.text);
      final query = await FirebaseFirestore.instance.collection('posts').where('postNumber', isEqualTo: postNumber).limit(1).get();
      if (query.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: 投稿番号 $postNumber は既に使用されています。'), backgroundColor: Colors.red));
        return; // 処理を中断
      }
    }

    if (_remarksController.text.isNotEmpty ||
        _imageBytes != null ||
        _selectedDeductionPoints > 0) {
      
      debugPrint('入力バリデーションOK');
      setState(() => _isPosting = true);

      // 編集モードの場合の処理
      if (_editingPost != null) {
        try {
          final docRef = FirebaseFirestore.instance.collection('posts').doc(_editingPost!['id']);
          final violationDate = _selectedPostDate ?? DateTime.parse(_editingPost!['timestamp']);
          final bool isOverdue = DateTime.now().difference(violationDate).inDays >= 3;

          // 履歴の更新ロジック
          List<dynamic> currentHistory = List.from(_editingPost!['statusHistory'] ?? []);
          final bool hasIssueNotification = currentHistory.any((h) => h is Map && h['type'] == 'notification_issued');

          if (isOverdue && !hasIssueNotification) {
            // 3日以上経過していて、まだ通知履歴がなければ追加
            currentHistory.add({
              'type': 'notification_issued',
              'timestamp': DateTime.now().toIso8601String(),
              'reason': '減点通知書発行 (3日経過)'
            });
          } else if (!isOverdue && hasIssueNotification) {
            // 3日未満になり、通知履歴があれば削除
            currentHistory.removeWhere((h) => h is Map && h['type'] == 'notification_issued');
          }

          await docRef.update({
            'class': '$_selectedValue1年$_selectedValue2組',
            'deductionPoints': _selectedDeductionPoints.toString(),
            'deductionReason': _selectedDeductionReason,
            'remarks': _remarksController.text,
            'name': _nameController.text, // 投稿者名を更新
            'violationDate': violationDate.toIso8601String(), // 違反日を更新
            // 編集者と日時を記録（任意）
            'lastEditedBy': widget.username,
            'lastEditedAt': DateTime.now().toIso8601String(),
            'statusHistory': currentHistory, // 更新された履歴を保存
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('変更を保存しました。')));
            setState(() => _editingPost = null); // 編集モードを終了
            _resetForm(); // フォームをリセット
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新エラー: $e')));
          }
        } finally {
          if (mounted) {
            setState(() => _isPosting = false);
          }
        }
        return; // 新規投稿処理は行わない
      }

      // --- 以下、新規投稿処理 ---
      try {
        // 統計情報の更新
        if (_selectedDeductionReason != '未選択') {
          _incrementViolationCount(_selectedDeductionReason);
        }

        String imageUrl = '';
        if (_imageBytes != null) {
          debugPrint('画像をアップロード中...');
          final ref = FirebaseStorage.instance
              .ref()
              .child('post_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
          await ref.putData(_imageBytes!);
          imageUrl = await ref.getDownloadURL();
          debugPrint('画像アップロード完了: $imageUrl');
        }

        // 投稿番号を安全にインクリメントして新しい投稿を作成する
        final newPostRef = FirebaseFirestore.instance.collection('posts').doc();
        final counterRef = FirebaseFirestore.instance.collection('metadata').doc('postCounter');

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final violationDate = _selectedPostDate ?? DateTime.now();
          final bool isOverdue = DateTime.now().difference(violationDate).inDays >= 3;

          final List<Map<String, String>> history = [
            {'type': 'created', 'timestamp': DateTime.now().toIso8601String(), 'reason': '新規減点登録'}
          ];

          if (isOverdue) {
            history.add({
              'type': 'notification_issued',
              'timestamp': DateTime.now().toIso8601String(),
              'reason': '減点通知書発行 (3日経過)'
            });
          }

          final postData = {
            'class': '$_selectedValue1年$_selectedValue2組',
            'deductionPoints': _selectedDeductionPoints.toString(),
            'deductionReason': _selectedDeductionReason,
            'remarks': _remarksController.text,
            'imagePath': imageUrl,
            'timestamp': DateTime.now().toIso8601String(), // 投稿サーバー時刻
            'violationDate': violationDate.toIso8601String(), // 違反日
            'name': widget.username,
            'isHidden': false,
            'statusHistory': history,
          };

          final counterSnapshot = await transaction.get(counterRef);
          int nextNumber;

          // 手動入力された番号があればそれを使用、なければ自動採番
          if (_postNumberController.text.isNotEmpty) {
            nextNumber = int.parse(_postNumberController.text);
          } else {
            // counterドキュメントが存在しない場合は初期値1で作成
            if (!counterSnapshot.exists) {
              nextNumber = 1;
              transaction.set(counterRef, {'current': 1});
            } else {
              final currentNumber = (counterSnapshot.data()!['current'] as int?) ?? 0;
              nextNumber = currentNumber + 1;
              transaction.update(counterRef, {'current': nextNumber});
            }
          }
          transaction.set(newPostRef, {...postData, 'postNumber': nextNumber});
        });
        debugPrint('Firestoreへの書き込み完了');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '投稿しました: $_selectedDeductionPoints点, 理由: $_selectedDeductionReason',
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          );
        }

        _resetForm();
      } catch (e) {
        debugPrint('投稿エラー: $e');
        if (mounted) {
          // エラー内容を詳細に表示するように変更
          String errorMessage = e.toString();
          if (errorMessage.contains('permission-denied')) errorMessage = '権限エラー：Firebaseのルール期限を確認してください';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('投稿失敗: $errorMessage')),
          );
        }
      } finally {
        if (mounted) setState(() => _isPosting = false);
      }
    }
  }

  // フォームを初期状態にリセットする
  void _resetForm() {
    setState(() {
      _editingPost = null; // 編集モードを解除
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
      _postNumberController.clear();
      _nameController.clear();
      _selectedPostDate = null; // 選択された日付をリセット
      _imageBytes = null;
    });
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
                  // Firebaseからサインアウト
                  await FirebaseAuth.instance.signOut();
                  // ログイン画面に戻る (Navigator.pushReplacementを使用して安全に画面遷移)
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
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
    final List<ViolationCategory> categories = getViolationDataForGrade(_selectedValue1);

    // 事前計算済みのデータを使用
    final List<Map<String, dynamic>> sourcePosts = _filteredPostsCache[tabIndex];
    final Map<int, int> classTotals = _showHiddenOnly ? _archivedClassTotalsCache[tabIndex] : _classTotalsCache[tabIndex];

    final activeFilter = _gradeClassFilters[tabIndex];
    final String? tabClassFilter = (tabIndex > 0 && activeFilter != null) 
        ? '${tabIndex}年${activeFilter}組' : null;
    
    final List<Map<String, dynamic>> displayedPosts = [];
    for (var post in sourcePosts) {
      final bool isHidden = post['isHidden'] ?? false;
      final String? status = post['discussionStatus'];
      // 違反日(violationDate)がなければ投稿日(timestamp)を基準にする
      final String referenceDateStr = post['violationDate'] ?? post['timestamp'] ?? '';

      // 「口頭可能」状態で3営業日経過したか判定
      bool isOralPossibleExpired = false;
      String? refTimestampStr = post['discussionTimestamp']; // 審議開始日時
      if (refTimestampStr == null && referenceDateStr.isNotEmpty) {
        final List<dynamic> history = post['statusHistory'] ?? [];
        final refEvent = history.reversed.firstWhere(
          (e) => e is Map && (e['type'] == 'finalized_deduction' || e['type'] == 'archived_undiscussed' || e['type'] == 'discussion_started'),
          orElse: () => null
        );
        if (refEvent != null) refTimestampStr = refEvent['timestamp'];
      }
      // 審議開始日時がなければ、違反日/投稿日を基準にする
      final dateToCompare = refTimestampStr ?? referenceDateStr;
      if (dateToCompare.isNotEmpty) {
        try {
          final dt = DateTime.parse(dateToCompare);
          isOralPossibleExpired = DateTime.now().isAfter(dt.add(const Duration(days: 3))); // 3暦日後に変更
        } catch (_) {}
      }

      if (_showHiddenOnly) {
        // 「取り消した減点」タブ: 期限切れの口頭可能はホームに戻るが、取り消し確定(cancelled)はここに残す
        // isHiddenフラグが立っている投稿、または'cancelled'状態の投稿を表示する
        // isHiddenがtrueか、statusが'cancelled'の投稿のみ表示する
        if (!(isHidden || status == 'cancelled')) {
          continue;
        }

      } else {
        // メインタブ: 通常表示分 + 期限切れの口頭可能を表示するが、取り消し確定(cancelled)は除外する
        // 表示しない条件:
        // 1. 減点取り消しが確定('cancelled')した投稿
        // 2. 審議待ち('isHidden' == true かつ status が null)の投稿で、まだ期限が切れていないもの
        if (status == 'cancelled') continue;
        // if ((isHidden && status == null) && !isOralPossibleExpired) continue; // 「減点」ボタンで審議中にした投稿も表示するため、この行をコメントアウト
      }

      if (tabClassFilter != null && post['class'] != tabClassFilter) continue;
      
      // 表示用の番号を割り振る(元のリストでの位置に基づく)
      post['_isOralPossibleExpired'] = isOralPossibleExpired; // 判定結果を保持
      displayedPosts.add(post);
    }

    // 並び替え (null安全な比較に修正)
    displayedPosts.sort((a, b) {
      final int numA = a['postNumber'] ?? 0;
      final int numB = b['postNumber'] ?? 0;
      return _sortNewestFirst ? numB.compareTo(numA) : numA.compareTo(numB);
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
                          Text(
                            _editingPost == null ? '減点登録' : '投稿の編集',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Icon(
                            _isPostFormExpanded ? Icons.expand_less : Icons.expand_more,
                              color: const Color(0xFF9E9E9E),
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
                      // 投稿番号入力フィールド
                      TextField(
                        controller: _postNumberController,
                        keyboardType: TextInputType.number,
                        enabled: _editingPost == null, // 編集モードでは番号の変更を不可にする
                        decoration: const InputDecoration(
                          labelText: '投稿番号 (任意)',
                          hintText: '空欄の場合は自動採番',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.numbers),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 投稿者名入力フィールド (編集モードでのみ表示)
                      if (_editingPost != null) ...[
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: '投稿者名',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      // 違反日選択フィールド
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text('違反日', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _selectDate(context),
                            child: Text(
                              _selectedPostDate == null
                                ? '日付を選択 (任意)'
                                : '${_selectedPostDate!.year}/${_selectedPostDate!.month}/${_selectedPostDate!.day}',
                              style: TextStyle(color: _selectedPostDate == null ? Colors.grey : Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
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
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 232, 241, 252), // ← 1. セグメント全体の背景色(後ろの色)
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
                        onChanged: (_) => setState(() {}), // 入力時にボタンの有効状態を更新
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
                            onPressed: (!_isPosting && (_remarksController.text.isNotEmpty || _imageBytes != null || _selectedViolation != null)) ? _submitPost : null,
                            icon: _isPosting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                            label: Text(_isPosting ? '登録中...' : '登録する'),
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
    final int postNumber = item['postNumber'] ?? 0;
    final Uint8List? cachedBytes = item['_cachedUint8List'] as Uint8List?;

    final bool isOralPossibleExpired = item['_isOralPossibleExpired'] == true;

    final String? status = item['discussionStatus'];
    final bool isDeduction = status == 'deduction'; // 口頭可能(審議中)

    // 3日以内の投稿かどうか判定(ナンバリングの色用)
    // 違反日(violationDate)がなければ投稿日(timestamp)を基準にする
    final String referenceDateStr = item['violationDate'] ?? item['timestamp'] ?? '';
    bool isRecent = false;
    if (referenceDateStr.isNotEmpty) {
      try {
        final DateTime referenceDate = DateTime.parse(referenceDateStr);
        isRecent = DateTime.now().isBefore(referenceDate.add(const Duration(days: 3))); // 3日以内なら最近の投稿
      } catch (_) {}
    }
    
    // 「口頭可能」タグが表示される条件（審議中、または初期アーカイブ状態）
    // 減点確定(finalized)や取り消し(cancelled)後はタグを消す (このロジックは_buildStatusTagに移動)
    final bool isOralPossibleActive = !isOralPossibleExpired && (isDeduction || (item['isHidden'] == true && status == null));

    // ナンバリングをピンクにする条件：口頭可能期間中の投稿、または未処理の新規投稿
    // タグが外れた際、およびステータスが確定した時点で灰色（カウント停止）にする
    final bool shouldBePink = isOralPossibleActive || (item['isHidden'] == false && status == null && isRecent);
    final Color numberingColor = shouldBePink ? Colors.pink : Colors.grey;

    // アイコン表示条件: 
    // 1. 期限切れでないこと (!isOralPossibleExpired)
    // 2. アーカイブ内（isHidden: true）で、かつ既に確定（cancelled or finalized）状態でないこと
    // ※ホーム画面（isHidden: false）にある投稿は、警告中・確定後を問わず表示する
    // 減点確定(finalized)または取り消し確定(cancelled)の投稿ではアイコンを非表示にする
    final bool showToggleIcon = (status != 'finalized' && status != 'cancelled') && !isOralPossibleExpired;

    // アイコンとツールチップのテキストを決定
    IconData toggleIconData = Icons.undo;
    String toggleTooltipText = '減点を取り消す'; // デフォルト
    if (item['isHidden'] == true && (status == null || status == 'finalized')) { toggleIconData = Icons.restore; toggleTooltipText = '減点を戻す'; }
    if (status == 'cancelled' || (item['isHidden'] == true && status == null)) { 
      toggleIconData = Icons.restore; 
      toggleTooltipText = '減点を戻す'; 
    }
    else if (isDeduction) { toggleTooltipText = '議論結果を入力'; }

    if (_isLargeImageMode && imagePath.isNotEmpty) {
      return Card(
        clipBehavior: Clip.antiAlias,
        color: Colors.white,
        elevation: 1.0, // 控えめな影
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PostDetailScreen(post: item)),
            );
            if (result is Map && result['action'] == 'edit' && mounted) {
              _startEditing(result['post'] as Map<String, dynamic>);
            }
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
                        Row(
                          children: [
                            Text(
                              'No. $postNumber  ${item['class']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: numberingColor,
                              ),
                            ),
                            _buildStatusTag(item, isRecent),
                          ],
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
                            if (showToggleIcon)
                              IconButton(
                                icon: Icon(toggleIconData, size: 20, color: Colors.grey),
                                onPressed: () => _toggleHidePost(item),
                                tooltip: toggleTooltipText,
                              ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                              onPressed: () => _startEditing(item),
                              tooltip: 'この投稿を編集する',
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
      margin: const EdgeInsets.only(bottom: 12), // Already const
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
              style: TextStyle(color: numberingColor, fontSize: 12),
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
            Row(
              children: [
                Text(
                  '${item['class']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                _buildStatusTag(item, isRecent),
              ],
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
            if (showToggleIcon)
              IconButton( // アイコン表示
                icon: Icon(toggleIconData, color: Colors.grey),
                onPressed: () => _toggleHidePost(item),
                tooltip: toggleTooltipText,
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.grey),
              onPressed: () => _startEditing(item),
              tooltip: 'この投稿を編集する',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () => _deletePost(item),
            ),
          ],
        ),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PostDetailScreen(post: item)),
          );
          // 戻ってきたときに 'edit' アクションがあれば編集を開始
          if (result is Map && result['action'] == 'edit' && mounted) {
            _startEditing(result['post'] as Map<String, dynamic>);
          }
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
                color: const Color(0xFFFFE5E5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${item['deductionPoints']}点',
                style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${item['deductionReason']}',
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
            DataColumn(label: const Text('No', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: const Text('日時', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: const Text('クラス', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: const Text('点数', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: const Text('理由', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: const Text('名前', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: List<DataRow>.generate(displayedPosts.length, (index) {
            final item = displayedPosts[index];

            // 表形式の方でも3日以内判定を行う
            // 違反日(violationDate)がなければ投稿日(timestamp)を基準にする
            final String referenceDateStr = item['violationDate'] ?? item['timestamp'] ?? '';
            bool isRecent = false;
            if (referenceDateStr.isNotEmpty) {
              try {
                final DateTime referenceDate = DateTime.parse(referenceDateStr);
                isRecent = DateTime.now().isBefore(referenceDate.add(const Duration(days: 3)));
              } catch (_) {}
            }

            final bool isOralPossibleExpired = item['_isOralPossibleExpired'] == true;
            final String? status = item['discussionStatus'];
            final bool isHidden = item['isHidden'] == true; // 元の非表示フラグ

            final bool isOralPossibleActive = !isOralPossibleExpired && (status == 'deduction' || (isHidden && status == null));
            final bool shouldBePink = isOralPossibleActive || (isHidden == false && status == null && isRecent);

            return DataRow(
              cells: [
                DataCell(
                  Text('${item['postNumber'] ?? 0}', style: TextStyle(color: shouldBePink ? Colors.pink : Colors.grey)),
                  onTap: () async {
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(post: item)));
                    if (result is Map && result['action'] == 'edit' && mounted) {
                      _startEditing(result['post'] as Map<String, dynamic>);
                    }
                  },
                ),
                DataCell(
                  Text(item['timestamp'] != null
                      ? DateTime.parse(item['timestamp']!)
                          .toLocal()
                          .toString()
                          .substring(5, 16)
                          .replaceAll('-', '/')
                      : ''),
                  onTap: () async {
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(post: item)));
                    if (result is Map && result['action'] == 'edit' && mounted) {
                      _startEditing(result['post'] as Map<String, dynamic>);
                    }
                  },
                ),
                DataCell(Text(item['class']?.toString() ?? ''), onTap: () => _navigateToDetailAndHandleEdit(context, item)),
                DataCell(Text(item['deductionPoints']?.toString() ?? ''), onTap: () => _navigateToDetailAndHandleEdit(context, item)),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(item['deductionReason']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                  ), onTap: () => _navigateToDetailAndHandleEdit(context, item)),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(item['name']?.toString() ?? '不明', overflow: TextOverflow.ellipsis),
                  ), onTap: () => _navigateToDetailAndHandleEdit(context, item)),
              ],
            );
          }),
        ),
      ),
    );
  }

  // 詳細画面へ遷移し、編集リクエストをハンドルする共通メソッド
  Future<void> _navigateToDetailAndHandleEdit(BuildContext context, Map<String, dynamic> post) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
    );
    if (result is Map && result['action'] == 'edit' && mounted) {
      _startEditing(result['post'] as Map<String, dynamic>);
    }
  }

  /// 表示中のデータをA4サイズのPDFプレビューとして表示する
  Future<void> _exportPostsToPdf(List<Map<String, dynamic>> posts, int tabIndex) async {
    final int? activeClass = _gradeClassFilters[tabIndex];
    final bool isClassView = tabIndex > 0 && activeClass != null;
    String title = tabIndex == 0 ? '全校 減点集計表' : '$tabIndex年 減点集計表';
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
                              p['postNumber']?.toString() ?? '',
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
    final double iconSize = size ?? 40;
    // 表示すべき画像パスもキャッシュもない場合は、何も表示しない
    if ((imagePath == null || imagePath.isEmpty) && (cachedBytes == null || cachedBytes.isEmpty)) {
      return SizedBox(width: width ?? size, height: height ?? size);
    }

    final double? w = width ?? size;
    final double? h = height ?? size;
    final int? cacheW = (w != null && w > 0 && w.isFinite && (w * 2.0).toInt() > 0) ? (w * 2.0).toInt() : null;
    final int? cacheH = (h != null && h > 0 && h.isFinite && (h * 2.0).toInt() > 0) ? (h * 2.0).toInt() : null;

    // 1. URL形式の画像がある場合
    if (imagePath != null && imagePath.startsWith('http')) { // URL形式
      return Image.network(
        imagePath,
        width: w, height: h, fit: BoxFit.cover,
        // キャッシュされたバイトデータがあれば、読み込み中にそれを表示する
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: frame != null ? child : (cachedBytes != null && cachedBytes.isNotEmpty
                ? Image.memory(cachedBytes, width: w, height: h, fit: BoxFit.cover, gaplessPlayback: true)
                : Center(child: CupertinoActivityIndicator(radius: iconSize / 4))),
          );
        },
        cacheWidth: cacheW, cacheHeight: cacheH,
        errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: iconSize, color: Colors.grey[300]),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          // 読み込み中もキャッシュがあれば表示
          if (cachedBytes != null && cachedBytes.isNotEmpty) {
            return Image.memory(cachedBytes, width: w, height: h, fit: BoxFit.cover);
          }
          return Center(child: CupertinoActivityIndicator(radius: iconSize / 4));
        },
      );
    }

    // 2. Base64形式の画像、またはキャッシュされたバイトデータがある場合 (古いデータ形式への対応)
    final bytesToUse = cachedBytes ?? (imagePath != null && imagePath.isNotEmpty ? base64Decode(imagePath) : null);
    if (bytesToUse != null && bytesToUse.isNotEmpty) {
      return _buildMemoryImage(bytesToUse, w, h, cacheW, cacheH, iconSize);
    }
    return Icon(Icons.image_not_supported, size: iconSize, color: Colors.grey[300]);
  }

  Widget _buildStatusTag(Map<String, dynamic> item, bool isRecent) {
    final String? status = item['discussionStatus'];
    final bool isHidden = item['isHidden'] == true;

    final bool isOralPossibleExpired = item['_isOralPossibleExpired'] == true;

    if (isOralPossibleExpired) return const SizedBox.shrink();
    
    // 新しいロジック: 投稿後3日以内で、まだ何のステータスも付いていない投稿に「口頭可能」タグを表示
    if (isRecent && status == null && !isHidden) {
      return _tagWidget('口頭可能', Colors.yellow, Colors.black87);
    }
    return const SizedBox.shrink();
  }

  Widget _tagWidget(String text, Color color, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }
}

// _HomeScreenState の外に移動
Widget _buildMemoryImage(Uint8List? imageBytes, double? w, double? h, int? cacheW, int? cacheH, double iconSize) {
  try {
    final bytes = imageBytes;
    if (bytes == null || bytes.isEmpty) {
      return Icon(Icons.broken_image, size: iconSize, color: Colors.grey[300]);
    }

    return Image.memory(
      bytes,
      width: w, height: h, fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      cacheWidth: cacheW,
      cacheHeight: cacheH,
      errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: iconSize, color: Colors.grey[300]),
    );
  } catch (_) {
    return Icon(Icons.broken_image, size: iconSize, color: Colors.grey[300]);
  }
}



 // _HomeScreenState を閉じるカッコ(重要)

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Row(children: [Icon(icon, color: Colors.blueGrey), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]));
  }
}
