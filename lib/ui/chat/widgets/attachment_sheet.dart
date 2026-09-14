import 'package:flutter/cupertino.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/tg_icons.dart';
import '../../../core/tg_theme.dart';
import '../../../l10n/app_localizations.dart';

/// The attach sheet, the way Messages and Telegram do it: the most recent
/// photos first, so the common case is one tap, with the rest as plain rows.
class AttachmentSheet extends StatefulWidget {
  const AttachmentSheet({
    super.key,
    required this.onPickedAsset,
    required this.onGallery,
    required this.onCamera,
    required this.onFile,
    required this.onLocation,
  });

  /// A photo chosen straight from the strip, already resolved to a file path.
  final ValueChanged<String> onPickedAsset;

  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onFile;
  final VoidCallback onLocation;

  @override
  State<AttachmentSheet> createState() => _AttachmentSheetState();
}

class _AttachmentSheetState extends State<AttachmentSheet> {
  List<AssetEntity>? _recent;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    // A refused gallery permission is not an error: the sheet simply shows its
    // rows, and the system picker can still be opened from them.
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      if (mounted) setState(() => _denied = true);
      return;
    }

    final assets = await PhotoManager.getAssetListPaged(
      page: 0,
      pageCount: 24,
      type: RequestType.image,
    );
    if (mounted) setState(() => _recent = assets);
  }

  Future<void> _send(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null || !mounted) return;
    widget.onPickedAsset(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 6),
          Text(l10n.send, style: TgText.rowTitle(context)),
          const SizedBox(height: 12),
          if (!_denied) _RecentStrip(assets: _recent, onTap: _send),
          const SizedBox(height: 8),
          CupertinoListSection.insetGrouped(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            children: [
              CupertinoListTile.notched(
                leading: const Icon(TgIcons.media),
                title: Text(l10n.cameraRoll),
                subtitle: Text(l10n.chooseFromGallery),
                trailing: const CupertinoListTileChevron(),
                onTap: widget.onGallery,
              ),
              CupertinoListTile.notched(
                leading: const Icon(TgIcons.camera),
                title: Text(l10n.camera),
                trailing: const CupertinoListTileChevron(),
                onTap: widget.onCamera,
              ),
              CupertinoListTile.notched(
                leading: const Icon(TgIcons.document),
                title: Text(l10n.documents),
                subtitle: Text(l10n.browseFiles),
                trailing: const CupertinoListTileChevron(),
                onTap: widget.onFile,
              ),
              CupertinoListTile.notched(
                leading: const Icon(TgIcons.location),
                title: Text(l10n.location),
                trailing: const CupertinoListTileChevron(),
                onTap: widget.onLocation,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal strip of recent photos.
class _RecentStrip extends StatelessWidget {
  const _RecentStrip({required this.assets, required this.onTap});

  final List<AssetEntity>? assets;
  final ValueChanged<AssetEntity> onTap;

  @override
  Widget build(BuildContext context) {
    if (assets == null) {
      return const SizedBox(
        height: 96,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (assets!.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: assets!.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final asset = assets![index];
          return GestureDetector(
            onTap: () => onTap(asset),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 78,
                height: 96,
                child: _Thumbnail(asset: asset),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.asset});

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: asset.thumbnailDataWithSize(const ThumbnailSize.square(240)),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return ColoredBox(
            color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
            child: const SizedBox.expand(),
          );
        }
        return Image.memory(data, fit: BoxFit.cover);
      },
    );
  }
}
