import 'package:flutter/material.dart';
import 'package:music_app/middleware.dart';
import 'package:music_app/model/song.dart';
import 'package:music_app/page_controller.dart';
import 'package:music_app/widgets/login.dart';
import 'package:splashscreen/splashscreen.dart';
import "dart:async";
import 'package:music_app/model/user_profile.dart';

class SplashScreenPage extends StatefulWidget {
  @override
  _SplashScreenState createState() => new _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreenPage> {

  Future<Widget> loadFromFuture() async {
    SpotifyProfile profile = SpotifyProfile();
    await profile.loginFromFile();
    if(profile.isLoggedIn) {
      // TODO make request for fresh profile data
      List<Song> songs = await getRecommendations(numSongs: 20);
      List<Song> likedSongs = await getLikedSongs();
      return Future.value(PagesHolder(songs, likedSongs));
    } else {
      return Future.value(LoginPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return new SplashScreen(
        navigateAfterFuture: loadFromFuture(),
//        navigateAfterSeconds: Discover(),
        image: Image(image: AssetImage('assets/img/logo.png')),
        backgroundColor: Colors.black,
//        styleTextUnderTheLoader: new TextStyle(),
        photoSize: 115.0,
        loaderColor: Color(0xFFC77DFF)
    );
  }
}