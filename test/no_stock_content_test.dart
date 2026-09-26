import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import 'app/new_design.dart';

// ---------------------------------------------------------------------------
// Nothing in the output is a picture of somebody else's door.
//
// This file guards the repository itself rather than any one function. It
// fails the moment a stock image, a downloaded picture or a ready-made model
// is added, whatever it is called and wherever it is put.
// ---------------------------------------------------------------------------

/// Everything under [where], as paths relative to the package root.
List<File> filesUnder(String where, {String extension = '.dart'}) {
  final directory = Directory(where);
  if (!directory.existsSync()) return const [];
  return [
    for (final entry in directory.listSync(recursive: true))
      if (entry is File && entry.path.endsWith(extension)) entry,
  ];
}

void main() {
  group('the application ships no pictures of anything', () {
    test('the only bundled assets are typefaces', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final flutterSection =
          pubspec.substring(pubspec.indexOf('\nflutter:'));

      // An `assets:` block is how a picture would get into the bundle. There
      // is not one, and there is not to be one: everything the user sees is
      // drawn from their own geometry.
      expect(
        RegExp(r'^\s{2}assets:', multiLine: true).hasMatch(flutterSection),
        isFalse,
        reason: 'pubspec.yaml declares a bundled asset. The only thing this '
            'application bundles is the typefaces it draws text with.',
      );
      expect(flutterSection, contains('fonts:'));
    });

    test('nothing under assets/ is an image or a model', () {
      final strays = [
        for (final entry in Directory('assets').existsSync()
            ? Directory('assets').listSync(recursive: true)
            : <FileSystemEntity>[])
          if (entry is File &&
              !entry.path.endsWith('.ttf') &&
              !entry.path.endsWith('.otf') &&
              !entry.path.endsWith('.txt'))
            entry.path,
      ];
      expect(strays, isEmpty,
          reason: 'assets/ holds typefaces and their licence, nothing else');
    });

    test('no source file loads an image, from anywhere', () {
      // Every way Flutter puts a picture on screen, and every way one could
      // be fetched to put there.
      final forbidden = <String, String>{
        r'Image\.asset': 'a bundled picture',
        r'Image\.network': 'a downloaded picture',
        r'Image\.file': 'a picture from disk',
        r'Image\.memory': 'a picture from bytes',
        r'AssetImage': 'a bundled picture',
        r'NetworkImage': 'a downloaded picture',
        r'FileImage': 'a picture from disk',
        r'MemoryImage': 'a picture from bytes',
        r'ExactAssetImage': 'a bundled picture',
        r'rootBundle': 'something loaded out of the bundle',
        r'decodeImageFromList': 'a decoded picture',
        r'instantiateImageCodec': 'a decoded picture',
        r'package:http': 'a network request',
        r'HttpClient': 'a network request',
        r'WebSocket': 'a network request',
      };

      final offences = <String>[];
      for (final file in filesUnder('lib')) {
        final source = file.readAsStringSync();
        for (final entry in forbidden.entries) {
          if (RegExp(entry.key).hasMatch(source)) {
            offences.add('${file.path}: ${entry.value} (${entry.key})');
          }
        }
      }

      expect(offences, isEmpty,
          reason: 'the design is drawn from its own geometry, never from a '
              'picture:\n${offences.join('\n')}');
    });

    test('no ready-made model file is anywhere in the source', () {
      const modelKinds = [
        '.glb', '.gltf', '.obj', '.fbx', '.stl', '.dae', '.3ds', '.usdz',
      ];
      final strays = <String>[];
      for (final root in ['lib', 'assets', 'web']) {
        if (!Directory(root).existsSync()) continue;
        for (final entry in Directory(root).listSync(recursive: true)) {
          if (entry is! File) continue;
          if (modelKinds.any(entry.path.endsWith)) strays.add(entry.path);
        }
      }
      expect(strays, isEmpty,
          reason: 'the solid is built from the drawing, not loaded');
    });

    test('no picture is bundled with the web build either', () {
      // The launcher icon and the favicon are the application's own mark in
      // a task switcher or a browser tab. Nothing else belongs here, and in
      // particular nothing that could stand in for a design.
      final allowed = {
        'favicon.png',
        'Icon-192.png',
        'Icon-512.png',
        'Icon-maskable-192.png',
        'Icon-maskable-512.png',
      };
      final strays = [
        for (final entry in Directory('web').listSync(recursive: true))
          if (entry is File &&
              RegExp(r'\.(png|jpe?g|gif|webp|svg|bmp)$')
                  .hasMatch(entry.path) &&
              !allowed.contains(entry.uri.pathSegments.last))
            entry.path,
      ];
      expect(strays, isEmpty);
    });
  });

  group('every part of the output traces back to the drawing', () {
    test('an empty design produces an empty model, not a stand-in', () {
      final at = DateTime(2026);
      final mesh = MeshBuilder.build(Design(
        id: 'd',
        name: 'x',
        kind: DesignKind.door,
        createdAt: at,
        updatedAt: at,
      ));
      expect(mesh.isEmpty, isTrue,
          reason: 'nothing drawn means nothing to show');
    });

    test('every face in the model belongs to a part of the drawing', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(workspaceProvider.notifier)
        ..startDesign(DesignKind.window)
        ..addStroke(
          const [
            StrokeSample(Vec2(0, 0)),
            StrokeSample(Vec2(1700, 0)),
            StrokeSample(Vec2(1700, 1300)),
            StrokeSample(Vec2(0, 1300)),
            StrokeSample(Vec2(0, 0)),
          ],
          tool: Tool.pen,
        )
        ..addStroke(
          const [StrokeSample(Vec2(430, 0)), StrokeSample(Vec2(430, 1300))],
          tool: Tool.pen,
        )
        ..readDrawing();

      final design = container.read(workspaceProvider).design;
      final known = {
        design.frame!.id,
        for (final d in design.dividers) d.id,
        for (final s in design.sections) s.id,
      };

      final mesh = MeshBuilder.build(design);
      expect(mesh.facets, isNotEmpty);
      for (final facet in mesh.facets) {
        expect(known, contains(facet.elementId),
            reason: 'a face in the model belongs to nothing in the drawing');
      }
    });
  });

  testWidgets('with nothing drawn, the 3D view says so', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late WidgetRef captured;
    await tester.pumpWidget(ProviderScope(
      child: Consumer(builder: (context, ref, _) {
        captured = ref;
        return const ProFrameApp();
      }),
    ));
    await tester.pumpAndSettle();
    await toTheCategories(tester);
    await chooseDesign(tester, 'WINDOW');

    captured.read(workspaceProvider.notifier).showView(WorkspaceView.model);
    await tester.pumpAndSettle();

    expect(find.text('Nothing to show yet'), findsOneWidget);
    expect(
      find.textContaining('there is no stock model to show'),
      findsOneWidget,
    );
    // And there is no picture on screen standing in for one.
    expect(find.byType(Image), findsNothing);
  });
}
