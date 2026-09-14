# Native TDLib libraries

Drop `libtdjson.so`, built for each ABI, into the matching folder here:

```
jniLibs/arm64-v8a/libtdjson.so
jniLibs/armeabi-v7a/libtdjson.so
jniLibs/x86_64/libtdjson.so
```

Build instructions: https://tdlib.github.io/td/build.html

Gradle packages whatever it finds here into the APK, and
`lib/data/tdlib/tdlib_ffi.dart` opens it with `DynamicLibrary.open`. When the
library is absent the app runs the demo backend instead.
