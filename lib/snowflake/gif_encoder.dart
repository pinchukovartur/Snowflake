import 'dart:typed_data';

/// Encodes [frames] (RGBA, [width] × [height] each, opaque) as a looping GIF,
/// each frame shown [delay] hundredths of a second.
///
/// One palette for all of them, cut from [frames]' own colours (median cut,
/// 5 bits a channel), with an ordered dither: steady from frame to frame, so
/// what stays still stays the same and each frame after the first holds only
/// the box that changed, with the rest of it left clear. A frame the same as
/// the one before only lengthens it.
Uint8List encodeGif(List<Uint8List> frames, int width, int height, int delay) {
  final palette = _palette(frames);
  final out = BytesBuilder(copy: false);
  out.add('GIF89a'.codeUnits);
  _short(out, width);
  _short(out, height);
  out.add([0xF7, 0, 0]); // A global table of 256 colours.
  out.add(palette.rgb);
  // Loops for ever.
  out.add([0x21, 0xFF, 0x0B, ...'NETSCAPE2.0'.codeUnits, 3, 1, 0, 0, 0]);

  final lzw = _Lzw();
  Uint8List? shown;
  ({int x, int y, int w, int h, Uint8List pixels})? pending;
  var pendingDelay = 0;
  void flush() {
    final f = pending;
    if (f == null) return;
    // Not disposed of (left for the next to draw over), its clear index see-through.
    out.add([0x21, 0xF9, 4, 1 << 2 | 1]);
    _short(out, pendingDelay);
    out.add([_clear, 0]);
    out.addByte(0x2C);
    _short(out, f.x);
    _short(out, f.y);
    _short(out, f.w);
    _short(out, f.h);
    out.addByte(0);
    lzw.encode(out, f.pixels);
  }

  for (final rgba in frames) {
    final idx = palette.index(rgba, width, height);
    final prev = shown;
    if (prev == null) {
      pending = (x: 0, y: 0, w: width, h: height, pixels: idx);
    } else {
      // The box round what changed.
      var x0 = width, y0 = height, x1 = -1, y1 = -1;
      for (var y = 0, i = 0; y < height; y++) {
        for (var x = 0; x < width; x++, i++) {
          if (idx[i] == prev[i]) continue;
          if (x < x0) x0 = x;
          if (x > x1) x1 = x;
          if (y < y0) y0 = y;
          y1 = y;
        }
      }
      if (x1 < 0) {
        pendingDelay += delay;
        continue;
      }
      flush();
      final w = x1 - x0 + 1, h = y1 - y0 + 1;
      final box = Uint8List(w * h);
      for (var y = 0, j = 0; y < h; y++) {
        for (var x = 0, i = (y0 + y) * width + x0; x < w; x++, i++, j++) {
          box[j] = idx[i] == prev[i] ? _clear : idx[i];
        }
      }
      pending = (x: x0, y: y0, w: w, h: h, pixels: box);
      pendingDelay = 0;
    }
    pendingDelay += delay;
    shown = idx;
  }
  flush();
  out.addByte(0x3B);
  return out.takeBytes();
}

/// The palette index left see-through: the rest of the 256 are colours.
const _clear = 255;

void _short(BytesBuilder out, int v) => out.add([v & 0xFF, v >> 8 & 0xFF]);

/// The ordered dither's 4 × 4 thresholds, as offsets of up to half a palette
/// step (8 levels of 256, at 5 bits) either way.
final _bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map((v) => (v - 7.5) * 8 / 16).toList();

class _Palette {
  _Palette(this.colors) : rgb = Uint8List(256 * 3) {
    for (var i = 0; i < colors.length; i++) {
      rgb.setRange(i * 3, i * 3 + 3, colors[i]);
    }
  }

  final List<List<int>> colors;

  /// The table as the GIF holds it, its clear index black.
  final Uint8List rgb;

  /// The nearest colour to each 5-bit one, found as first needed.
  final _nearest = Int16List(1 << 15)..fillRange(0, 1 << 15, -1);

  Uint8List index(Uint8List rgba, int width, int height) {
    final idx = Uint8List(width * height);
    for (var y = 0, i = 0; y < height; y++) {
      for (var x = 0; x < width; x++, i++) {
        final d = _bayer[(y & 3) << 2 | x & 3];
        int q(int c) => (c + d).round().clamp(0, 255) >> 3;
        final key = q(rgba[i * 4]) << 10 | q(rgba[i * 4 + 1]) << 5 | q(rgba[i * 4 + 2]);
        var n = _nearest[key];
        if (n < 0) n = _nearest[key] = _closest(key);
        idx[i] = n;
      }
    }
    return idx;
  }

