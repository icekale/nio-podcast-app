import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'catalog.dart';
import 'covers.dart';
import 'format.dart';
import 'player.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

enum AppScreen { home, albums, search, album, favorites }

class RadioApp extends StatefulWidget {
  const RadioApp({super.key, required this.api, required this.player});

  final NioApi api;
  final RadioPlayer player;

  @override
  State<RadioApp> createState() => _RadioAppState();
}

class _RadioAppState extends State<RadioApp> with TickerProviderStateMixin {
  AppScreen _screen = AppScreen.home;
  AppScreen? _albumReturn;
  Album? _album;
  String _searchQuery = '';
  Catalog? _catalog;
  HomeSelection? _home;
  Object? _error;
  var _loading = true;
  var _refreshing = false;
  var _stale = false;
  final _favoriteIds = <int>[];
  final _later = <Episode>[];
  SharedPreferences? _prefs;
  int? _savedEpisodeId;
  var _savedQueueLength = -1;
  var _savedHistoryLength = -1;
  var _savedPositionBucket = -1;
  String _queueTab = 'queue';
  Timer? _sleep;
  String? _sleepLabel;
  AppLifecycleListener? _lifecycle;
  late final AnimationController _pageSlide;
  late final Animation<Offset> _pageOffset;
  late final AnimationController _coverSlide;
  late final Animation<Offset> _coverOffset;
  final _navTick = ValueNotifier(0);
  final _coverTick = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _pageSlide = _newSlide();
    _pageOffset = _slideOffset(_pageSlide);
    _coverSlide = _newSlide();
    _coverOffset = _slideOffset(_coverSlide);
    _pageSlide.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _navTick.value++;
      }
    });
    _lifecycle = AppLifecycleListener(onPause: _persistPlayback);
    widget.player.addListener(_persistPlayback);
    _load();
    unawaited(_restore());
  }

  @override
  void dispose() {
    _pageSlide.dispose();
    _coverSlide.dispose();
    _navTick.dispose();
    _coverTick.dispose();
    _sleep?.cancel();
    widget.player.removeListener(_persistPlayback);
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _prefs = prefs;
    final playback = loadPlayback(prefs);
    setState(() {
      _favoriteIds.addAll(loadFavorites(prefs));
      _later.addAll(loadLater(prefs));
    });
    widget.player.restore(
      queue: playback?.queue ?? const [],
      index: playback?.index ?? -1,
      history: loadHistory(prefs),
      position: playback?.position ?? Duration.zero,
      duration: playback?.duration ?? Duration.zero,
    );
  }

  void _persistPlayback() {
    final prefs = _prefs;
    if (prefs == null) return;
    final player = widget.player;
    final episodeId = player.current?.id;
    final queueLength = player.queue.length;
    final positionBucket = player.position.inSeconds ~/ 5;
    if (player.history.length != _savedHistoryLength) {
      _savedHistoryLength = player.history.length;
      unawaited(saveHistory(prefs, player.history));
    }
    if (episodeId == _savedEpisodeId && queueLength == _savedQueueLength && positionBucket == _savedPositionBucket) {
      return;
    }
    _savedEpisodeId = episodeId;
    _savedQueueLength = queueLength;
    _savedPositionBucket = positionBucket;
    unawaited(savePlayback(
      prefs,
      queue: player.queue,
      index: player.index,
      positionMs: player.position.inMilliseconds,
      durationMs: player.duration.inMilliseconds,
    ));
  }

  Future<void> _load() async {
    setState(() {
      if (_catalog == null) {
        _loading = true;
      } else {
        _refreshing = true;
      }
      _error = null;
    });
    try {
      final catalog = await widget.api.fetchCatalog();
      var daytime = const <Episode>[];
      try {
        daytime = await widget.api.fetchDaytimeEpisodes();
      } catch (_) {}
      if (!mounted) return;
      final fallback = selectHomeEpisodes(catalog.albums);
      setState(() {
        _catalog = catalog;
        _home = mergeDaytime(fallback, daytime);
        _loading = false;
        _refreshing = false;
        _stale = false;
      });
      final sections = groupAlbumsByCategory(catalog.albums, _favoriteIds);
      unawaited(CoverStore.prefetch([
        for (final group in sections.groups) ...group.albums,
        ...sections.rest,
      ]));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
        _refreshing = false;
        _stale = _catalog != null;
      });
    }
  }

  AnimationController _newSlide() => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 260),
      );

  Animation<Offset> _slideOffset(AnimationController controller) =>
      Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic),
      );

  void _go(AppScreen screen, {Album? album, String? query}) {
    if (screen == AppScreen.album) {
      if (_screen != AppScreen.album) _albumReturn = _screen;
      _screen = AppScreen.album;
      if (album != null) _album = album;
      _coverTick.value++;
      if (_pageSlide.isDismissed) _pageSlide.forward();
      _coverSlide.forward();
      return;
    }
    final fromHome = _screen == AppScreen.home || _pageSlide.isDismissed;
    _screen = screen;
    if (query != null) _searchQuery = query;
    _navTick.value++;
    if (fromHome) _pageSlide.forward();
  }

  void _back() {
    if (_screen == AppScreen.album) {
      _coverSlide.reverse().whenComplete(() {
        if (!mounted || _coverSlide.isAnimating) return;
        _screen = _albumReturn ?? AppScreen.albums;
        _album = null;
        _coverTick.value++;
      });
      return;
    }
    if (_screen == AppScreen.home) return;
    _pageSlide.reverse().whenComplete(() {
      if (!mounted || _pageSlide.isAnimating) return;
      _screen = AppScreen.home;
      _navTick.value++;
    });
  }

  Future<void> _play(Episode episode, [List<Episode>? queue]) {
    return widget.player.playEpisode(episode, queue);
  }

  void _toggleFavorite(int albumId) {
    setState(() {
      if (_favoriteIds.contains(albumId)) {
        _favoriteIds.remove(albumId);
      } else {
        _favoriteIds.insert(0, albumId);
      }
    });
    final prefs = _prefs;
    if (prefs != null) unawaited(saveFavorites(prefs, _favoriteIds));
  }

  LaterAddResult _addLater(Episode episode) {
    if (_later.any((item) => item.id == episode.id)) {
      return LaterAddResult(added: false, items: _later);
    }
    if (_later.length >= 50) {
      return LaterAddResult(added: false, reason: 'limit', items: _later);
    }
    setState(() => _later.add(episode));
    final prefs = _prefs;
    if (prefs != null) unawaited(saveLater(prefs, _later));
    return LaterAddResult(added: true, items: _later);
  }

  void _removeLater(int episodeId) {
    final before = _later.length;
    _later.removeWhere((item) => item.id == episodeId);
    if (_later.length == before) return;
    final prefs = _prefs;
    if (prefs != null) unawaited(saveLater(prefs, _later));
  }

  void _setSleep(int? minutes, {bool episodeEnd = false}) {
    _sleep?.cancel();
    widget.player.stopAfterEpisode = episodeEnd;
    if (episodeEnd) {
      setState(() => _sleepLabel = '本集结束');
      return;
    }
    if (minutes == null) {
      setState(() => _sleepLabel = null);
      return;
    }
    setState(() => _sleepLabel = '$minutes 分钟');
    _sleep = Timer(Duration(minutes: minutes), () {
      if (widget.player.playing) widget.player.toggle();
      if (mounted) setState(() => _sleepLabel = null);
    });
  }

  Future<void> _openQueue() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ListenableBuilder(
          listenable: widget.player,
          builder: (context, _) {
            return QueueSheet(
              player: widget.player,
              later: _later,
              tab: _queueTab,
              sleepLabel: _sleepLabel,
              onTab: (tab) => setState(() => _queueTab = tab),
              onPlay: (episode) => _play(episode, widget.player.queue),
              onPlayLater: (episode) => _play(episode, _later),
              onRemove: widget.player.removeFromQueue,
              onPlayNext: widget.player.playNext,
              onRemoveLater: _removeLater,
              onSleepMinutes: (minutes) => _setSleep(minutes),
              onSleepEpisodeEnd: () => _setSleep(null, episodeEnd: true),
              onClearSleep: () => _setSleep(null),
              onClose: () => Navigator.pop(context),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = NioPalette(Theme.of(context).brightness);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_screen == AppScreen.home) {
          SystemNavigator.pop();
          return;
        }
        _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).appBarTheme.systemOverlayStyle ?? SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: palette.surface,
        body: Stack(
          children: [
            Positioned.fill(child: _body()),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12 + MediaQuery.paddingOf(context).bottom,
              child: ListenableBuilder(
                listenable: widget.player,
                builder: (context, _) {
                  final show = !_loading && widget.player.current != null;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: show
                        ? MiniPlayerBar(
                            key: const ValueKey('mini'),
                            player: widget.player,
                            onToggle: widget.player.toggle,
                            onSeek: widget.player.seek,
                            onOpenQueue: _openQueue,
                          )
                        : const SizedBox.shrink(key: ValueKey('mini-off')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _splash(BuildContext context) {
    final palette = NioPalette(Theme.of(context).brightness);
    return ColoredBox(
      color: palette.dark ? const Color(0xFF101A27) : Colors.white,
      child: Center(
        child: Image.asset(
          'assets/logo.png',
          width: 168,
          height: 168,
          color: palette.dark ? Colors.white : Colors.black,
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return _splash(context);
    }
    if (_catalog == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('刷新目录')),
          ],
        ),
      );
    }
    final catalog = _catalog!;
    final palette = NioPalette(Theme.of(context).brightness);
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: SizedBox.expand(
          child: HomeScreen(
            home: _home!,
            player: widget.player,
            stale: _stale,
            refreshing: _refreshing,
            error: _error,
            onRetry: _load,
            onPlay: (episode) => _play(episode, _home!.episodes),
            onPlayAll: () {
              if (_home!.episodes.isEmpty) return;
              final rec = _home!.episodes.first;
              if (widget.player.current?.id == rec.id) {
                widget.player.toggle();
              } else {
                _play(rec, _home!.episodes);
              }
            },
            onResume: () {
              if (!widget.player.playing) widget.player.toggle();
            },
            onSearch: () => _go(AppScreen.search),
            onOpenAlbums: () => _go(AppScreen.albums),
          ),
          ),
        ),
        RepaintBoundary(
          child: ClipRect(
            child: SlideTransition(
              position: _pageOffset,
              child: ValueListenableBuilder<int>(
                valueListenable: _navTick,
                builder: (context, _, _) {
                  return IgnorePointer(
                    ignoring: _screen == AppScreen.home,
                    child: ColoredBox(
                      color: palette.surface,
                      child: _screen == AppScreen.home
                          ? const SizedBox.expand()
                          : _listPage(catalog),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        RepaintBoundary(
          child: ClipRect(
            child: SlideTransition(
              position: _coverOffset,
              child: ValueListenableBuilder<int>(
                valueListenable: _coverTick,
                builder: (context, _, _) {
                  return IgnorePointer(
                    ignoring: _album == null,
                    child: ColoredBox(
                      color: palette.surface,
                      child: _album == null ? const SizedBox.expand() : _albumPage(),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  AppScreen get _listScreen {
    if (_screen == AppScreen.album) return _albumReturn ?? AppScreen.albums;
    return _screen;
  }

  Widget _listPage(Catalog catalog) {
    final showGrid = _pageSlide.status != AnimationStatus.forward;
    if (_listScreen == AppScreen.search) {
      return SearchView(
        catalog: catalog,
        query: _searchQuery,
        favoriteIds: _favoriteIds,
        showGrid: showGrid,
        onBack: _back,
        onQuery: (value) => setState(() => _searchQuery = value),
        onOpenAlbum: (album) => _go(AppScreen.album, album: album),
        onToggleFavorite: _toggleFavorite,
      );
    }
    if (_listScreen == AppScreen.favorites) {
      return FavoritesView(
        catalog: catalog,
        favoriteIds: _favoriteIds,
        onBack: _back,
        onBrowse: () => _go(AppScreen.albums),
        onOpenAlbum: (album) => _go(AppScreen.album, album: album),
        onToggleFavorite: _toggleFavorite,
      );
    }
    return AlbumsScreen(
      catalog: catalog,
      favoriteIds: _favoriteIds,
      showGrid: showGrid,
      onBack: _back,
      onSearch: () => _go(AppScreen.search),
      onOpenAlbum: (album) => _go(AppScreen.album, album: album),
      onToggleFavorite: _toggleFavorite,
    );
  }

  Widget _albumPage() {
    return AlbumView(
      api: widget.api,
      album: _album!,
      favorited: _favoriteIds.contains(_album!.id),
      onBack: _back,
      onPlay: (episode, queue) => _play(episode, queue),
      onAddLater: _addLater,
      onToggleFavorite: () => _toggleFavorite(_album!.id),
    );
  }
}

class LaterAddResult {
  LaterAddResult({required this.added, this.reason, required this.items});
  final bool added;
  final String? reason;
  final List<Episode> items;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.home,
    required this.player,
    required this.stale,
    required this.refreshing,
    required this.error,
    required this.onRetry,
    required this.onPlay,
    required this.onPlayAll,
    required this.onResume,
    required this.onSearch,
    required this.onOpenAlbums,
  });

  final HomeSelection home;
  final RadioPlayer player;
  final bool stale;
  final bool refreshing;
  final Object? error;
  final Future<void> Function() onRetry;
  final ValueChanged<Episode> onPlay;
  final VoidCallback onPlayAll;
  final VoidCallback onResume;
  final VoidCallback onSearch;
  final VoidCallback onOpenAlbums;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _recKey = GlobalKey();
  var _scrolled = false;
  var _visible = 20;

  bool _onScroll(ScrollNotification notification) {
    final box = _recKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final bottom = box.localToGlobal(Offset.zero).dy + box.size.height;
      final headerBottom = 56 + MediaQuery.paddingOf(context).top;
      final next = notification.metrics.pixels > 0 && bottom <= headerBottom;
      if (next != _scrolled) setState(() => _scrolled = next);
    }
    if (notification.metrics.extentAfter < 240 && _visible < widget.home.episodes.length) {
      setState(() => _visible = (_visible + 20).clamp(0, widget.home.episodes.length));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.player,
      builder: (context, _) {
    final palette = NioPalette(Theme.of(context).brightness);
    final rec = widget.home.episodes.isEmpty ? null : widget.home.episodes.first;
    final playingRec = rec != null && widget.player.current?.id == rec.id;
    final episodes = widget.home.episodes.take(_visible).toList();
    String playLabel = '全部播放';
    var playIcon = Icons.play_arrow;
    if (playingRec) {
      playLabel = widget.player.playing ? '暂停' : '继续播放';
      playIcon = widget.player.playing ? Icons.pause : Icons.play_arrow;
    }

    return RefreshIndicator(
      color: palette.teal,
      onRefresh: widget.onRetry,
      child: NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: TopBar(
              background: _scrolled ? palette.surface : palette.aqua,
              scrolled: _scrolled,
              leading: IconCircleButton(icon: Icons.menu, tooltip: '全部专辑', onPressed: widget.onOpenAlbums),
              title: Text('NIO Radio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: palette.ink)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_scrolled && widget.player.current != null)
                    TextButton(onPressed: widget.onResume, child: const Text('▶ 继续播放')),
                  IconCircleButton(icon: Icons.search, tooltip: '搜索', onPressed: widget.onSearch),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              key: _recKey,
              color: palette.aqua,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TODAY', style: TextStyle(color: palette.tealDark, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                            const SizedBox(height: 8),
                            Text('今日推荐', style: TextStyle(fontSize: 32, height: 1.12, fontWeight: FontWeight.w700, color: palette.ink)),
                            const SizedBox(height: 16),
                            if (rec == null)
                              Text('今天还没有新的节目', style: TextStyle(color: palette.mutedStrong))
                            else ...[
                              Text(rec.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.35)),
                              const SizedBox(height: 8),
                              Text(
                                '${rec.albumName.isEmpty ? 'NIO Radio' : rec.albumName} · ${formatDuration(rec.durationMs)}',
                                style: TextStyle(color: palette.mutedStrong, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Artwork(src: rec?.albumPic ?? '', darkSrc: rec?.albumPicDark ?? '', width: 120, height: 120),
                    ],
                  ),
                  const SizedBox(height: 20),
                  PrimaryPillButton(
                    label: playLabel,
                    icon: playIcon,
                    onPressed: widget.home.episodes.isEmpty ? null : widget.onPlayAll,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 160),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SectionHeading(title: widget.home.heading, count: widget.home.episodes.length),
                if (episodes.isEmpty)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 48), child: Center(child: Text('暂无可播放的节目', style: TextStyle(color: palette.mutedStrong))))
                else
                  DecoratedBox(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.line))),
                    child: Column(
                      children: [
                        for (final episode in episodes)
                          EpisodeRow(
                            episode: episode,
                            active: widget.player.current?.id == episode.id,
                            progress: widget.player.current?.id == episode.id && widget.player.duration.inSeconds > 0
                                ? (widget.player.position.inMilliseconds / widget.player.duration.inMilliseconds * 100).clamp(0, 100)
                                : 0,
                            onPlay: () => widget.onPlay(episode),
                          ),
                      ],
                    ),
                  ),
                if (widget.stale || widget.refreshing || widget.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        Expanded(child: Text(widget.refreshing ? '正在刷新目录…' : widget.error != null ? '目录刷新失败，继续使用缓存内容' : '显示的是上次缓存的目录')),
                        TextButton(onPressed: widget.onRetry, child: Text(widget.refreshing ? '刷新中' : '刷新目录')),
                      ],
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
      ),
    );
      },
    );
  }
}

class AlbumsScreen extends StatelessWidget {
  const AlbumsScreen({
    super.key,
    required this.catalog,
    required this.favoriteIds,
    this.showGrid = true,
    required this.onBack,
    required this.onSearch,
    required this.onOpenAlbum,
    required this.onToggleFavorite,
  });

  final Catalog catalog;
  final List<int> favoriteIds;
  final bool showGrid;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final ValueChanged<Album> onOpenAlbum;
  final ValueChanged<int> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final palette = NioPalette(Theme.of(context).brightness);
    return Column(
      children: [
        TopBar(
          leading: IconCircleButton(icon: Icons.arrow_back, tooltip: '返回主页', onPressed: onBack),
          title: const Text('全部专辑', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          trailing: IconCircleButton(icon: Icons.search, tooltip: '搜索', onPressed: onSearch),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 160),
            children: [
              SectionHeading(title: '全部专辑', count: catalog.albums.length),
              if (showGrid)
                CategoryAlbumSections(albums: catalog.albums, favoriteIds: favoriteIds, onOpenAlbum: onOpenAlbum, onToggleFavorite: onToggleFavorite),
              if (catalog.albums.isEmpty) Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 48), child: Text('暂无可用专辑', style: TextStyle(color: palette.mutedStrong)))),
            ],
          ),
        ),
      ],
    );
  }
}

class SearchView extends StatelessWidget {
  const SearchView({
    super.key,
    required this.catalog,
    required this.query,
    required this.favoriteIds,
    this.showGrid = true,
    required this.onBack,
    required this.onQuery,
    required this.onOpenAlbum,
    required this.onToggleFavorite,
  });

  final Catalog catalog;
  final String query;
  final List<int> favoriteIds;
  final bool showGrid;
  final VoidCallback onBack;
  final ValueChanged<String> onQuery;
  final ValueChanged<Album> onOpenAlbum;
  final ValueChanged<int> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final palette = NioPalette(Theme.of(context).brightness);
    final searching = query.trim().isNotEmpty;
    final value = query.trim().toLowerCase();
    final filtered = searching
        ? catalog.albums.where((album) => '${album.name} ${album.description} ${album.host}'.toLowerCase().contains(value)).toList()
        : const <Album>[];
    return Column(
      children: [
        TopBar(
          leading: IconCircleButton(icon: Icons.arrow_back, tooltip: '返回', onPressed: onBack),
          title: SearchField(value: query, onChanged: onQuery),
          trailing: query.isEmpty
              ? const SizedBox(width: 44)
              : IconCircleButton(icon: Icons.close, tooltip: '清空搜索', onPressed: () => onQuery('')),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 160),
            children: [
              SectionHeading(title: '全部专辑', count: searching ? filtered.length : catalog.albums.length),
              if (searching) ...[
                AlbumGrid(albums: filtered, favoriteIds: favoriteIds, onOpenAlbum: onOpenAlbum, onToggleFavorite: onToggleFavorite),
                if (filtered.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 48), child: Center(child: Text('没有找到匹配的专辑', style: TextStyle(color: palette.mutedStrong)))),
              ] else if (showGrid)
                CategoryAlbumSections(albums: catalog.albums, favoriteIds: favoriteIds, onOpenAlbum: onOpenAlbum, onToggleFavorite: onToggleFavorite),
            ],
          ),
        ),
      ],
    );
  }
}

class AlbumView extends StatefulWidget {
  const AlbumView({
    super.key,
    required this.api,
    required this.album,
    required this.onBack,
    required this.onPlay,
    required this.onAddLater,
    required this.favorited,
    required this.onToggleFavorite,
  });

  final NioApi api;
  final Album album;
  final bool favorited;
  final VoidCallback onBack;
  final void Function(Episode episode, List<Episode> queue) onPlay;
  final LaterAddResult Function(Episode episode) onAddLater;
  final VoidCallback onToggleFavorite;

  @override
  State<AlbumView> createState() => _AlbumViewState();
}

class _AlbumViewState extends State<AlbumView> {
  final _episodes = <Episode>[];
  final _scroll = ScrollController();
  var _page = 1;
  var _hasMore = false;
  var _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_tryLoadMore);
    _load(1);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _tryLoadMore() {
    if (!_scroll.hasClients || _loading || !_hasMore || _error != null) return;
    if (_scroll.position.extentAfter < 400) _load(_page + 1);
  }

  Future<void> _load(int page) async {
    if (page > 1 && _loading) return;
    _loading = true;
    setState(() {
      _error = null;
      if (page == 1) _episodes.clear();
    });
    try {
      final result = await widget.api.fetchAlbumPage(widget.album.id, page: page);
      if (!mounted) return;
      setState(() {
        _episodes.addAll(result.episodes);
        _page = page;
        _hasMore = result.hasMore;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryLoadMore();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = NioPalette(Theme.of(context).brightness);
    final album = widget.album;
    return Column(
      children: [
        TopBar(
          leading: IconCircleButton(icon: Icons.arrow_back, tooltip: '返回专辑列表', onPressed: widget.onBack),
          trailing: FavoriteButton(favorited: widget.favorited, name: album.name, onPressed: widget.onToggleFavorite),
          title: Column(
            children: [
              Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text('${album.episodeCount} 集', style: TextStyle(color: palette.muted, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 160),
            children: [
              Row(
                children: [
                  Artwork(src: album.imageUrl, darkSrc: album.imageUrlDark, width: 88, height: 88),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('节目列表', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(album.description.isEmpty ? 'NIO Radio 精选内容' : album.description, style: TextStyle(color: palette.mutedStrong)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Row(
                  children: [
                    Icon(Icons.error_outline, color: palette.danger),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('节目加载失败，请检查网络后重试')),
                    TextButton.icon(onPressed: () => _load(_page), icon: const Icon(Icons.refresh, size: 16), label: const Text('重新加载')),
                  ],
                ),
              if (_loading && _episodes.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('正在加载节目…'))),
              for (final episode in _episodes)
                EpisodeRow(
                  episode: episode,
                  onPlay: () => widget.onPlay(episode, _episodes),
                  action: IconButton(
                    tooltip: '稍后播放',
                    onPressed: () {
                      final result = widget.onAddLater(episode);
                      final text = result.reason == 'limit'
                          ? '稍后播放最多保存 50 条'
                          : !result.added
                              ? '已在稍后播放'
                              : '已添加到稍后播放';
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
                    },
                    icon: const Icon(Icons.more_horiz, size: 15),
                  ),
                ),
              if (!_loading && _error == null && _episodes.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: Text('这个专辑还没有节目'))),
              if (_loading && _episodes.isNotEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: Text('正在加载下一页…'))),
            ],
          ),
        ),
      ],
    );
  }
}

class FavoritesView extends StatelessWidget {
  const FavoritesView({
    super.key,
    required this.catalog,
    required this.favoriteIds,
    required this.onBack,
    required this.onBrowse,
    required this.onOpenAlbum,
    required this.onToggleFavorite,
  });

  final Catalog catalog;
  final List<int> favoriteIds;
  final VoidCallback onBack;
  final VoidCallback onBrowse;
  final ValueChanged<Album> onOpenAlbum;
  final ValueChanged<int> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final palette = NioPalette(Theme.of(context).brightness);
    final byId = {for (final album in catalog.albums) album.id: album};
    final favorites = favoriteIds.map((id) => byId[id]).whereType<Album>().toList();
    return Column(
      children: [
        TopBar(
          leading: IconCircleButton(icon: Icons.arrow_back, tooltip: '返回主页', onPressed: onBack),
          title: const Text('专辑收藏', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 160),
            children: [
              SectionHeading(title: '专辑收藏', count: favorites.length),
              if (favorites.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(Icons.favorite_border, size: 32, color: palette.muted),
                      const SizedBox(height: 12),
                      const Text('还没有收藏专辑', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('在「全部专辑」里点击专辑标题右侧的 ☆ 即可收藏。', textAlign: TextAlign.center, style: TextStyle(color: palette.mutedStrong)),
                      const SizedBox(height: 16),
                      TextButton(onPressed: onBrowse, child: const Text('去全部专辑看看')),
                    ],
                  ),
                )
              else
                AlbumGrid(albums: favorites, favoriteIds: favoriteIds, onOpenAlbum: onOpenAlbum, onToggleFavorite: onToggleFavorite),
            ],
          ),
        ),
      ],
    );
  }
}

class CategoryAlbumSections extends StatefulWidget {
  const CategoryAlbumSections({super.key, required this.albums, required this.favoriteIds, required this.onOpenAlbum, required this.onToggleFavorite});
  final List<Album> albums;
  final List<int> favoriteIds;
  final ValueChanged<Album> onOpenAlbum;
  final ValueChanged<int> onToggleFavorite;

  @override
  State<CategoryAlbumSections> createState() => _CategoryAlbumSectionsState();
}

class _CategoryAlbumSectionsState extends State<CategoryAlbumSections> {
  String? _expanded;
  var _expandedRest = false;

  @override
  Widget build(BuildContext context) {
    final data = groupAlbumsByCategory(widget.albums, widget.favoriteIds);
    return Column(
      children: [
        for (final group in data.groups)
          if (group.albums.isNotEmpty) ...[
            _heading(group.label, group.albums.length, _expanded == group.id, () {
              setState(() => _expanded = _expanded == group.id ? null : group.id);
            }),
            AlbumGrid(
              albums: _expanded == group.id ? group.albums : group.albums.take(12).toList(),
              favoriteIds: widget.favoriteIds,
              onOpenAlbum: widget.onOpenAlbum,
              onToggleFavorite: widget.onToggleFavorite,
            ),
          ],
        if (data.rest.isNotEmpty) ...[
          _heading('更多专辑', data.rest.length, _expandedRest, () => setState(() => _expandedRest = !_expandedRest)),
          AlbumGrid(
            albums: _expandedRest ? data.rest : data.rest.take(12).toList(),
            favoriteIds: widget.favoriteIds,
            onOpenAlbum: widget.onOpenAlbum,
            onToggleFavorite: widget.onToggleFavorite,
          ),
        ],
      ],
    );
  }

  Widget _heading(String label, int count, bool expanded, VoidCallback onTap) {
    final palette = NioPalette(Theme.of(context).brightness);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('$count', style: TextStyle(color: palette.muted, fontSize: 13)),
            AnimatedRotation(
              turns: expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 160),
              child: Icon(Icons.chevron_right, color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class AlbumGrid extends StatelessWidget {
  const AlbumGrid({super.key, required this.albums, required this.favoriteIds, required this.onOpenAlbum, required this.onToggleFavorite});
  final List<Album> albums;
  final List<int> favoriteIds;
  final ValueChanged<Album> onOpenAlbum;
  final ValueChanged<int> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            spacing: gap,
            runSpacing: 20,
            children: [
              for (final album in albums)
                SizedBox(
                  width: width,
                  child: AlbumRow(
                    album: album,
                    grid: true,
                    favorited: favoriteIds.contains(album.id),
                    onOpen: () => onOpenAlbum(album),
                    onToggleFavorite: () => onToggleFavorite(album.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key, required this.player, required this.onToggle, required this.onSeek, required this.onOpenQueue});
  final RadioPlayer player;
  final VoidCallback onToggle;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) {
    final palette = NioPalette(Theme.of(context).brightness);
    final episode = player.current!;
    final maxSeconds = player.duration.inSeconds > 0 ? player.duration.inSeconds : (episode.durationMs ~/ 1000);
    final position = player.position.inSeconds.clamp(0, maxSeconds);
    return Material(
      color: palette.surface,
      elevation: 10,
      shadowColor: const Color(0x1F091C2F),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Artwork(src: episode.albumPic, darkSrc: episode.albumPicDark, width: 48, height: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(episode.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                      Text(episode.albumName.isEmpty ? 'NIO Radio' : episode.albumName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.muted, fontSize: 12)),
                    ],
                  ),
                ),
                _roundButton(palette, player.playing ? Icons.pause : Icons.play_arrow, player.playing ? '暂停' : '播放', onToggle),
                const SizedBox(width: 8),
                _roundButton(palette, Icons.queue_music, '打开播放列表', onOpenQueue),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(formatClock(position), style: TextStyle(color: palette.muted, fontSize: 11)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: palette.teal,
                      inactiveTrackColor: palette.line,
                      thumbColor: palette.surface,
                    ),
                    child: Slider(
                      min: 0,
                      max: maxSeconds == 0 ? 1 : maxSeconds.toDouble(),
                      value: maxSeconds == 0 ? 0 : position.toDouble(),
                      onChanged: maxSeconds == 0 ? null : (value) => onSeek(Duration(seconds: value.round())),
                    ),
                  ),
                ),
                Text(formatClock(maxSeconds), style: TextStyle(color: palette.muted, fontSize: 11)),
              ],
            ),
            if (player.error != null)
              Row(
                children: [
                  Expanded(child: Text(player.error!, style: TextStyle(color: palette.danger, fontSize: 12))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _roundButton(NioPalette palette, IconData icon, String tooltip, VoidCallback onPressed) {
    return Material(
      color: palette.surfaceSoft,
      shape: const CircleBorder(),
      child: IconButton(tooltip: tooltip, onPressed: onPressed, icon: Icon(icon, size: 21)),
    );
  }
}

class QueueSheet extends StatefulWidget {
  const QueueSheet({
    super.key,
    required this.player,
    required this.later,
    required this.tab,
    required this.sleepLabel,
    required this.onTab,
    required this.onPlay,
    required this.onPlayLater,
    required this.onRemove,
    required this.onPlayNext,
    required this.onRemoveLater,
    required this.onSleepMinutes,
    required this.onSleepEpisodeEnd,
    required this.onClearSleep,
    required this.onClose,
  });

  final RadioPlayer player;
  final List<Episode> later;
  final String tab;
  final String? sleepLabel;
  final ValueChanged<String> onTab;
  final ValueChanged<Episode> onPlay;
  final ValueChanged<Episode> onPlayLater;
  final Future<void> Function(int id) onRemove;
  final ValueChanged<Episode> onPlayNext;
  final ValueChanged<int> onRemoveLater;
  final ValueChanged<int> onSleepMinutes;
  final VoidCallback onSleepEpisodeEnd;
  final VoidCallback onClearSleep;
  final VoidCallback onClose;

  @override
  State<QueueSheet> createState() => _QueueSheetState();
}

/// Owns tab/later/sleep state locally: the parent's setState cannot rebuild this
/// modal route, and the player's notifications are too coarse (none while paused).
class _QueueSheetState extends State<QueueSheet> {
  late String _tab = widget.tab;
  late final List<Episode> _later = List.of(widget.later);
  late String? _sleepLabel = widget.sleepLabel;

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final later = _later;
    final tab = _tab;
    final sleepLabel = _sleepLabel;
    final palette = NioPalette(Theme.of(context).brightness);
    final items = tab == 'history'
        ? player.history
        : tab == 'later'
            ? later
            : player.queue;
    final empty = tab == 'queue'
        ? '播放列表是空的'
        : tab == 'history'
            ? '还没有听过的节目'
            : '稍后播放是空的';
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430, maxHeight: 640),
        child: Material(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                Container(width: 36, height: 4, decoration: BoxDecoration(color: palette.line, borderRadius: BorderRadius.circular(99))),
                Row(
                  children: [
                    const Expanded(child: Text('播放列表', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
                    PopupMenuButton<String>(
                      tooltip: '睡眠定时',
                      icon: Icon(Icons.timer_outlined, color: sleepLabel != null ? palette.tealDark : palette.ink),
                      onSelected: (value) {
                        setState(() {
                          if (value == 'end') {
                            _sleepLabel = '本集结束';
                          } else if (value == 'off') {
                            _sleepLabel = null;
                          } else {
                            _sleepLabel = '$value 分钟';
                          }
                        });
                        if (value == 'end') {
                          widget.onSleepEpisodeEnd();
                        } else if (value == 'off') {
                          widget.onClearSleep();
                        } else {
                          widget.onSleepMinutes(int.parse(value));
                        }
                      },
                      itemBuilder: (context) => [
                        for (final minutes in [15, 30, 45, 60]) PopupMenuItem(value: '$minutes', child: Text('$minutes 分钟')),
                        const PopupMenuItem(value: 'end', child: Text('本集结束')),
                        if (sleepLabel != null) const PopupMenuItem(value: 'off', child: Text('关闭定时')),
                      ],
                    ),
                    IconButton(tooltip: '收起播放列表', onPressed: widget.onClose, icon: const Icon(Icons.close)),
                  ],
                ),
                Row(
                  children: [
                    _tabButton(context, 'queue', '播放列表', player.queue.length),
                    _tabButton(context, 'history', '最近听过', player.history.length),
                    _tabButton(context, 'later', '稍后播放', later.length),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.music_note_outlined, size: 28, color: palette.muted),
                              const SizedBox(height: 8),
                              Text(empty),
                              Text('选择一个节目后，它会出现在这里', style: TextStyle(color: palette.muted)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final episode = items[index];
                            final active = tab == 'queue' && player.current?.id == episode.id;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Artwork(src: episode.albumPic, darkSrc: episode.albumPicDark, width: 48, height: 48),
                              title: Text(episode.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${episode.albumName.isEmpty ? 'NIO Radio' : episode.albumName} · ${formatDuration(episode.durationMs)}'),
                              trailing: active
                                  ? Icon(Icons.music_note, color: palette.tealDark)
                                  : tab == 'queue'
                                      ? PopupMenuButton<String>(
                                          tooltip: '管理 ${episode.title}',
                                          onSelected: (value) {
                                            if (value == 'next') widget.onPlayNext(episode);
                                            if (value == 'remove') widget.onRemove(episode.id);
                                          },
                                          itemBuilder: (context) => const [
                                            PopupMenuItem(value: 'next', child: Text('下一首播放')),
                                            PopupMenuItem(value: 'remove', child: Text('移出列表')),
                                          ],
                                        )
                                      : tab == 'later'
                                          ? IconButton(
                                              tooltip: '移出稍后播放',
                                              onPressed: () {
                                                setState(() => _later.removeWhere((item) => item.id == episode.id));
                                                widget.onRemoveLater(episode.id);
                                              },
                                              icon: const Icon(Icons.delete_outline),
                                            )
                                          : null,
                              onTap: () => tab == 'later' ? widget.onPlayLater(episode) : widget.onPlay(episode),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(BuildContext context, String id, String label, int count) {
    final palette = NioPalette(Theme.of(context).brightness);
    final selected = _tab == id;
    return Expanded(
      child: TextButton(
        onPressed: () {
          setState(() => _tab = id);
          widget.onTab(id);
        },
        child: Text(
          '$label $count',
          style: TextStyle(color: selected ? palette.ink : palette.muted, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
        ),
      ),
    );
  }
}
