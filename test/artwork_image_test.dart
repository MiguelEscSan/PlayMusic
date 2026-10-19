import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koda/shared/widgets/artwork_image.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('una ruta local se pinta con Image.file', (tester) async {
    await tester.pumpWidget(_wrap(const ArtworkImage(url: '/data/cover.jpg')));

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<FileImage>());
    expect((image.image as FileImage).file.path, '/data/cover.jpg');
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('una URL http sigue usando la caché de red', (tester) async {
    await tester.pumpWidget(
      _wrap(const ArtworkImage(url: 'https://example.com/a.jpg')),
    );

    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });
}