  int _closest(int key) {
    final r = (key >> 10) << 3 | 4, g = (key >> 5 & 31) << 3 | 4, b = (key & 31) << 3 | 4;
    var best = 0, bestD = 1 << 30;
    for (var i = 0; i < colors.length; i++) {
      final c = colors[i];
      final dr = c[0] - r, dg = c[1] - g, db = c[2] - b;
      final d = dr * dr + dg * dg + db * db;
      if (d < bestD) {
        best = i;
        bestD = d;
      }
    }
    return best;
  }
}

/// Up to 255 colours for [frames] (every fourth pixel of every fourth frame
/// counted): the 5-bit colours split by median cut, each box its colours'
/// average.
_Palette _palette(List<Uint8List> frames) {
  final counts = Int32List(1 << 15);
  for (var f = 0; f < frames.length; f += 4) {
    final rgba = frames[f];
    for (var i = 0; i < rgba.length; i += 16) {
      counts[rgba[i] >> 3 << 10 | rgba[i + 1] >> 3 << 5 | rgba[i + 2] >> 3]++;
    }
  }
  final keys = [for (var k = 0; k < counts.length; k++) if (counts[k] > 0) k];
  int channel(int key, int c) => key >> (10 - 5 * c) & 31;
  var boxes = [keys];
  while (boxes.length < _clear) {
    // Splits the box widest along any channel, at its median by count.
    var at = -1, widest = 0, along = 0;
    for (var b = 0; b < boxes.length; b++) {
      if (boxes[b].length < 2) continue;
      for (var c = 0; c < 3; c++) {
        var lo = 31, hi = 0;
        for (final k in boxes[b]) {
          final v = channel(k, c);
          if (v < lo) lo = v;
          if (v > hi) hi = v;
        }
        if (hi - lo > widest) {
          at = b;
          widest = hi - lo;
          along = c;
        }
      }
    }
    if (at < 0) break;
    final box = boxes[at]..sort((a, b) => channel(a, along) - channel(b, along));
    final total = box.fold(0, (s, k) => s + counts[k]);
    var half = 0, cut = 0;
    while (cut < box.length - 1 && (half += counts[box[cut]]) < total / 2) {
      cut++;
    }
    cut = cut.clamp(0, box.length - 2) + 1;
    boxes = [...boxes.take(at), box.sublist(0, cut), box.sublist(cut), ...boxes.skip(at + 1)];
  }
  return _Palette([
    for (final box in boxes)
      if (box.isNotEmpty)
        () {
          var n = 0, r = 0, g = 0, b = 0;
          for (final k in box) {
            final w = counts[k];
            n += w;
            r += w * (channel(k, 0) << 3 | 4);
            g += w * (channel(k, 1) << 3 | 4);
            b += w * (channel(k, 2) << 3 | 4);
          }
          return [r ~/ n, g ~/ n, b ~/ n];
        }(),
  ]);
}

/// GIF's LZW at 8 bits a symbol, its codes packed into sub-blocks.
class _Lzw {
  /// The code for each (prefix code, symbol), valid while its stamp is the
  /// current table's: a fresh table without clearing the lot.
  final _codes = Int32List(4096 * 256);
  final _stamps = Int32List(4096 * 256);
  var _table = 0;

  void encode(BytesBuilder out, Uint8List pixels) {
    const minSize = 8, clearCode = 1 << minSize, end = clearCode + 1;
    final bytes = BytesBuilder(copy: false);
    var acc = 0, bits = 0, size = minSize + 1, next = end + 1;
    void emit(int code) {
      acc |= code << bits;
      bits += size;
      while (bits >= 8) {
        bytes.addByte(acc & 0xFF);
        acc >>= 8;
        bits -= 8;
      }
    }

    _table++;
    emit(clearCode);
    var cur = pixels[0];
    for (var i = 1; i < pixels.length; i++) {
      final k = pixels[i], key = cur << 8 | k;
      if (_stamps[key] == _table) {
        cur = _codes[key];
        continue;
      }
      emit(cur);
      if (next == 4096) {
        emit(clearCode);
        next = end + 1;
        size = minSize + 1;
        _table++;
      } else {
        if (next >= 1 << size) size++;
        _codes[key] = next++;
        _stamps[key] = _table;
      }
      cur = k;
    }
    emit(cur);
    emit(end);
    if (bits > 0) bytes.addByte(acc & 0xFF);

    out.addByte(minSize);
    final data = bytes.takeBytes();
    for (var i = 0; i < data.length; i += 255) {
      final n = data.length - i < 255 ? data.length - i : 255;
      out.addByte(n);
      out.add(Uint8List.sublistView(data, i, i + n));
    }
    out.addByte(0);
  }
}
