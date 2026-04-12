import 'package:budget/widgets/aiAssistantChat.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:flutter/material.dart';

void openAiAssistantSheet(BuildContext context) {
  openBottomSheet(
    context,
    AiAssistantSheet(),
    fullSnap: true,
  );
}

class AiAssistantSheet extends StatelessWidget {
  const AiAssistantSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding:
              const EdgeInsetsDirectional.only(top: 12, start: 20, end: 20),
          child: Row(
            children: [
              Icon(
                Icons.smart_toy_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: 12),
              Expanded(
                child: TextFont(
                  text: 'Cashew AI',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: Icon(Icons.close),
              ),
            ],
          ),
        ),
        Divider(height: 1),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: AiAssistantChat(
            onClose: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      ],
    );
  }
}
