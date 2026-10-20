import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'strings.dart';

/// A message with a "Retry" button, for a screen that could not load.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: Text(S.of(context).retry)),
          ]),
        ),
      );
}

/// "Label   value  [copy]", for the transfer details.
class CopyRow extends StatelessWidget {
  const CopyRow({super.key, required this.label, required this.value, this.copyText, this.emphasis = false});

  final String label;
  final String value;
  final String? copyText;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final style = emphasis ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: TextStyle(color: Theme.of(context).hintColor))),
        Expanded(child: SelectableText(value, style: style)),
        IconButton(
          icon: const Icon(Icons.copy, size: 20),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: copyText ?? value));
            showMessage(context, '${S.of(context).copied}: ${copyText ?? value}');
          },
        ),
      ]),
    );
  }
}

/// "Label: value" in a details card.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Theme.of(context).hintColor))),
          Expanded(child: Text(value)),
        ]),
      );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> openLink(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
