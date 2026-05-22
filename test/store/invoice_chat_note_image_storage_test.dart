import 'package:app_taxi_invoice/src/store/invoice_chat_note_image_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('note image round trips drawing strokes', () {
    final image = InvoiceChatNoteImage(
      id: 'note-1',
      base64: 'abc123',
      mimeType: 'image/jpeg',
      name: 'biljeska.jpg',
      strokes: [
        InvoiceChatNoteStroke(
          colorValue: 0xCCFFB300,
          width: 9,
          points: const [
            InvoiceChatNotePoint(x: 0.1, y: 0.2),
            InvoiceChatNotePoint(x: 0.7, y: 0.8),
          ],
        ),
      ],
    );

    final parsed = InvoiceChatNoteImage.fromJson(image.toJson());

    expect(parsed.strokes.single.points.last.x, 0.7);
  });

  test('note image round trips drawing board json', () {
    final image = InvoiceChatNoteImage(
      id: 'note-1',
      base64: 'abc123',
      mimeType: 'image/jpeg',
      name: 'biljeska.jpg',
      drawingJson: [
        {
          'type': 'SimpleLine',
          'minPointDistance': 3.0,
          'useBezierCurve': true,
          'points': [
            {'dx': 12.0, 'dy': 18.0},
            {'dx': 42.0, 'dy': 64.0},
          ],
          'paint': {
            'blendMode': 3,
            'color': 0xCCFFB300,
            'filterQuality': 3,
            'invertColors': false,
            'isAntiAlias': true,
            'strokeCap': 1,
            'strokeJoin': 1,
            'strokeWidth': 9.0,
            'style': 1,
          },
        },
      ],
    );

    final parsed = InvoiceChatNoteImage.fromJson(image.toJson());

    expect(parsed.drawingJson.single['type'], 'SimpleLine');
    expect(parsed.drawingJson.single['points'], hasLength(2));
  });
}
