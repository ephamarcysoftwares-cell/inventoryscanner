// import 'dart:ffi';
// import 'package:ffi/ffi.dart';
//
// typedef _CoInitializeExNative = Int32 Function(Pointer<Void> pvReserved, Uint32 dwCoInit);
// typedef _CoInitializeExDart = int Function(Pointer<Void> pvReserved, int dwCoInit);
//
// typedef _CoCreateInstanceNative = Int32 Function(
//     Pointer guidCLSID,
//     Pointer pUnkOuter,
//     Uint32 dwClsContext,
//     Pointer guidIID,
//     Pointer<Pointer> ppv,
//     );
// typedef _CoCreateInstanceDart = int Function(
//     Pointer guidCLSID,
//     Pointer pUnkOuter,
//     int dwClsContext,
//     Pointer guidIID,
//     Pointer<Pointer> ppv,
//     );
//
// typedef _IUnknownReleaseNative = Int32 Function(Pointer pUnk);
// typedef _IUnknownReleaseDart = int Function(Pointer pUnk);
//
// typedef _ISpVoiceSpeakNative = Int32 Function(Pointer pVoice, Pointer<Utf16> psz, Uint32 dwFlags, Pointer<Uint32> pulStreamNumber);
// typedef _ISpVoiceSpeakDart = int Function(Pointer pVoice, Pointer<Utf16> psz, int dwFlags, Pointer<Uint32> pulStreamNumber);
//
// const CLSCTX_INPROC_SERVER = 0x1;
// const COINIT_APARTMENTTHREADED = 0x2;
//
// final ole32 = DynamicLibrary.open('ole32.dll');
//
// final CoInitializeEx = ole32.lookupFunction<_CoInitializeExNative, _CoInitializeExDart>('CoInitializeEx');
// final CoCreateInstance = ole32.lookupFunction<_CoCreateInstanceNative, _CoCreateInstanceDart>('CoCreateInstance');
// final CoUninitialize = ole32.lookupFunction<Void Function(), void Function()>('CoUninitialize');
//
// class GUID extends Struct {
//   @Uint32()
//   external int Data1;
//
//   @Uint16()
//   external int Data2;
//
//   @Uint16()
//   external int Data3;
//
//   @Array(8)
//   external Array<Uint8> Data4;
//
//   void setFromString(String guid) {
//     final parts = guid.split('-');
//     Data1 = int.parse(parts[0], radix: 16);
//     Data2 = int.parse(parts[1], radix: 16);
//     Data3 = int.parse(parts[2], radix: 16);
//     final data4Bytes = <int>[];
//     for (var i = 0; i < parts[3].length; i += 2) {
//       data4Bytes.add(int.parse(parts[3].substring(i, i + 2), radix: 16));
//     }
//     for (var i = 0; i < parts[4].length; i += 2) {
//       data4Bytes.add(int.parse(parts[4].substring(i, i + 2), radix: 16));
//     }
//     for (var i = 0; i < 8; i++) {
//       Data4[i] = data4Bytes[i];
//     }
//   }
// }
//
// final CLSID_SpVoice = calloc<GUID>();
// final IID_ISpVoice = calloc<GUID>();
//
// class WindowsTTS {
//   Pointer? _voice;
//
//   WindowsTTS() {
//     CLSID_SpVoice.ref.setFromString('96749377-3391-11D2-9EE3-00C04F797396');
//     IID_ISpVoice.ref.setFromString('6C44DF74-72B9-4992-A1EC-EF996E0422D4');
//     _init();
//   }
//
//   void _init() {
//     final hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
//     if (hr != 0) {
//       throw Exception('Failed to initialize COM library. HRESULT: $hr');
//     }
//
//     final voicePtrPtr = calloc<Pointer>();
//     final hrCreate = CoCreateInstance(
//       CLSID_SpVoice,
//       nullptr,
//       CLSCTX_INPROC_SERVER,
//       IID_ISpVoice,
//       voicePtrPtr,
//     );
//
//     if (hrCreate != 0) {
//       CoUninitialize();
//       throw Exception('Failed to create SAPI voice instance. HRESULT: $hrCreate');
//     }
//
//     _voice = voicePtrPtr.value;
//     calloc.free(voicePtrPtr);
//   }
//
//   void speak(String text) {
//     if (_voice == null) return;
//
//     final spVoice = _voice!;
//     final vtable = spVoice.cast<Pointer<Pointer>>().value;
//
//     // Speak method is at vtable index 3 (zero-based)
//     final speakPtr = Pointer<NativeFunction<_ISpVoiceSpeakNative>>.fromAddress(
//       vtable.elementAt(3).value,
//     );
//     final speak = speakPtr.asFunction<_ISpVoiceSpeakDart>();
//
//     final textPtr = text.toNativeUtf16();
//     final hrSpeak = speak(spVoice, textPtr, 0, calloc<Uint32>());
//     calloc.free(textPtr);
//
//     if (hrSpeak != 0) {
//       print('Speak failed with HRESULT: $hrSpeak');
//     }
//   }
//
//   void dispose() {
//     if (_voice != null) {
//       final vtable = _voice!.cast<Pointer<Pointer>>().value;
//       final releasePtr = Pointer<NativeFunction<_IUnknownReleaseNative>>.fromAddress(
//         vtable.elementAt(2).value,
//       );
//       final release = releasePtr.asFunction<_IUnknownReleaseDart>();
//       release(_voice!);
//       _voice = null;
//       CoUninitialize();
//     }
//   }
// }
