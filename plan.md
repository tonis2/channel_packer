# Channel Packer — Flutter WASM node-editor app

## Context

We are building a web app (Flutter compiled to **WASM**) that replicates the core of the
downloaded reference site at `/home/tonis/Documents/web/channel_packer/`:

- **Channel packing** — combine grayscale maps (AO, Roughness, Metallic, …) into one RGBA image.
- **Depth → Normal map** — convert a height image to a normal map with a strength control.

Unlike the reference (a fixed-form React UI), this app is driven by a **node editor**: the user
adds Image nodes, wires them into a Packer or NormalMap node, previews the result inside the node,
and downloads the output PNG. The app is built on the same `easy_nodes` package the sibling project
`/home/tonis/Documents/flutter/sdui/` already uses, so we reuse a proven node-graph foundation.

Target dir `/home/tonis/Documents/flutter/channel_packer/` already contains a fresh Flutter project
(default counter template, web enabled, Flutter 3.41.6 — WASM available via `flutter build web --wasm`).

### Decisions locked with the user
1. **Packer inputs** = 4 fixed labeled ports: `AO`, `Roughness`, `Metallic`, `Alpha`.
2. **Packer output** = per-channel remappable: 4 dropdowns (R/G/B/A) each choose which input feeds that
   output channel. Defaults: R←AO, G←Roughness, B←Metallic, A←none(white). (R=AO,G=Rough,B=Metal is
   glTF/ORM compatible.)
3. **Scope** includes node-graph **save/load** to JSON. Image nodes embed their bytes (base64) so a
   reloaded graph fully restores without re-picking.

## How `easy_nodes` works (verified, v1.0.4 in pub-cache)

- Subclass `Node`; override `String get typeName`, `Future<dynamic> run(ctx, cache)`, `Widget build(ctx)`.
- **Pull execution**: inside `run()`, `NodeControls.of(ctx)!` → controller; `controller.incomingNodes(this, inputIndex)`
  returns upstream `List<Node>`; `await up.first.execute(ctx, cache)` returns that node's `run()` value
  (auto-cached by uuid, cycle-detected). Call `controller.requestUpdate()` to repaint after computing.
- `NodeCanvas(controller, zoom, backgroundColor, lineColor)` renders graph; pan/zoom/drag built in.
- Controller: `registerNodeType(NodeTypeMetadata(typeName, displayName, description, icon, factory))`,
  `addNode(node, offset)`, `toJson()`, `fromJson(json, ctx)`, `clear()`, `executeAllEndpoints(ctx)`.
- **No built-in add-node UI** — we build our own menu from registered types.

## Dependencies (pubspec.yaml)
```yaml
  easy_nodes: ^1.0.4
  image: ^4.8.0         # pure-Dart decode/encode/resize/pixel access — wasm-safe
  file_picker: ^10.3.8  # web: result.files.first.bytes (Uint8List); never use .path on web
  web: ^1.1.0           # wasm-safe Blob/anchor download (NOT dart:html)
```
Do **not** add Hive/dart:io/dart:html — they break the wasm build.

## File structure (lib/)
```
main.dart                     # MaterialApp (dark) wrapped in Inherited(notifier: AppState())
state.dart                    # AppState extends ChangeNotifier + Inherited(InheritedNotifier);
                              #   holds NodeEditorController; registers the 3 node types; menuTypes list
pages/editor_page.dart        # NodeControls > Scaffold: NodeCanvas + FAB column (add/run/save/load)
widgets/add_node_menu.dart    # PopupMenuButton from state.menuTypes -> controller.addNode(node, center)
widgets/node_preview.dart     # reusable: Image.memory(previewBytes) + "Download PNG" button
core/image_payload.dart       # ImagePayload { img.Image image; Uint8List get png (lazy encodePng) }
core/image_ops.dart           # readGray, commonSize, resizeTo, packRGBA(...), sobelNormal(...)
core/download_helper.dart     # downloadBytes(Uint8List, filename) via package:web Blob+anchor
core/graph_io.dart            # saveGraph(controller), loadGraph(controller, ctx)
nodes/image_node.dart         # ImageNode
nodes/packer_node.dart        # PackerNode
nodes/normal_map_node.dart    # NormalMapNode
```

## Core logic

**`core/image_payload.dart`** — value flowing between nodes; every `run()` returns `ImagePayload`.
```dart
class ImagePayload { final img.Image image; Uint8List? _png;
  Uint8List get png => _png ??= Uint8List.fromList(img.encodePng(image));
  ImagePayload(this.image); }
```

**`core/image_ops.dart`** (pure functions, no BuildContext):
- `int readGray(img.Pixel p)` → `(p.luminanceNormalized*255).round().clamp(0,255)`.
- `commonSize(List<img.Image?>)` → max w/h of non-null inputs.
- `packRGBA({img.Image? r,g,b,a, defaults})` → resize each provided channel to common size;
  `img.Image(width,height,numChannels:4)`; per pixel `setPixelRgba(x,y, gray(r)|0, gray(g)|0, gray(b)|0, gray(a)|255)`.
