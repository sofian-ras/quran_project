import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/bookmark_service.dart';
import '../theme/app_theme.dart';
import 'screens/quran_loader.dart';

/// Écran de gestion des marque-pages
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<String> _categories = [];
  
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await BookmarkService.instance.getCategories();
    setState(() {
      _categories = categories;
      _tabController = TabController(length: categories.length + 1, vsync: this);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_categories.isEmpty) {
      return Scaffold(
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Mes Marque-pages',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(text: 'Tous'),
            ..._categories.map((category) => Tab(text: category)),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primaryLight,
            ],
          ),
        ),
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAllBookmarks(),
              ..._categories.map((category) => _buildCategoryBookmarks(category)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllBookmarks() {
    return FutureBuilder<List<Bookmark>>(
      future: BookmarkService.instance.getBookmarks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        return _buildBookmarkList(snapshot.data!);
      },
    );
  }

  Widget _buildCategoryBookmarks(String category) {
    return FutureBuilder<List<Bookmark>>(
      future: BookmarkService.instance.getBookmarksByCategory(category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        return _buildBookmarkList(snapshot.data!);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 80,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun marque-page',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ajoutez des marque-pages\nlors de la lecture',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkList(List<Bookmark> bookmarks) {
    // Trier par createdAt décroissant (plus récent en premier)
    bookmarks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        itemCount: bookmarks.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey[200],
        ),
        itemBuilder: (context, index) {
          final bookmark = bookmarks[index];
          return _buildBookmarkTile(bookmark);
        },
      ),
    );
  }

  Widget _buildBookmarkTile(Bookmark bookmark) {
    final dateStr = '${bookmark.createdAt.day.toString().padLeft(2, '0')}/${bookmark.createdAt.month.toString().padLeft(2, '0')}/${bookmark.createdAt.year}';
    
    return Dismissible(
      key: Key('bookmark_${bookmark.page}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer le marque-page'),
            content: Text('Voulez-vous supprimer le marque-page de la page ${bookmark.page} ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await BookmarkService.instance.removeBookmark(bookmark.page);
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Marque-page de la page ${bookmark.page} supprimé'),
              action: SnackBarAction(
                label: 'Annuler',
                onPressed: () async {
                  await BookmarkService.instance.addBookmark(bookmark);
                  setState(() {});
                },
              ),
            ),
          );
        }
      },
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuranLoader(initialPage: bookmark.page),
            ),
          );
        },
        onLongPress: () => _showBookmarkOptions(bookmark),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '${bookmark.page}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                bookmark.surahName ?? 'Page ${bookmark.page}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            _buildCategoryBadge(bookmark.category),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bookmark.note != null && bookmark.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                bookmark.note!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              dateStr,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: const Icon(CupertinoIcons.chevron_right, size: 20),
      ),
    );
  }

  Widget _buildCategoryBadge(String category) {
    final colors = {
      'À réviser': Colors.orange,
      'Important': Colors.red,
      'Favoris': Colors.pink,
      'À mémoriser': Colors.purple,
      'Notes': Colors.blue,
    };
    
    final color = colors[category] ?? Colors.grey;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showBookmarkOptions(Bookmark bookmark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Page ${bookmark.page}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  bookmark.surahName ?? 'Page ${bookmark.page}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(CupertinoIcons.book, color: Colors.blue),
                title: const Text('Ouvrir'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuranLoader(initialPage: bookmark.page),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.pencil, color: Colors.orange),
                title: const Text('Modifier la note'),
                onTap: () {
                  Navigator.pop(context);
                  _editNote(bookmark);
                },
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.tag, color: Colors.purple),
                title: const Text('Changer la catégorie'),
                onTap: () {
                  Navigator.pop(context);
                  _changeCategory(bookmark);
                },
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.delete, color: Colors.red),
                title: const Text('Supprimer'),
                onTap: () async {
                  Navigator.pop(context);
                  await BookmarkService.instance.removeBookmark(bookmark.page);
                  setState(() {});
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _editNote(Bookmark bookmark) {
    final controller = TextEditingController(text: bookmark.note);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier la note'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Votre note...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedBookmark = Bookmark(
                page: bookmark.page,
                surahId: bookmark.surahId,
                surahName: bookmark.surahName ?? 'Page ${bookmark.page}',
                note: controller.text.isEmpty ? null : controller.text,
                category: bookmark.category,
                createdAt: bookmark.createdAt,
              );
              await BookmarkService.instance.updateBookmark(updatedBookmark);
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _changeCategory(Bookmark bookmark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer la catégorie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _categories.map((category) {
            return RadioListTile<String>(
              title: Text(category),
              value: category,
              groupValue: bookmark.category,
              onChanged: (value) async {
                if (value != null) {
                  final updatedBookmark = Bookmark(
                    page: bookmark.page,
                    surahId: bookmark.surahId,
                    surahName: bookmark.surahName ?? 'Page ${bookmark.page}',
                    note: bookmark.note,
                    category: value,
                    createdAt: bookmark.createdAt,
                  );
                  await BookmarkService.instance.updateBookmark(updatedBookmark);
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
                  }
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
