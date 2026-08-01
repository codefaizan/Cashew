import 'package:flutter/material.dart';
import 'package:budget/widgets/openBottomSheet.dart';
import 'package:budget/pages/ai_assist/ai_assist_page.dart';

void openAiAssistSheet(BuildContext context) {
  openBottomSheet(
    context,
    SizedBox.shrink(),
    resizeForKeyboard: true,
    fullSnap: true,
    customBuilder: (context, scrollController, sheetState) {
      return AiAssistChat(scrollController: scrollController);
    },
  );
}
