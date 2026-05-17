import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // kIsWeb を使うため
import 'post_detail_screen.dart'; // Import the new detail screen

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
      if (postsString != null) {
        setState(() {
          final List<dynamic> decodedList = jsonDecode(postsString);
          _posts.clear(); // 重複読み込み防止
          _posts.addAll(
            decodedList.map((item) => Map<String, dynamic>.from(item)).toList(),
          );
        });
      }
    } catch (e) {
      debugPrint('データの読み込みに失敗しました: $e');
    }
  }

  Future<void> _savePosts() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(_posts);
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
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              title: const Text('ホーム'),
              backgroundColor: const Color.fromARGB(255, 208, 249, 255),
              floating: true, // 上にスクロールした時にすぐ表示される
              pinned: true,   // タブバーを上部に固定する
              snap: true,     // スクロールを止めると自動的に開き切る
              forceElevated: innerBoxIsScrolled,
              actions: [
                IconButton(
                  icon: Icon(_isTableView ? Icons.list : Icons.table_chart),
                  onPressed: () {
                    setState(() {
                      _isTableView = !_isTableView;
                    });
                  },
                  tooltip: _isTableView ? 'リスト表示' : '集計表表示',
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

  Widget _buildTabContent({required bool isPostForm, required int tabIndex}) {
    // 表示する投稿のリストを事前に準備(ソート・フィルタリング)
    List<Map<String, dynamic>> displayedPosts = [];
    if (tabIndex == 0) {
      displayedPosts = List<Map<String, dynamic>>.from(_posts);
      // 検索フィルターが有効な場合、選択されたクラスでフィルタリング
      if (_isSearchFilterActive) {
        final String searchTarget = '${_searchFilterYear}年${_searchFilterClass}組';
        displayedPosts = displayedPosts.where((post) => post['class'] == searchTarget).toList();
      }
    } else {
      final String targetYear = '${tabIndex}年';
      displayedPosts = _posts.where((post) => (post['class'] as String?)?.startsWith(targetYear) ?? false).toList();
    }

    // 減点合計およびクラスごとの集計を計算
    int totalDeductionPoints = 0;
    final Map<int, int> classTotals = {};
    if (tabIndex > 0) {
      for (int i = 1; i <= 9; i++) classTotals[i] = 0;
    }

    for (var post in displayedPosts) {
      final points = int.tryParse(post['deductionPoints']?.toString() ?? '0') ?? 0;
      totalDeductionPoints += points;

      if (tabIndex > 0) {
        final String? classStr = post['class'] as String?;
        if (classStr != null) {
          final match = RegExp(r'(\d+)組').firstMatch(classStr);
          if (match != null) {
            final classNum = int.tryParse(match.group(1)!);
            if (classNum != null && classTotals.containsKey(classNum)) {
              classTotals[classNum] = classTotals[classNum]! + points;
            }
          }
        }
      }
    }

    if (_sortNewestFirst) {
      displayedPosts.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    } else {
      displayedPosts.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
    }

    return SingleChildScrollView(
      // 画面全体をスクロール可能にする
      physics: const AlwaysScrollableScrollPhysics(), // スクロールの連動を安定させる
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (isPostForm) ...[
            Card(
              color: const Color.fromARGB(255, 249, 254, 255),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_note, color: Colors.blueGrey),
                        SizedBox(width: 8),
                        Text(
                          '減点登録',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    // 対象クラス選択
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
                    // 減点詳細
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
                    // 備考入力
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
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          // 検索フィルターUI (全体タブのみ)
          if (tabIndex == 0) ...[
            Card(
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
            ),
          ],
          // 学年別タブ：クラスごとの合計を表示するサマリー
          if (tabIndex > 0) ...[
            SizedBox(
              height: 65,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 9,
                itemBuilder: (context, index) {
                  final classNum = index + 1;
                  final total = classTotals[classNum] ?? 0;
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.blueGrey.withOpacity(0.1)),
                    ),
                    color: total > 0 ? Colors.red[50] : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$classNum組',
                              style: TextStyle(fontSize: 11, color: Colors.blueGrey[700])),
                          Text(
                            '$total点',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: total > 0 ? Colors.red[700] : Colors.blueGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!_isTableView)
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Icon(Icons.history, color: Colors.blueGrey),
                  SizedBox(width: 8),
                  Text('投稿履歴', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ), // ここは独立した if なのでカンマがあっても良いが、次の if との間にあることを確認

          // 一覧またはテーブルの表示
          if (_isTableView)
            _buildSummaryTable(displayedPosts) // ←ここにカンマがあると else がエラーになります
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayedPosts.length,
              itemBuilder: (context, index) {
                final item = displayedPosts[index];
                return Card(
                  color: Colors.white, // 履歴カードは白に設定（お好みで変更可能）
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_posts.length - _posts.indexOf(item)}',
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
                      child: Column(
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => _deletePost(item),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PostDetailScreen(post: item)),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
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
        columnSpacing: 16.0,
        dataRowMinHeight: 40.0,
        dataRowMaxHeight: 60.0,
        columns: const [
          DataColumn(
            label: Text('No.', style: TextStyle(fontWeight: FontWeight.bold)),
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
          final int postNumber = _posts.length - _posts.indexOf(item);
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
  Widget _buildImageWidget(String? imagePath, {double size = 100}) {
    if (imagePath == null || imagePath.isEmpty) {
      return const SizedBox.shrink();
    }

    // Web版ではファイルアクセスができないため、Base64としての表示のみ試みる
    if (kIsWeb) {
      try {
        return Image.memory(
          base64Decode(imagePath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Icon(Icons.broken_image, size: size),
        );
      } catch (_) {
        return Icon(Icons.broken_image, size: size);
      }
    }

    // アプリ版(iOS/Android)の場合は両方に対応
    try {
      // まずはBase64としてデコードを試みる
      final bytes = base64Decode(imagePath);
      return Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Icon(Icons.broken_image, size: size),
      );
    } catch (_) {
      // Base64でなければ、従来のファイルパスとして扱う
      return Image.file(
        File(imagePath),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Icon(Icons.broken_image, size: size),
      );
    }
  }
}
