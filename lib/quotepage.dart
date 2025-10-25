import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

class EnhancedDailyQuotePage extends StatefulWidget {
  const EnhancedDailyQuotePage({super.key});

  @override
  State<EnhancedDailyQuotePage> createState() => _EnhancedDailyQuotePageState();
}

class _EnhancedDailyQuotePageState extends State<EnhancedDailyQuotePage>
    with TickerProviderStateMixin {
  String _quote = "Loading...";
  String _author = "";
  String _category = "";
  bool _isLoading = false;
  bool _isFavorite = false;
  List<Map<String, String>> _favoriteQuotes = [];
  List<Map<String, String>> _quoteHistory = [];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<Color> _backgroundColors = [
    Colors.blue.shade50,
    Colors.green.shade50,
    Colors.purple.shade50,
    Colors.orange.shade50,
    Colors.teal.shade50,
    Colors.pink.shade50,
  ];

  Color _currentBackgroundColor = Colors.blue.shade50;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _loadQuote();
    _loadFavorites();
    _loadHistory();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadQuote() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (prefs.getString('quote_date') == today) {
      setState(() {
        _quote = prefs.getString('quote_text') ?? "";
        _author = prefs.getString('quote_author') ?? "";
        _category = prefs.getString('quote_category') ?? "";
        _isLoading = false;
      });
      _checkIfFavorite();
      _fadeController.forward();
    } else {
      await _fetchNewQuote();
    }
    _changeBackgroundColor();
  }

  Future<void> _fetchNewQuote() async {
    try {
      final response = await http.get(Uri.parse("https://zenquotes.io/api/today"));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final quoteData = data[0];

        final newQuote = quoteData['q'];
        final newAuthor = quoteData['a'];

        setState(() {
          _quote = newQuote;
          _author = newAuthor;
          _category = "Daily";
          _isLoading = false;
        });

        // Save to preferences
        final prefs = await SharedPreferences.getInstance();
        final today = DateTime.now().toIso8601String().substring(0, 10);
        prefs.setString('quote_date', today);
        prefs.setString('quote_text', _quote);
        prefs.setString('quote_author', _author);
        prefs.setString('quote_category', _category);

        // Add to history
        _addToHistory(_quote, _author, _category);
        _checkIfFavorite();
        _fadeController.forward();
      } else {
        setState(() {
          _quote = "Could not fetch quote. Try again later.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _quote = "Something went wrong. Check your internet connection.";
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchRandomQuote() async {
    setState(() => _isLoading = true);
    _fadeController.reset();

    try {
      final response = await http.get(Uri.parse("https://zenquotes.io/api/random"));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final quoteData = data[0];

        setState(() {
          _quote = quoteData['q'];
          _author = quoteData['a'];
          _category = "Random";
          _isLoading = false;
        });

        _addToHistory(_quote, _author, _category);
        _checkIfFavorite();
        _changeBackgroundColor();
        _fadeController.forward();
      }
    } catch (e) {
      setState(() {
        _quote = "Could not fetch random quote.";
        _isLoading = false;
      });
    }
  }

  void _changeBackgroundColor() {
    setState(() {
      _currentBackgroundColor = _backgroundColors[Random().nextInt(_backgroundColors.length)];
    });
  }

  void _addToHistory(String quote, String author, String category) async {
    final prefs = await SharedPreferences.getInstance();
    _quoteHistory.insert(0, {
      'quote': quote,
      'author': author,
      'category': category,
      'date': DateTime.now().toIso8601String(),
    });

    // Keep only last 50 quotes
    if (_quoteHistory.length > 50) {
      _quoteHistory = _quoteHistory.take(50).toList();
    }

    final historyJson = jsonEncode(_quoteHistory);
    prefs.setString('quote_history', historyJson);
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('quote_history');
    if (historyJson != null) {
      final List<dynamic> historyList = jsonDecode(historyJson);
      _quoteHistory = historyList.map((item) => Map<String, String>.from(item)).toList();
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString('favorite_quotes');
    if (favoritesJson != null) {
      final List<dynamic> favoritesList = jsonDecode(favoritesJson);
      _favoriteQuotes = favoritesList.map((item) => Map<String, String>.from(item)).toList();
    }
  }

  void _checkIfFavorite() {
    _isFavorite = _favoriteQuotes.any((fav) =>
    fav['quote'] == _quote && fav['author'] == _author);
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();

    if (_isFavorite) {
      _favoriteQuotes.removeWhere((fav) =>
      fav['quote'] == _quote && fav['author'] == _author);
      Fluttertoast.showToast(msg: "Removed from favorites");
    } else {
      _favoriteQuotes.add({
        'quote': _quote,
        'author': _author,
        'category': _category,
      });
      Fluttertoast.showToast(msg: "Added to favorites");
    }

    setState(() => _isFavorite = !_isFavorite);

    final favoritesJson = jsonEncode(_favoriteQuotes);
    prefs.setString('favorite_quotes', favoritesJson);
  }

  void _copyQuote() {
    Clipboard.setData(ClipboardData(text: '"$_quote" - $_author'));
    Fluttertoast.showToast(msg: "Quote copied to clipboard!");
  }

  void _shareQuote() {
    Share.share('"$_quote" - $_author', subject: 'Daily Quote');
  }

  void _showFavorites() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Favorite Quotes',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _favoriteQuotes.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No favorite quotes yet', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _favoriteQuotes.length,
                itemBuilder: (context, index) {
                  final quote = _favoriteQuotes[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quote['quote']!,
                            style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '- ${quote['author']}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Quote History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _quoteHistory.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No quote history yet', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _quoteHistory.length,
                itemBuilder: (context, index) {
                  final quote = _quoteHistory[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Chip(
                                label: Text(quote['category']!),
                                backgroundColor: Colors.blue.shade100,
                              ),
                              Text(
                                DateTime.parse(quote['date']!).toString().substring(0, 16),
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            quote['quote']!,
                            style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '- ${quote['author']}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentBackgroundColor,
      appBar: AppBar(
        title: const Text("Daily Quote"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showHistory,
            icon: const Icon(Icons.history),
            tooltip: 'History',
          ),
          IconButton(
            onPressed: _showFavorites,
            icon: const Icon(Icons.favorite),
            tooltip: 'Favorites',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading inspirational quote...'),
          ],
        ),
      )
          : FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.format_quote, size: 50, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        if (_category.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Chip(
                              label: Text(_category),
                              backgroundColor: Colors.blue.shade100,
                            ),
                          ),
                        Text(
                          _quote,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "- $_author",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _copyQuote,
                      icon: const Icon(Icons.copy),
                      label: const Text("Copy"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _shareQuote,
                      icon: const Icon(Icons.share),
                      label: const Text("Share"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _toggleFavorite,
                      icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
                      label: Text(_isFavorite ? "Unfavorite" : "Favorite"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFavorite ? Colors.red.shade100 : null,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _fetchRandomQuote,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Random"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade100,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}