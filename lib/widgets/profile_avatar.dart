import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';

/// Changing the profile photo — shared by the employee and admin profile screens and the full-screen
/// preview, so all three behave identically and show the same "uploading" state.
class ProfilePhotoActions {
  static final _picker = ImagePicker();

  /// True while a photo is being uploaded (drives the spinner on the avatar and in the preview).
  static final ValueNotifier<bool> uploading = ValueNotifier<bool>(false);

  /// "Take a photo" / "Choose from gallery" — then pick and upload. Returns true if the photo changed.
  static Future<bool> changePhoto(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primaryDark),
              title: const Text('Take a photo'),
              subtitle: const Text('Use the camera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primaryDark),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return false;
    return _pickAndUpload(context, source);
  }

  static Future<bool> _pickAndUpload(BuildContext context, ImageSource source) async {
    final session = context.read<Session>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    void say(String message, {bool error = false}) {
      messenger?.showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
      ));
    }

    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        // Selfie camera first for a profile photo; the user can still flip it in the camera app.
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1024,
        imageQuality: 85,
      );
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied' || e.code == 'photo_access_denied') {
        say('Camera/photo access is blocked for this app. Allow it in Settings > Apps > Permissions.', error: true);
      } else {
        say('Could not open ${source == ImageSource.camera ? 'the camera' : 'the gallery'}.', error: true);
      }
      return false;
    } catch (_) {
      say('Could not open ${source == ImageSource.camera ? 'the camera' : 'the gallery'}.', error: true);
      return false;
    }
    if (picked == null) return false; // cancelled

    uploading.value = true;
    try {
      final bytes = await picked.readAsBytes();
      final photoUrl = await ProfileService().uploadPhoto(bytes, picked.name);
      // The server keeps the same URL for this user's photo across re-uploads (one file per user, no
      // orphaned files), so Flutter's in-memory ImageCache — keyed strictly by URL — would keep showing
      // the old bytes without a cache-busting query param forcing a fresh fetch.
      await session.updatePhotoUrl('$photoUrl?v=${DateTime.now().millisecondsSinceEpoch}');
      say('Photo updated.');
      return true;
    } on ApiException catch (e) {
      say(e.message, error: true);
      return false;
    } catch (e) {
      say('Could not upload the photo. Please try again.', error: true);
      return false;
    } finally {
      uploading.value = false;
    }
  }
}

/// The signed-in user's round photo, no tap behaviour. Falls back to the initial when there is no photo, or
/// when the photo can't be loaded (file deleted, server unreachable) — never a blank circle.
class SessionAvatar extends StatefulWidget {
  const SessionAvatar({super.key, required this.name, this.radius = 36, this.busy = false});

  final String name;
  final double radius;

  /// Show a spinner instead of the photo/initial (an upload is in progress).
  final bool busy;

  @override
  State<SessionAvatar> createState() => _SessionAvatarState();
}

class _SessionAvatarState extends State<SessionAvatar> {
  /// A photo URL that failed to load. We try again as soon as the URL changes (e.g. after a new upload).
  String? _failedUrl;

  @override
  Widget build(BuildContext context) {
    final radius = widget.radius;
    final photoUrl = resolvePhotoUrl(context.watch<Session>().photoUrl);
    final showPhoto = photoUrl != null && photoUrl != _failedUrl;
    final initial = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      backgroundImage: showPhoto ? NetworkImage(photoUrl) : null,
      onBackgroundImageError: showPhoto
          ? (_, _) {
              // Fires while the image stream is resolving, so flip the state after the frame.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _failedUrl != photoUrl) setState(() => _failedUrl = photoUrl);
              });
            }
          : null,
      child: widget.busy
          ? SizedBox(width: radius * 0.6, height: radius * 0.6, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
          : !showPhoto
              ? Text(initial, style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w700, color: AppColors.primaryDark))
              : null,
    );
  }
}

/// The round profile photo. Tap the photo = see it full screen (pinch to zoom); tap the little camera badge
/// = change it (camera or gallery).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.name, this.radius = 36});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhotoPreviewScreen(name: name))),
            child: ValueListenableBuilder<bool>(
              valueListenable: ProfilePhotoActions.uploading,
              builder: (context, busy, _) => Hero(
                tag: 'profile-photo',
                child: SessionAvatar(name: name, radius: radius, busy: busy),
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: () => ProfilePhotoActions.changePhoto(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2))),
                child: Icon(Icons.camera_alt, size: radius * 0.42, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen photo: pinch/double-tap to zoom, drag to pan, and a "Change photo" action.
class PhotoPreviewScreen extends StatelessWidget {
  const PhotoPreviewScreen({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final photoUrl = resolvePhotoUrl(session.photoUrl);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: photoUrl == null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_circle_outlined, size: 120, color: Colors.white.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text('No profile photo yet', style: TextStyle(color: Colors.white70)),
                      ],
                    )
                  : Hero(
                      tag: 'profile-photo',
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 5,
                        child: Image.network(
                          photoUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) =>
                              progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
                          errorBuilder: (context, error, stack) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
                        ),
                      ),
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: ValueListenableBuilder<bool>(
                valueListenable: ProfilePhotoActions.uploading,
                builder: (context, busy, _) => ElevatedButton.icon(
                  onPressed: busy ? null : () => ProfilePhotoActions.changePhoto(context),
                  icon: busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.photo_camera_outlined),
                  label: Text(photoUrl == null ? 'Add photo' : 'Change photo'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
