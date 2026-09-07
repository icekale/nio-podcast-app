import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'player.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.api, required this.player});

  final NioApi api;
  final RadioPlayer player;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeSelection? _home;
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_onPlayer);
    _load();
  }

  @override
  void dispose() {
    widget.player.removeListener(_onPlayer);
    super.dispose();
  }

  void _onPlayer() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await widget.api.fetchCatalog();
      if (!mounted) return;
      setState(() {
        _home = selectHomeEpisodes(catalog.albums);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _playAt(int index) async {
    final home = _home;
    if (home == null) return;
    await widget.player.playQueue(home.episodes, index);
  }

  void _openQueue() {
    final player = widget.player;
    if (player.queue.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListenableBuilder(
          listenable: player,
          builder: (context, _) {
            return ListView.builder(
              itemCount: player.queue.length,
              itemBuilder: (context, index) {
                final episode = player.queue[index];
                final active = index == player.index;
                return ListTile(
                  selected: active,
                  leading: _cover(episode.albumPic),
                  title: Text(episode.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(episode.albumName),
                  onTap: () {
                    Navigator.pop(context);
                    player.playQueue(player.queue, index);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).appBarTheme.systemOverlayStyle ?? SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset('assets/logo.png', height: 28, errorBuilder: (_, _, _) => const SizedBox.shrink()),
              const SizedBox(width: 10),
              const Text('NIO Radio'),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(child: _body(scheme)),
            if (widget.player.current != null) _miniPlayer(scheme),
          ],
        ),
      ),
    );
  }

  Widget _body(ColorScheme scheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    final home = _home!;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      itemCount: home.episodes.length + 1,
      separatorBuilder: (_, _) => Divider(color: scheme.brightness == Brightness.dark ? NioColors.darkLine : NioColors.lightLine),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(home.heading, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          );
        }
        final episode = home.episodes[index - 1];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _cover(episode.albumPic),
          title: Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('${episode.albumName} · ${_formatDuration(episode.durationMs)}'),
          onTap: () => _playAt(index - 1),
        );
      },
    );
  }

  Widget _miniPlayer(ColorScheme scheme) {
    final episode = widget.player.current!;
    return Material(
      color: scheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: ListTile(
          leading: _cover(episode.albumPic),
          title: Text(episode.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(episode.albumName, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(onPressed: widget.player.previous, icon: const Icon(Icons.skip_previous)),
              IconButton(
                onPressed: widget.player.toggle,
                icon: Icon(widget.player.playing ? Icons.pause_circle : Icons.play_circle),
              ),
              IconButton(onPressed: widget.player.next, icon: const Icon(Icons.skip_next)),
              IconButton(onPressed: _openQueue, icon: const Icon(Icons.queue_music)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cover(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url.isEmpty
          ? Container(width: 48, height: 48, color: NioColors.logoTeal)
          : Image.network(url, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, _, _) {
              return Container(width: 48, height: 48, color: NioColors.logoTeal);
            }),
    );
  }
}

String _formatDuration(int ms) {
  final total = (ms / 1000).round();
  final minutes = total ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
