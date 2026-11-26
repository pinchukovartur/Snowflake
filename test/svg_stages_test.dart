import 'package:flutter_test/flutter_test.dart';
import 'package:snowflake/snowflake/svg_flakes.dart';

/// A wedge template with two holes, each in a step of its own ("1", and
/// "_2" as an export may name it).
const _steps = '''
<svg width="1000" height="1100" viewBox="0 0 1000 1100" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M500 1050L250 100C400 60 600 60 750 100L500 1050Z" fill="#EAF4FF"/>
<g id="1"><rect x="470" y="300" width="60" height="60" fill="#D9D9D9"/></g>
<g id="_2"><rect x="470" y="600" width="60" height="60" fill="#D9D9D9"/></g>
</svg>
''';

void main() {
  test('a drawing in numbered groups is cut step by step', () {
    final stages = flakeStagesFromSvg(_steps);
    expect(stages, hasLength(2));
    // The last step is the whole flake.
    expect(stages.last, flakeFromSvg(_steps));
    // The first has only the first hole: less cut away than the whole.
    expect(stages.first, isNot(stages.last));
  });

  test('a white-parts drawing marks what it draws, not its template', () {
    const svg = '''
<svg width="1000" height="1100" viewBox="0 0 1000 1100" fill="none" xmlns="http://www.w3.org/2000/svg">
<g id="template"><path d="M500 1050L250 100C400 60 600 60 750 100L500 1050Z" fill="#496C93"/></g>
<rect x="470" y="300" width="60" height="60" fill="white"/>
</svg>
''';
    final white = whitePartsFromSvg(svg);
    // (500, 330) in the drawing: the wedge's middle, .72 out.
    expect(white.contains(const Offset(0, -.72)), isTrue);
    expect(white.contains(const Offset(0, -.3)), isFalse);
  });

  test('a drawing with no numbered groups has no steps', () {
    expect(flakeStagesFromSvg(_steps.replaceAll('id="1"', 'id="a"').replaceAll('id="_2"', 'id="b"')), isEmpty);
  });
}
