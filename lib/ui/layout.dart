import 'package:flutter/widgets.dart';

/// True when the user's text size is so large that rows should stack
/// (reflow to 200 %: cards stack, prices wrap under times, nothing is cut).
bool swIsLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.5;
