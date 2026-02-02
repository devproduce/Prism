import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/theme/text_styles.dart';
import 'package:prism/providers/local_gallery_provider.dart';
import 'package:prism/widgets/album_card.dart';
import 'package:prism/screens/local_album_view_screen.dart';

class AllAlbumsScreen extends StatelessWidget {
  const AllAlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: PrismColors.white),
        title: Text("All Albums", style: PrismTextStyles.h3),
      ),
      body: Consumer<LocalGalleryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: PrismColors.prismYellow),
            );
          }

          final albums = provider.albums;
          final screenWidth = MediaQuery.of(context).size.width;
          final crossAxisCount = screenWidth < 600 ? 2 : 3;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return AlbumCard(
                title: album.name,
                assetCount: album.assetCount,
                coverAsset: album.coverAsset,
                width: double.infinity,
                height: double.infinity,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LocalAlbumViewScreen(
                        album: album.album,
                        albumName: album.name,
                        assetCount: album.assetCount,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
