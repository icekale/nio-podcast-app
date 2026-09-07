import 'api.dart';

const topicCategories = [
  ('news', '资讯热点'),
  ('car', '汽车蔚来'),
  ('business', '商业科技'),
  ('culture', '文化知识'),
  ('lifestyle', '生活兴趣'),
  ('audio', '音乐声音'),
  ('kids', '亲子成长'),
];

const _topicPriority = ['car', 'kids', 'audio', 'news', 'business', 'culture', 'lifestyle'];

const _pinnedAlbumIds = [5, 23];
const _boostedAlbumIds = [35, 584];
final _cityChannel = RegExp(r'城市资讯|城市频道|天气预报');

const _manualAlbumIds = <int, String>{
  799: 'news', 800: 'news', 30: 'news', 5: 'news', 23: 'news', 507: 'news', 356: 'news', 663: 'news', 107: 'news',
  35: 'kids', 728: 'kids', 741: 'kids', 472: 'kids', 458: 'kids',
  306: 'audio', 307: 'audio', 11: 'audio', 41: 'audio', 669: 'audio', 18: 'audio', 661: 'audio', 547: 'audio', 394: 'audio',
  584: 'culture', 577: 'culture',
  689: 'lifestyle', 692: 'lifestyle', 401: 'lifestyle',
  570: 'car', 438: 'car', 268: 'car', 308: 'car', 745: 'car', 735: 'car',
};

final _nameRules = <(String, RegExp)>[
  ('car', RegExp(r'蔚来|nio\b|onvo|乐道|萤火虫|提车|用车|爱车|约fan|驾驶|车友|保养|赛车|formula|es8|es9|et9|ec6|换电|车展|发布会|老司机|直通车|驾趣|nio day|nomi|蔚友|车机|蔚爱|阅蔚|同频|李斌|苏苏福福|王安宇|加电|牛屋|wo的车|玩转wo|蔚星', caseSensitive: false)),
  ('kids', RegExp(r'绘本|童声|儿童|少年|亲子|宝宝|哄娃|宝贝|童话|寓言|儿歌|家庭教育|孩子|拼读|汤姆·索亚|金龟子|小小少年|恐龙|礼貌|胡小闹|呼噜西游|亚斯与莉莉|黏糊糊|童言|萌宠补习|王国》儿童|安武林|米雪老师|海洋奇妙|超人救援|动物剧场|神奇动物|必读故事')),
  ('audio', RegExp(r'音乐|乐行|乐动|歪波|点唱机|点歌|电台|歌单|热歌|音乐会|乐光|乐章|band\b|dance|r&b|电音|古典|白噪音|vibration|weekend dance|年代电台|歌歌歌歌|自成音浪|seeds精选|hit music', caseSensitive: false)),
  ('news', RegExp(r'资讯|新闻|早间|晚间|速递|报道|早报|晚报|天气预报|城市频道|城市资讯|观察局|前方加速度|充电站|世界杯|摸鱼早报')),
  ('business', RegExp(r'商业|创业|投资|财经|科技|互联网|人工智能|\bai\b|工业|职场|经济|品牌|硅谷|编码|debug|tech talk|疯投|组织进化|一人公司|搞钱|美市|slow brand|果壳|十字路口', caseSensitive: false)),
  ('culture', RegExp(r'历史|文化|读书|书房|知识|科普|博物|艺术|文学|人文|诗词|唐诗|读库|世界史|节气|哲学|人物|讲堂|n问|生命周刊|魔法书|大宋|唐砖|汉乡|奥术|了不起的女性|城市记忆|城市地图|汉声', caseSensitive: false)),
  ('lifestyle', RegExp(r'生活|健康|养生|旅行|漫游|美食|咖啡|酒|运动|体育|游戏|电影|时尚|探店|玩乐地图|饭局|影视|健身|宠物|萌宠|目的地|吃喝|宵夜|律师|法律|机核|体育地平线|探险|杂谈|乱劈柴|百事有感觉|吃吃白相|fun游|津津有味|不开玩笑|映画|好梗|大口说|去现场|打工人|周刊|喜剧|剧场|剧谈|律师生活|海獭|脑筋|广播剧', caseSensitive: false)),
];

