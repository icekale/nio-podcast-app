import 'package:flutter/material.dart';

import 'api.dart';
import 'format.dart';
import 'theme.dart';

class Artwork extends StatelessWidget {
  const Artwork({super.key, required this.src, this.darkSrc = '', this.width, this.height, this.radius = 8});

  final String src;
  final String darkSrc;
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = NioPalette(Theme.of(context).brightness);
    final url = palette.dark && darkSrc.isNotEmpty ? darkSrc : src;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: palette.surfaceSoft,
        child: url.isEmpty
            ? SizedBox(
                width: width ?? double.infinity,
                height: height ?? double.infinity,
                child: Icon(Icons.music_note_outlined, color: palette.tealDark, size: 22),
              )
            : Image.network(
                url,
                width: width ?? double.infinity,
                height: height ?? double.infinity,
                cacheWidth: artworkCacheWidth(context, width),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => SizedBox(
                  width: width ?? double.infinity,
                  height: height ?? double.infinity,
                  child: Icon(Icons.music_note_outlined, color: palette.tealDark, size: 22),
                ),
              ),
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.background,
    this.scrolled = false,
  });

  final Widget title;
  final Widget? leading;
  final Widget? trailing;
  final Color? background;
  final bool scrolled;

  @override
  Widget build(BuildContext context) {
    final palette = NioPalette(Theme.of(context).brightness);
    return Container(
      constraints: BoxConstraints(minHeight: 56 + MediaQuery.paddingOf(context).top),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top, 16, 0),
      decoration: BoxDecoration(
        color: background ?? palette.surface,
        border: Border(bottom: BorderSide(color: scrolled ? palette.line : palette.line.withValues(alpha: 0.72))),
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            SizedBox(width: 44, child: leading),
            Expanded(child: Center(child: title)),
            trailing ?? const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }
}

class IconCircleButton extends StatelessWidget {
  const IconCircleButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.size = 24});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: size,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon),
    );
  }
}

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.favorited,
    required this.onPressed,
    this.name = '',
  });

  final bool favorited;
  final VoidCallback onPressed;
  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = NioPalette(Theme.of(context).brightness);
    return IconButton(
      tooltip: favorited ? '取消收藏 $name' : '收藏 $name',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(
        favorited ? Icons.favorite : Icons.favorite_border,
        size: 18,
        color: favorited ? NioColors.logoTeal : palette.muted,
      ),
    );
  }
}

class PrimaryPillButton extends StatelessWidget {
  const PrimaryPillButton({super.key, required this.label, required this.icon, this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = NioPalette(Theme.of(context).brightness);
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: NioColors.accentInk),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: NioColors.accentInk)),
        style: FilledButton.styleFrom(
          backgroundColor: palette.teal,
          disabledBackgroundColor: palette.teal.withValues(alpha: 0.45),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

class EpisodeRow extends StatelessWidget {
  const EpisodeRow({
    super.key,
    required this.episode,
    required this.onPlay,
    this.active = false,
    this.progress = 0,
    this.action,
  });

  final Episode episode;
  final VoidCallback onPlay;
  final bool active;
  final double progress;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = NioPalette(Theme.of(context).brightness);
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.line))),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onPlay,
              child: Row(
                children: [
                  Artwork(src: episode.albumPic, darkSrc: episode.albumPicDark, width: 68, height: 68),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.35,
                            color: active ? palette.tealDark : palette.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DefaultTextStyle(
                          style: TextStyle(color: palette.muted, fontSize: 12.5, height: 1.25),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(episode.albumName.isEmpty ? 'NIO Radio' : episode.albumName),
                              Text('|', style: TextStyle(color: palette.line)),
                              Icon(Icons.schedule, size: 14, color: palette.muted),
                              Text(formatDuration(episode.durationMs)),
                              if (episode.onlineTime > 0) ...[
                                Text('|', style: TextStyle(color: palette.line)),
                                Text(formatDate(episode.onlineTime)),
                              ],
                              if (progress > 0)
                                Text('已听${progress.round()}%', style: TextStyle(color: palette.tealDark)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class AlbumRow extends StatelessWidget {
  const AlbumRow({
    super.key,
    required this.album,
    required this.onOpen,
    this.grid = false,
    this.favorited = false,
    this.onToggleFavorite,
  });

  final Album album;
  final VoidCallback onOpen;
  final bool grid;
  final bool favorited;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final palette = NioPalette(Theme.of(context).brightness);
    final subtitle = album.directorySubtitle.isNotEmpty
        ? album.directorySubtitle
        : (album.latestEpisode?.title ?? (album.description.isEmpty ? '暂无节目' : album.description));
    final toggle = onToggleFavorite;
    final heart = toggle == null
        ? null
        : FavoriteButton(favorited: favorited, name: album.name, onPressed: toggle);
    if (grid) {
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          InkWell(
            onTap: onOpen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Artwork(src: album.imageUrl, darkSrc: album.imageUrlDark, radius: 8),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 48),
                  child: Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 48),
                  child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.muted, fontSize: 13)),
                ),
              ],
            ),
          ),
          if (heart != null) Positioned(right: 0, bottom: 0, child: heart),
        ],
      );
    }
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.line))),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Artwork(src: album.imageUrl, darkSrc: album.imageUrlDark, width: 68, height: 68),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (onToggleFavorite == null) Icon(Icons.chevron_right, color: palette.muted),
                  ],
                ),
              ),
            ),
          ),
          ?heart,
        ],
      ),
    );
  }
}

class SearchField extends StatefulWidget {
  const SearchField({super.key, required this.value, required this.onChanged, this.hint = '搜索专辑'});
  final String value;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = NioPalette(Theme.of(context).brightness);
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        isDense: true,
        border: InputBorder.none,
        hintStyle: TextStyle(color: palette.muted),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = NioPalette(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w600, height: 1.2)),
          const SizedBox(width: 8),
          Text('$count', style: TextStyle(color: palette.muted, fontSize: 15)),
        ],
      ),
    );
  }
}

int artworkCacheWidth(BuildContext context, double? width) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final logical = width ?? MediaQuery.sizeOf(context).width / 2;
  return (logical * dpr).round().clamp(64, 720);
}

void precacheAlbumArt(BuildContext context, List<Album> albums) {
  final width = artworkCacheWidth(context, null);
  for (final album in albums.take(8)) {
    final url = Theme.of(context).brightness == Brightness.dark && album.imageUrlDark.isNotEmpty
        ? album.imageUrlDark
        : album.imageUrl;
    if (url.isEmpty) continue;
    precacheImage(ResizeImage(NetworkImage(url), width: width), context);
  }
}
