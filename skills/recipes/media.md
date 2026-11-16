# Recipe: images, uploads and permissions

## Problem

A 4000 px photo decoded for a 64 dp thumbnail holds about 64 MB. A 12 MP upload takes minutes on a slow network
and carries the place it was taken in its EXIF. A permission asked at start is refused, and never asked again.

## Rule

- Remote pictures go through `AppImage`: decoded at the size shown, a placeholder, an error state (F15).
- Photos are shrunk on the phone (the long side about 1600 px, quality about 85, EXIF stripped) and checked against
  the server's limits before upload. The upload runs under a total time budget, with an `Idempotency-Key`.
- Permissions go through ONE wrapper in `lib/core/permissions/` that answers granted, denied or permanently
  denied. Ask at the moment the feature needs it, never at start; each one has its reason in
  `AndroidManifest.xml` and `Info.plist` (F13). Tests fake the wrapper.
- Heavy work runs off the UI isolate: `compute` or `Isolate.run`.

## Code

```dart
// lib/core/common/widgets/app_image.dart
    final pixels = (width * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        // Width only: the height follows the picture's own ratio, so nothing is stretched.
        cacheWidth: pixels > 0 ? pixels : null,
```

```dart
// lib/core/common/data/photo_shrinker.dart (not in the starter: copy it with the first upload)
  /// The JPEG to upload, or null when the phone cannot read the file as a picture.
  Future<Uint8List?> shrink(String path) async {
    final size = await _sizeOf(path);
    // The engine cannot read the size of every format (some HEIC files): then the short side is capped.
    final side = size == null ? maxSide : shortSideFor(size.width, size.height);
    try {
      return await FlutterImageCompress.compressWithFile(
        path,
        // Minimums, not maximums: the plugin scales the SHORT side down to them. Both equal, and sized from the
        // long side, they give a long side of maxSide in either orientation.
        minWidth: side,
        minHeight: side,
        quality: quality,
        // keepExif stays false (the default), so the location goes; autoCorrectionAngle turns the pixels upright.
      );
    } on Exception catch (e) {
      _log('compress', e);
      return null;
    }
  }
```

`_sizeOf` reads the size from the file header (`ui.ImageDescriptor.encoded`) without decoding the pixels, and
`shortSideFor` returns `short * maxSide / long`. The repository checks the server's limit before it sends:

```dart
// lib/features/members/data/repositories/members_repository_impl.dart (not in the starter)
  Future<Result<Member>> uploadPhoto(String memberId, String photoPath) async {
    final jpeg = await _shrinker.shrink(photoPath);
    if (jpeg == null || jpeg.length > maxPhotoBytes) {
      return const FailureResult(MemberPhotoRejectedFailure());
    }
    return _guard(
      () async =>
          MemberModel.fromJson(await _remote.uploadPhoto(memberId, jpeg)),
    );
  }
```

The data source sends `MultipartFile.fromBytes(jpeg, ...)` through `ApiClient.upload`, which adds the key and
the two-minute budget (network.md).

```dart
// lib/core/permissions/app_permissions.dart (not in the starter: add permission_handler with the first one)
  Future<PermissionOutcome> request(AppPermission permission) async {
    final status = await _plugin(permission).request();
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return PermissionOutcome.granted;
    }
    // iOS answers permanentlyDenied after the first no, Android 11+ after the second. Restricted (parental
    // controls) cannot be changed from the app either.
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionOutcome.permanentlyDenied;
    }
    return PermissionOutcome.denied;
  }
```

On `permanentlyDenied`, the screen says why it needs it and offers `openSettings()`.

## Traps

- image_picker's `maxWidth` and `imageQuality` re-encode on Android and copy the EXIF tags, GPS included: pick the
  original and shrink it with `PhotoShrinker`.
- flutter_image_compress's `minWidth`/`minHeight` are minimums: 1600 by 1600 leaves a 4:3 photo 2133 px long.
- Android may kill the app while the camera is open: call `ImagePicker().retrieveLostData()` at start, or the
  new photo is lost.
- On Android, a permission's `status` never says "permanently denied"; only `request()` does. Always `request()`.
- iOS ends the app at the first request when `Info.plist` lacks the usage text (`NSCameraUsageDescription`), and
  permission_handler shows no dialog unless `ios/Podfile` turns the permission on (`'PERMISSION_CAMERA=1'`).
- `cacheWidth` alone under `BoxFit.cover` blurs a picture wider than its box (a landscape photo in a square
  avatar): the decode matches the box's width, then cover scales it up. Ask the server for square thumbnails.
- A signed URL changes on every read, so the image cache misses each time: key it by the file's id.
