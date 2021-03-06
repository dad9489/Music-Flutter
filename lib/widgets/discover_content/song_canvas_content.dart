import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_app/discover.dart';
import 'package:music_app/widgets/discover_content/progress_indicator.dart';

import 'package:music_app/widgets/discover_content/video_content.dart';
import 'package:music_app/widgets/discover_content/song_description.dart';
import 'package:music_app/widgets/discover_content/actions_toolbar.dart';

import 'overlay.dart';
class SongCanvasContent extends StatefulWidget {
  final String canvasUrl;
  final String albumArtUrl;
  final String songName;
  final String albumArtist;
  final double playerRatio;
  final double lastPlayerRatio;
  final Function onInteraction;
  final bool paused;
  final bool likedCurrentSong;
  final Size navBarSize;

  SongCanvasContent(this.canvasUrl, this.albumArtUrl, this.songName,
      this.albumArtist, this.lastPlayerRatio, this.playerRatio,
      this.onInteraction, this.paused, this.likedCurrentSong, this.navBarSize);

  @override
  _SongCanvasContentState createState() => _SongCanvasContentState();
}
class _SongCanvasContentState extends State<SongCanvasContent> {

  static MediaQueryData queryData;
  final GlobalKey<PostOverlayState> _likeOverlayState = GlobalKey<PostOverlayState>();
  final GlobalKey<ActionsToolbarState> _actionsToolbarState = GlobalKey<ActionsToolbarState>();
  Widget _likeOverlay;

  @override
  void initState() {
    super.initState();
    _likeOverlay = PostOverlay(OverlayType.LIKE, key: _likeOverlayState);
  }

  Widget _getGradient() {
    return Container(
      height: queryData.size.height,
      decoration: BoxDecoration(
          color: Colors.white,
          gradient: LinearGradient(
              begin: FractionalOffset.topCenter,
              end: FractionalOffset.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.0),
                Colors.black.withOpacity(0.6),
              ],
              stops: [
                0.0,
                1.0
              ])),
    );
  }

  Widget _getCanvas() {
    if(Uri.parse(widget.canvasUrl).pathSegments.contains("video")) {
      return VideoContent(widget.canvasUrl, widget.paused);
    } else {
      return Container(
        decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(widget.canvasUrl),
          fit: BoxFit.cover,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    queryData = MediaQuery.of(context);
    return Stack(
      children: [
        _getCanvas(),
        _getGradient(),
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SongDescription(widget.albumArtUrl, widget.songName, widget.albumArtist),
              Container(height: widget.navBarSize.height,)
            ]),
        GestureDetector(
            onTap: (){widget.onInteraction(Interaction.PAUSE, byUser: true);},
            onDoubleTap: () async {
              _likeOverlayState.currentState.like();
              bool success = await widget.onInteraction(Interaction.LIKE);
              if(success) {
                _actionsToolbarState.currentState.externalLike();
              }
            },
            child: Stack(
              children: [
                PostOverlay(OverlayType.PAUSE, isPaused: widget.paused),
                _likeOverlay,
              ],
            )),
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              alignment: Alignment.bottomRight,
                child: ActionsToolbar(
                    widget.onInteraction,
                    widget.likedCurrentSong,
                    key: _actionsToolbarState)
            ),
            ContentProgressIndicator(widget.lastPlayerRatio, widget.playerRatio),
            Container(height: widget.navBarSize.height,)
          ],
        ),
      ],
    );
  }
}