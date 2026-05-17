import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // kIsWeb を使うため
import 'post_detail_screen.dart'; // Import the new detail screen

/// 重いJSONデコードを別スレッドで行うためのトップレベル関数
List<Map<String, dynamic>> _parsePostsJson(String jsonString) {
  final List<dynamic> decodedList = jsonDecode(jsonString);
  return decodedList.map((item) => Map<String, dynamic>.from(item)).toList();
}

/// 重いJSONエンコードを別スレッドで行うためのトップレベル関数
String _encodePostsJson(List<Map<String, dynamic>> posts) {
  return jsonEncode(posts);
}

class HomeScreen extends StatefulWidget {
  final String username;

  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _remarksController = TextEditingController();
  final List<Map<String, dynamic>> _posts =
      []; // Changed type to dynamic for timestamp
  int _selectedValue1 = 1;
  String _selectedValue2 = '1';
  String? _base64Image; // Web対応のためBase64形式で保持
  final ImagePicker _picker = ImagePicker();
  late TabController _tabController;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _classController;
  late FixedExtentScrollController _deductionPointsPicker;
  late FixedExtentScrollController _deductionReasonPicker;
  late FixedExtentScrollController _searchYearPicker;
  late FixedExtentScrollController _searchClassPicker;

  // New state variables for deduction points and reason
  int _selectedDeductionPoints = 1; // Default to 1
  String _selectedDeductionReason = 'ペンキ'; // Default to the first option
  final List<String> _deductionReasons = [
    'ペンキ',
    '時間',
    '工具',
    '会計',
    'ステージ',
    'その他',
  ];

