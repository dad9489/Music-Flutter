import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_app/widgets/discover_content/more_options_sheet.dart';
import 'package:music_app/widgets/discover_content/music_player.dart';
import 'package:music_app/page_controller.dart';
import 'package:music_app/widgets/discover_content_manager.dart';

import 'middleware.dart';
import 'model/song.dart';

class Discover extends StatefulWidget {
  PageStatus discoverStatus;
  final List<Song> initialSongs;
  final List<Song> initialLikedSongs;
  final Size navBarSize;

  Discover(this.initialSongs, this.initialLikedSongs, this.discoverStatus, this.navBarSize, {Key key}) : super(key: key);

  @override
  DiscoverState createState() => DiscoverState();
}

enum PlayerState { STOPPED, PLAYING, PAUSED }

enum Interaction { REFRESH, LOAD_MORE, CHANGE_PAGE, PAUSE, LIKE, UNLIKE, OPEN_SPOTIFY, SHARE, MORE_OPTIONS }

class DiscoverState extends State<Discover> with AutomaticKeepAliveClientMixin {

  MusicPlayer _musicPlayer;
  double _playerRatio;
  double _lastPlayerRatio;
  bool _paused = false;
  bool _userPaused = false;
  Duration _lastUpdate = Duration(seconds: 0);
  Widget overlay = Container();
  List<Song> _songs;
  int _currentIdx = 0;
  bool _fetchingSongs = false;
  bool _likedCurrentSong = false;
  List<Song> _likedSongs;
  final GlobalKey<ContentManagerState> _contentManagerState = GlobalKey<ContentManagerState>();

  @override
  void initState() {
    super.initState();
    setState(() {
      _songs = widget.initialSongs;
      _likedSongs = widget.initialLikedSongs;
    });
    _musicPlayer = MusicPlayer(_songs[0].previewUrl, _onAudioPositionChanged);
    _musicPlayer.initAudioPlayer();
  }

  void jumpToTop() {
    _contentManagerState.currentState.jumpToTop();
  }

  void _onAudioPositionChanged(Duration p) {
    if(p != null && (p.inMilliseconds >= _lastUpdate.inMilliseconds + 190 || p.inMilliseconds < _lastUpdate.inMilliseconds)) {
      setState(() {
        _playerRatio = min(1.0,
            max(0.0, p.inMilliseconds / _musicPlayer.duration.inMilliseconds));
        _lastPlayerRatio = min(1.0, max(0.0,
            _lastUpdate.inMilliseconds / _musicPlayer.duration.inMilliseconds));
        _lastUpdate = p;
      });
    }
  }


  void _onPageChanged(int idx) async {
    setState(() {
      _likedCurrentSong = _likedSongs.contains(_songs[idx]);
      _paused = false;
      _currentIdx = idx;
    });
    await _musicPlayer.stop();
    _playerRatio = 0.0;
    _lastPlayerRatio = 0.0;
    await _musicPlayer.play(_songs[_currentIdx].previewUrl);
  }

  void setOverlay(Widget overlayWidget) {
    setState(() {
      overlay = overlayWidget;
    });
  }

  void clearOverlay() {
    setState(() {
      overlay = Container();
    });
  }

  void _togglePause(bool pausedByUser) {
    setState(() {
      _paused = !_paused;
      if(pausedByUser) {
        _userPaused = _paused;
      }
    });
    if(_paused) {
      _musicPlayer.pause();
    } else {
      _musicPlayer.play(_musicPlayer.currentUrl);
      clearOverlay();
    }
  }

  dynamic _interactionHandler(Interaction interaction, {byUser: true, int idx}) async {
    dynamic response;
    switch (interaction) {
      case Interaction.PAUSE:
        _togglePause(byUser);
        break;
      case Interaction.CHANGE_PAGE:
        _onPageChanged(idx);
        break;
      case Interaction.LOAD_MORE:
        response = _onLoadMore();
        break;
      case Interaction.REFRESH:
        response = _onRefresh();
        break;
      case Interaction.LIKE:
        response = _like();
        break;
      case Interaction.UNLIKE:
        response = _unlike();
        break;
      case Interaction.MORE_OPTIONS:
        ModalOptionsSheet(
            _contentManagerState.currentState.skipPage,
            _songs[_currentIdx]
        ).showBottomSheet(context);
        break;
      case Interaction.OPEN_SPOTIFY:
        response = interact(_songs[_currentIdx], "open");
        _songs[_currentIdx].openInSpotify();
       break;
      case Interaction.SHARE:
        response = interact(_songs[_currentIdx], "share");
        _songs[_currentIdx].share();
        break;
    }
    return response;
  }

  Future<bool> _like() async {
    if(!_likedCurrentSong) {
      print("Liked song");
      bool success = await interact(_songs[_currentIdx], "like") == 200;
      if(success) {
        setState(() {
          _likedCurrentSong = true;
          _likedSongs.add(_songs[_currentIdx]);
        });
      }
      return success;
    }
    return false;
  }

  Future<bool> _unlike() async {
    if(_likedCurrentSong) {
      print("Unliked song");
      bool success = await interact(_songs[_currentIdx], "unlike") == 200;
      if(success) {
        setState(() {
          _likedCurrentSong = false;
          _likedSongs.remove(_songs[_currentIdx]);
        });
      }
      return success;
    }
    return false;
  }

  Future<List<Song>> _onRefresh() async {
    print("Discover onRefresh");
    if(!_fetchingSongs) {
      // Initially get a small amount of songs to reduce load time
      _fetchingSongs = true;
      List<Song> songs = await getRecommendations(numSongs: 20);
      setState(() {
        _songs = songs;
        _currentIdx = 0;
      });
      _onPageChanged(0);
      _fetchingSongs = false;
    } else {
      print("Refresh skipped - already fetching songs");
    }
    return _songs;
  }

  Future<Map<String, dynamic>> _onLoadMore() async {
    print("Discover onLoadMore");
    if(!_fetchingSongs) {
      _fetchingSongs = true;
      List<Song> songs = await getRecommendations(numSongs: 50);
      setState(() {
        _songs.addAll(songs);
        _currentIdx++;
      });
      // TODO add this back if there starts to be lag from too many songs being
      //  loaded at once. If it is added back, there will need to be some
      //  debugging to make things work smoothly when dynamically keeping the
      //  song buffer.
//      if(_songs.length > maxSongs && (_currentIdx > maxSongs - _songs.length)) {
//        // Remove songs far back in list so we don't need to keep track of too many
//        int cutoff = _songs.length - maxSongs;
//        List<Song> sublist = _songs.sublist(cutoff);
//        setState(() {
//          _currentIdx = max(0, _currentIdx-cutoff);
//          _songs = sublist;
//        });
//      }
      _fetchingSongs = false;
    } else {
      print("Load more skipped - already fetching songs");
    }
    return {"currentIdx": _currentIdx, "songs": _songs};
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if(_paused && !_userPaused && widget.discoverStatus == PageStatus.returning) {
      _togglePause(false);
      widget.discoverStatus = PageStatus.active;
    } else if(!_paused && widget.discoverStatus == PageStatus.inactive) {
      _togglePause(false);
    }
      return ContentManager(
          _songs,
          _lastPlayerRatio,
          _playerRatio,
          _musicPlayer.currentUrl,
          _interactionHandler,
          _paused,
          _likedCurrentSong,
          widget.navBarSize,
          key: _contentManagerState);
  }

  @override
  void dispose() {
    _musicPlayer.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}