String? categorizeAlbum(Album album) {
  final manual = _manualAlbumIds[album.id];
  if (manual != null) return manual;
  final text = [album.name, album.description, album.latestEpisode?.title ?? ''].where((part) => part.isNotEmpty).join('\n');
  if (text.isEmpty) return null;
  final hits = _nameRules.where((rule) => rule.$2.hasMatch(text)).map((rule) => rule.$1).toSet();
  for (final id in _topicPriority) {
    if (hits.contains(id)) return id;
  }
  return null;
}

class CategoryGroup {
  const CategoryGroup({required this.id, required this.label, required this.albums});
  final String id;
  final String label;
  final List<Album> albums;
}

class CategorySectionsData {
  const CategorySectionsData({required this.groups, required this.rest});
  final List<CategoryGroup> groups;
  final List<Album> rest;
}

List<Album> sortAlbumsByLatest(List<Album> albums) {
  final next = [...albums];
  next.sort((a, b) {
    final time = (b.latestEpisode?.onlineTime ?? 0) - (a.latestEpisode?.onlineTime ?? 0);
    if (time != 0) return time;
    return a.id - b.id;
  });
  return next;
}

List<Album> sortAlbumsForDirectory(List<Album> albums, List<int> favoriteIds) {
  final favoriteOrder = <int, int>{
    for (var i = 0; i < favoriteIds.length; i++) favoriteIds[i]: i,
  };
  final favorites = <Album>[];
  final pinned = <Album>[];
  final boosted = <Album>[];
  final rest = <Album>[];
  final city = <Album>[];
  for (final album in albums) {
    if (favoriteOrder.containsKey(album.id)) {
      favorites.add(album);
    } else if (_pinnedAlbumIds.contains(album.id)) {
      pinned.add(album);
    } else if (_boostedAlbumIds.contains(album.id)) {
      boosted.add(album);
    } else if (_cityChannel.hasMatch(album.name)) {
      city.add(album);
    } else {
      rest.add(album);
    }
  }
  favorites.sort((a, b) => favoriteOrder[a.id]!.compareTo(favoriteOrder[b.id]!));
  pinned.sort((a, b) => _pinnedAlbumIds.indexOf(a.id).compareTo(_pinnedAlbumIds.indexOf(b.id)));
  boosted.sort((a, b) => _boostedAlbumIds.indexOf(a.id).compareTo(_boostedAlbumIds.indexOf(b.id)));
  return [...favorites, ...pinned, ...boosted, ...sortAlbumsByLatest(rest), ...sortAlbumsByLatest(city)];
}

CategorySectionsData groupAlbumsByCategory(List<Album> albums, [List<int> favoriteIds = const []]) {
  final groups = [
    for (final topic in topicCategories) CategoryGroup(id: topic.$1, label: topic.$2, albums: []),
  ];
  final rest = <Album>[];
  for (final album in albums) {
    final category = album.category ?? categorizeAlbum(album);
    final group = groups.where((item) => item.id == category).firstOrNull;
    if (group != null) {
      group.albums.add(album);
    } else {
      rest.add(album);
    }
  }
  return CategorySectionsData(
    groups: [
      for (final group in groups)
        CategoryGroup(id: group.id, label: group.label, albums: sortAlbumsForDirectory(group.albums, favoriteIds)),
    ],
    rest: sortAlbumsForDirectory(rest, favoriteIds),
  );
}

HomeSelection mergeDaytime(HomeSelection fallback, List<Episode> daytime) {
  if (daytime.isEmpty) return fallback;
  final daytimeIds = {for (final episode in daytime) episode.id};
  final extra = fallback.heading == '今日更新' ? fallback.episodes.where((episode) => !daytimeIds.contains(episode.id)) : const <Episode>[];
  return HomeSelection(heading: '日间', episodes: [...daytime, ...extra]);
}