  bool _sortNewestFirst = true; // Added state for sorting order
  // Search filter state
  int _searchFilterYear = 1; // Default selected year for search
  String _searchFilterClass = '1'; // Default selected class for search
  bool _isSearchFilterActive = false; // Flag to indicate if a search filter is applied
  bool _isTableView = false; // 集計表表示かどうかの状態
  bool _isLargeImageMode = false; // 画像を大きく表示するかどうかの状態
  bool _showHiddenOnly = false; // 非表示（アーカイブ）された投稿のみを表示するかどうか
  bool _isPostFormExpanded = true; // 減点登録フォームが開いているかどうか
  final Map<int, int> _gradeClassFilters = {}; // 学年ごとのクラスフィルター状態 (tabIndex: classNum)

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadPosts();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _tabController.dispose();
    _yearController.dispose();
    _classController.dispose();
    _deductionPointsPicker.dispose();
    _deductionReasonPicker.dispose();
    _searchYearPicker.dispose();
    _searchClassPicker.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    _tabController = TabController(
      length: 4,
      vsync: this,
    ); // 全体, 1年, 2年, 3年の4つに変更
    _yearController = FixedExtentScrollController(
      initialItem: _selectedValue1 - 1,
    );
    _classController = FixedExtentScrollController(
      initialItem: int.parse(_selectedValue2) - 1,
    );
    _deductionPointsPicker = FixedExtentScrollController(
      initialItem: _selectedDeductionPoints - 1,
    );
    _deductionReasonPicker = FixedExtentScrollController(
      initialItem: _deductionReasons.indexOf(_selectedDeductionReason),
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
      maxWidth: 800, // 軽量化：画像を最大800pxにリサイズ
      maxHeight: 800,
      imageQuality: 70, // 軽量化：画質を少し落として容量削減
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes(); // 画像をバイトデータとして読み込む
      setState(() {
        _base64Image = base64Encode(bytes); // Base64文字列に変換
      });
    }
  }

  Future<void> _loadPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? postsString = prefs.getString('posts_data');
    try {
      if (postsString != null && postsString.isNotEmpty) {
        // 大量データのデコードを別スレッド(compute)で行い、UIのフリーズを防ぐ
        final List<Map<String, dynamic>> loadedPosts = await compute(_parsePostsJson, postsString);
        setState(() {
          _posts.clear(); // 重複読み込み防止
          _posts.addAll(loadedPosts);
        });
      }
    } catch (e, stack) {
      debugPrint('データの読み込みに失敗しました: $e\n$stack');
    }
  }

  Future<void> _savePosts() async {
    final prefs = await SharedPreferences.getInstance();
    // エンコードも別スレッドで行う
    final String encodedData = await compute(_encodePostsJson, _posts);
    await prefs.setString('posts_data', encodedData);
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
              onPressed: () {
                setState(() {
                  _posts.remove(item);
                  _savePosts();
                });
                Navigator.pop(context);
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
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('復元の確認'),
            content: const Text('この減点取り消しを無効にして、減点を復元しますか？'),
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

      if (confirm != true) return;

      setState(() {
        item['isHidden'] = false;
        item.remove('hiddenReasonImage'); // ストレージ節約のため写真を削除
        _savePosts();
      });
      return;
    }

    // 非表示にする際の画像選択ダイアログ
    String? tempBase64;
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
                  if (tempBase64 != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Image.memory(base64Decode(tempBase64!), height: 150, fit: BoxFit.cover),
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
                        setDialogState(() => tempBase64 = base64Encode(bytes));
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
                  onPressed: () {
                    setState(() {
                      item['isHidden'] = true;
                      item['hiddenReasonImage'] = tempBase64;
                      _savePosts();
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

  void _submitPost() {
    // 備考に入力がある、画像が選択されている、または減点数が設定されている場合に投稿を許可
    if (_remarksController.text.isNotEmpty ||
        _base64Image != null ||
        _selectedDeductionPoints > 0) {
      setState(() {
        _posts.insert(0, {
          'class': '$_selectedValue1年$_selectedValue2組',
          'deductionPoints': _selectedDeductionPoints.toString(),
          'deductionReason': _selectedDeductionReason,
          'remarks': _remarksController.text,
          'imagePath': _base64Image ?? '', // Base64文字列を保存
          'timestamp': DateTime.now().toIso8601String(), // Add timestamp
          'name': widget.username, // ログインユーザー名を保存
          'isHidden': false, // 初期状態は表示
        });
        _savePosts(); // Save posts after adding a new one
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '投稿しました: $_selectedDeductionPoints点, 理由: $_selectedDeductionReason',
          ),
        ),
      );

      // フォームをリセット
      _selectedValue1 = 1;
      _selectedValue2 = '1';
      _yearController.jumpToItem(0);
      _classController.jumpToItem(0);
      _selectedDeductionPoints = 1;
      _selectedDeductionReason = 'ペンキ';
      _deductionPointsPicker.jumpToItem(0);
      _deductionReasonPicker.jumpToItem(0);
      _remarksController.clear();
      _base64Image = null;
    }
  }

  @override
  Widget build(BuildContext context) {
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
              pinned: true,   // タブバーを上部に固定する
              snap: true,     // スクロールを止めると自動的に開き切る
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
                controller: _tabController,
                onTap: (index) {
                  // すでに選択されているタブをもう一度押した時にフィルターをリセット
                  if (index == _tabController.index) {
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
          controller: _tabController,
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
      
      // 基本条件（取り消し済みかどうか）
      if ((post['isHidden'] ?? false) != _showHiddenOnly) continue;

      // タブごとの条件
      final String postClass = (post['class']?.toString() ?? '').trim();
      if (cleanSearchTarget != null && postClass != cleanSearchTarget) continue;
      if (cleanTargetYear != null && !postClass.startsWith(cleanTargetYear)) continue;

      final int postNo = _posts.length - i;

      // 集計
      final points = int.tryParse(post['deductionPoints']?.toString() ?? '0') ?? 0;
      totalDeductionPoints += points;
      if (tabIndex > 0) {
        final String? classStr = post['class'] as String?;
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

      // リスト表示用の絞り込み（集計には含めるがリストからは外す場合）
      if (tabClassFilter != null && postClass != tabClassFilter) continue;

      // 表示用データを作成（高速化のため参照を渡し、UI用の番号を直接付与）
      post['_uiNumber'] = postNo;
      displayedPosts.add(post);
    }

    // 並び替え (null安全な比較に修正)
    displayedPosts.sort((a, b) {
      final String timeA = a['timestamp']?.toString() ?? '';
      final String timeB = b['timestamp']?.toString() ?? '';
      if (_sortNewestFirst) return timeB.compareTo(timeA);
      return timeA.compareTo(timeB);
    });

    // CustomScrollView を使用することで、大量のリストアイテムを効率的に描画（Recycling）できるようにします
    return CustomScrollView(
      key: PageStorageKey<String>('tab_$tabIndex'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (isPostForm && !_showHiddenOnly) ...[
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
                              onSelectedItemChanged: (int index) => setState(() => _selectedValue1 = index + 1),
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
                          Icon(Icons.warning_amber_rounded, size: 20, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('減点詳細', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('減点数:', style: TextStyle(color: Colors.grey)),
                          const SizedBox(width: 8),
                          _buildPickerContainer(
                            width: 80,
                            picker: CupertinoPicker(
                              scrollController: _deductionPointsPicker,
                              itemExtent: 32.0,
                              onSelectedItemChanged: (int index) => setState(() => _selectedDeductionPoints = index + 1),
                              children: List<Widget>.generate(60, (int index) => Center(child: Text('${index + 1}'))),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text('理由:', style: TextStyle(color: Colors.grey)),
                          const SizedBox(width: 8),
                          _buildPickerContainer(
                            width: 120,
                            picker: CupertinoPicker(
                              scrollController: _deductionReasonPicker,
                              itemExtent: 32.0,
                              onSelectedItemChanged: (int index) => setState(() => _selectedDeductionReason = _deductionReasons[index]),
                              children: List<Widget>.generate(
                                _deductionReasons.length,
                                (int index) => Center(child: Text(_deductionReasons[index])),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _remarksController,
                        decoration: InputDecoration(
                          labelText: '備考',
                          hintText: '具体的な状況など（任意）',
                          prefixIcon: const Icon(Icons.notes),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        maxLines: 3,
                        minLines: 1,
                      ),
                      const SizedBox(height: 16),
                      if (_base64Image != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(_base64Image!),
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text('写真添付'),
                          ),
                          IconButton(
                            onPressed: _submitPost,
                            icon: const Icon(Icons.send),
                            color: const Color.fromARGB(255, 101, 167, 221),
                            iconSize: 32,
                            tooltip: '投稿する',
                          ),
                        ],
                      ),
                    ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (tabIndex == 0) ...[
                _buildSearchFilterSection(totalDeductionPoints),
              ],
              if (tabIndex > 0) ...[
                _buildGradeSummarySection(tabIndex, classTotals),
              ],
              if (!_isTableView) ...[
                const _SectionHeader(icon: Icons.history_edu, title: '投稿履歴'),
              ],
            ]),
          ),
        ),
        // リスト部分。SliverListを使うことで画面外のアイテムは描画されず、メモリが節約されます。
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
                    // 合計点数表示エリア：Expandedを使って、ピッカーの位置が左右に動かないように固定
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
                      absorbing: _isSearchFilterActive, // 検索中は操作を無効化（固定）
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
                            // クリア時にピッカーをリセットせず、現在の位置を保持（勝手に動かさない）
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

  // 投稿内容（減点数、理由、備考）のUIパーツ
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
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              '備考: ${item['remarks']}',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  // ピッカーを包む共通のデザインコンテナ
  Widget _buildPickerContainer({required double width, required Widget picker}) {
    return Container(
      height: 60,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: picker,
    );
  }

  // 投稿をまとめた集計表を表示するウィジェット
  Widget _buildSummaryTable(List<Map<String, dynamic>> displayedPosts) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        key: ValueKey('table_${displayedPosts.length}'), // 変更を検知させる
        columnSpacing: 16.0,
        dataRowMinHeight: 40.0,
        dataRowMaxHeight: 60.0,
        columns: const [
          DataColumn(
            label: Text('No.', style: TextStyle(fontWeight: FontWeight.bold)),
            numeric: true,
          ),
          DataColumn(
            label: Text('クラス', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text('減点数', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text('理由', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text('備考', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text('名前', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
        rows: List<DataRow>.generate(displayedPosts.length, (index) {
          final item = displayedPosts[index];
          // リストの通し番号と一致させる
          final int postNumber = item['_uiNumber'] ?? 0;
          final String classInfo = item['class']?.toString() ?? '';
          final String deductionPoints = item['deductionPoints']?.toString() ?? '';
          final String deductionReason = item['deductionReason']?.toString() ?? '';
          final String remarks = item['remarks']?.toString() ?? '';
          final String name = item['name']?.toString() ?? '不明'; // 名前が保存されていない場合は「不明」

          return DataRow(
            cells: [
              // Make the first DataCell tappable for navigation
              DataCell(
                Text('$postNumber'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailScreen(post: item),
                    ),
                  );
                },
              ),
              DataCell(Text(classInfo)),
              DataCell(Text(deductionPoints)),
              DataCell(Text(deductionReason)),
              DataCell(
                SizedBox(
                  width: 100, // 備考が長文になる可能性があるので幅を制限
                  child: Text(
                    remarks,
                    maxLines: 2, // 2行まで表示
                    overflow: TextOverflow.ellipsis, // 2行を超えたら省略
                  ),
                ),
              ),
              DataCell(Text(name)),
            ],
          );
        }),
      ),
    );
  }

  // 画像パスが Base64 か ファイルパス かを判定して表示するウィジェット
  Widget _buildImageWidget(String? imagePath, {double? size, double? width, double? height}) {
    if (imagePath == null || imagePath.isEmpty) {
      return const SizedBox.shrink();
    }

    final double? targetWidth = width ?? size ?? 100;
    final double? targetHeight = height ?? size ?? 100;

    return RepaintBoundary(
      child: _buildRawImage(imagePath, targetWidth, targetHeight, size),
    );
  }

  Widget _buildRawImage(String imagePath, double? targetWidth, double? targetHeight, double? size) {
    const filterQuality = FilterQuality.low; // 軽量化のため画質設定を調整

    if (kIsWeb) {
      try {
        return Image.memory(
          base64Decode(imagePath),
          width: targetWidth,
          height: targetHeight,
          fit: BoxFit.cover,
          filterQuality: filterQuality,
          gaplessPlayback: true,
          cacheWidth: (targetWidth != null && targetWidth.isFinite) ? (targetWidth * 2).toInt() : null,
          cacheHeight: (targetHeight != null && targetHeight.isFinite) ? (targetHeight * 2).toInt() : null,
          errorBuilder: (c, e, s) => Icon(Icons.broken_image, size: size ?? 40),
        );
      } catch (_) {
        return Icon(Icons.broken_image, size: size);
      }
    }

    try {
      return Image.memory(
        base64Decode(imagePath),
        width: targetWidth,
        height: targetHeight,
        fit: BoxFit.cover,
        filterQuality: filterQuality,
        gaplessPlayback: true,
        cacheWidth: (targetWidth != null && targetWidth.isFinite) ? (targetWidth * 2).toInt() : null,
        cacheHeight: (targetHeight != null && targetHeight.isFinite) ? (targetHeight * 2).toInt() : null,
        errorBuilder: (c, e, s) => _buildFileImage(imagePath, targetWidth, targetHeight, size),
      );
    } catch (_) {
      return _buildFileImage(imagePath, targetWidth, targetHeight, size);
    }
  }

  Widget _buildFileImage(String path, double? w, double? h, double? s) {
    return Image.file(
      File(path),
      width: w,
      height: h,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      cacheWidth: (w != null && w.isFinite) ? (w * 2).toInt() : null,
      cacheHeight: (h != null && h.isFinite) ? (h * 2).toInt() : null,
      errorBuilder: (c, e, s_stack) => Icon(Icons.broken_image, size: s ?? 40),
    );
  }
}

/// 共通のヘッダーウィジェットを分離して再利用（軽量化のため）
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
