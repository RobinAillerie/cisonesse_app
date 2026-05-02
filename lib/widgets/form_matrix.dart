// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class FormMatrix extends StatelessWidget {
  final String title;
  final List<String> columns;
  final Map<String, String?> values;
  final void Function(String row, String value) onChanged;
  final bool required;
  final bool showErrors;

  const FormMatrix({
    super.key,
    required this.title,
    required this.columns,
    required this.values,
    required this.onChanged,
    this.required = true,
    this.showErrors = true,
  });

  @override
  Widget build(BuildContext context) {
    final missing = values.values.where((v) => v == null).length;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              required ? "$title *" : title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            if (showErrors && required && missing > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  "Réponses manquantes : $missing",
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(flex: 3, child: SizedBox()),
                ...columns.map(
                  (c) => Expanded(
                    child: Center(
                      child: Text(
                        c,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...values.keys.map((row) {
              return Row(
                children: [
                  Expanded(flex: 3, child: Text(row)),
                  ...columns.map((c) {
                    return Expanded(
                      child: Radio<String>(
                        value: c,
                        groupValue: values[row],
                        onChanged: (v) {
                          if (v != null) onChanged(row, v);
                        },
                      ),
                    );
                  }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}