import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:ffi/ffi.dart';

// Define the functions you need from libvlc.dll
class VLC {
  static late DynamicLibrary _libvlc;

  // Load libvlc.dll dynamically
  static void loadLibrary(String path) {
    _libvlc = DynamicLibrary.open(path);
  }

  // Declare FFI function signatures here
  static late final _libvlc_new = _libvlc.lookupFunction<
      Pointer<Void> Function(Int32 argc, Pointer<Pointer<Utf8>> argv),
      Pointer<Void> Function(int argc, Pointer<Pointer<Utf8>> argv)>('libvlc_new');

  static late final _libvlc_media_new_location = _libvlc.lookupFunction<
      Pointer<Void> Function(Pointer<Void> instance, Pointer<Utf8> url),
      Pointer<Void> Function(Pointer<Void> instance, Pointer<Utf8> url)>('libvlc_media_new_location');

  static late final _libvlc_media_player_new_from_media = _libvlc.lookupFunction<
      Pointer<Void> Function(Pointer<Void> media),
      Pointer<Void> Function(Pointer<Void> media)>('libvlc_media_player_new_from_media');

  static late final _libvlc_media_player_play = _libvlc.lookupFunction<
      Int32 Function(Pointer<Void> mediaPlayer),
      int Function(Pointer<Void> mediaPlayer)>('libvlc_media_player_play');

  // Function to initialize libvlc
  static Pointer<Void> newInstance() {
    final args = calloc<Pointer<Utf8>>(0); // Empty arguments (no arguments needed)
    final instance = _libvlc_new(0, args);
    calloc.free(args);
    return instance;
  }

  // Function to create media from a URL
  static Pointer<Void> mediaNewLocation(Pointer<Void> instance, String url) {
    final urlPointer = url.toNativeUtf8();
    final media = _libvlc_media_new_location(instance, urlPointer);
    calloc.free(urlPointer);
    return media;
  }

  // Function to create a media player from media
  static Pointer<Void> mediaPlayerNewFromMedia(Pointer<Void> media) {
    return _libvlc_media_player_new_from_media(media);
  }

  // Function to play the media player
  static int mediaPlayerPlay(Pointer<Void> mediaPlayer) {
    return _libvlc_media_player_play(mediaPlayer);
  }
}