- `sobelNormal(img.Image h, {strength=2.0, invertG=false})` (reference algorithm):
  grayscale; 3×3 clamped neighborhood; `dX=(tr+2r+br)-(tl+2l+bl)`, `dY=(bl+2b+br)-(tl+2t+tr)`;
  `nx=-dX*strength/255; ny=-dY*strength/255; nz=1`; normalize; encode `*0.5+0.5`→0..255; if invertG flip G; A=255.

**`core/download_helper.dart`** — wasm-safe, used by every Download button + graph save:
```dart
import 'dart:js_interop'; import 'package:web/web.dart' as web;
void downloadBytes(Uint8List bytes, String filename) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type:'application/octet-stream'));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()..href=url..download=filename;
  web.document.body!.appendChild(a); a.click(); a.remove(); web.URL.revokeObjectURL(url);
}
```

**`core/graph_io.dart`**:
- `saveGraph` → `downloadBytes(utf8.encode(jsonEncode(controller.toJson())), 'graph.json')`.
- `loadGraph` → file_picker `pickFiles(type:custom, allowedExtensions:['json'])`; `bytes!` → jsonDecode →
  `controller.clear(); await controller.fromJson(json, ctx); controller.requestUpdate();`.

## The three nodes (all: override typeName/run/build; toJson adds settings; fromJson restores via Node.fromJson)

**ImageNode** — no inputs, output `Image`. Fields `img.Image? image; Uint8List? bytes`.
`pickImage`: capture controller before await; `pickFiles()`; `bytes=result.files.first.bytes!`;
`image=decodeImage(bytes)`; `requestUpdate()`. `run()` returns `ImagePayload(image!)` (throws if null).
`build()`: tappable thumbnail or "Click to pick" + delete. **toJson embeds `bytes` as base64**; fromJson decodes
it so save/load fully restores.

**PackerNode** — inputs `[AO, Roughness, Metallic, Alpha]`, output `Packed`.
Field `Map<String,int?> sel = {'R':0,'G':1,'B':2,'A':null}` (value=input index or null=none).
`build()`: 4 `DropdownButton<int?>` (items: none/AO/Roughness/Metallic/Alpha) → update sel + requestUpdate;
`NodePreview` + Download PNG (`downloadBytes(payload.png,'packed.png')`).
`run()`: helper `chan(idx)` = `idx==null?null: (incomingNodes(this,idx).firstOrNull?.execute(...) as ImagePayload?).image`;
`out=packRGBA(r:chan(sel['R']),...)`; store preview bytes; requestUpdate; return `ImagePayload(out)`.
toJson/fromJson persist `sel`.

**NormalMapNode** — input `[Height]`, output `Normal`. Fields `double strength=2.0; bool invertG=false`.
`build()`: `Slider(0.1..5.0)` + `Checkbox` + `NodePreview` + Download PNG → each change updates field + requestUpdate.
`run()`: pull `incomingNodes(this,0).first.execute()` → `sobelNormal(img, strength, invertG)`; preview; return payload.
toJson/fromJson persist `strength`, `invertG`.

## UI wiring (editor_page.dart)
`NodeControls(notifier: controller, child: Scaffold(body: NodeCanvas(...), floatingActionButton: Column[...]))`:
- **Add** → AddNodeMenu (PopupMenu from `state.menuTypes`) → `controller.addNode(NodeForType(typeName), canvasCenter)`.
- **Run** → `controller.executeAllEndpoints(ctx)` (cascades the pull from endpoint Packer/NormalMap nodes).
- **Save** → `saveGraph(controller)`;  **Load** → `loadGraph(controller, ctx)`.
- Per-node Download PNG buttons live inside each node `build()`.

## First implementation step
Also write this plan to `/home/tonis/Documents/flutter/channel_packer/plan.md` (the user asked for it there),
then implement files in dependency order: `image_payload` → `image_ops` → `download_helper` → nodes →
`state` → `graph_io` → `add_node_menu`/`node_preview` → `editor_page` → `main`.

## Verification
```
cd /home/tonis/Documents/flutter/channel_packer
flutter pub get
flutter run -d chrome        # dev iteration
flutter build web --wasm     # GATE: confirm wasm compiles (no dart:io/html leak)
```
Manual end-to-end:
1. **Pack** — add 3 ImageNodes + pick grayscale PNGs; add PackerNode; wire to AO/Rough/Metal; set R←AO,G←Rough,B←Metal;
   Run → packed preview → Download → open file, channels correct.
2. **Normal** — ImageNode (height) → NormalMapNode; adjust strength + invert G; Run → bluish normal preview → Download.
3. **Persistence** — Save graph → Load it back (or reload page then Load) → node layout, connections, packer dropdowns,
   normal strength/invertG, and image contents all restored.

## Risks
- **easy_nodes wasm compile** is the gate (pure-Flutter pkg, expected safe; sibling project never built wasm). If it
  fails, the error names the import; our own code avoids io/html. Mitigation only if easy_nodes itself leaks io.
- **Base64 image embedding** inflates graph.json (chosen so save/load actually restores work — user's stated goal).
- **Large textures**: Sobel/pack run on the main isolate; acceptable for v1, isolate offload is a future improvement.
- We must build the **add-node menu** ourselves (easy_nodes ships none).
```
