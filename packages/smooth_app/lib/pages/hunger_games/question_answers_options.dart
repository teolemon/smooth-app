import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:openfoodfacts/model/Insight.dart';
import 'package:openfoodfacts/model/RobotoffQuestion.dart';
import 'package:smooth_app/generic_lib/design_constants.dart';

const Color _yesBackground = Colors.lightGreen;
const Color _noBackground = Colors.redAccent;
const Color _yesNoTextColor = Colors.white;

/// Display of the typical Yes / No / Maybe options for Robotoff
class QuestionAnswersOptions extends StatelessWidget {
  const QuestionAnswersOptions(
    this.question, {
    Key? key,
    required this.onAnswer,
  }) : super(key: key);

  final RobotoffQuestion question;
  final Function(InsightAnnotation) onAnswer;

  @override
  Widget build(BuildContext context) {
    final double yesNoHeight = MediaQuery.of(context).size.width / (3 * 1.25);

    return Expanded(
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: yesNoHeight,
                  child: _buildAnswerButton(
                    context,
                    insightAnnotation: InsightAnnotation.NO,
                    backgroundColor: _noBackground,
                    contentColor: _yesNoTextColor,
                  ),
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: yesNoHeight,
                  child: _buildAnswerButton(
                    context,
                    insightAnnotation: InsightAnnotation.YES,
                    backgroundColor: _yesBackground,
                    contentColor: _yesNoTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SMALL_SPACE),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _buildAnswerButton(
                context,
                insightAnnotation: InsightAnnotation.MAYBE,
                backgroundColor: const Color(0xFFFFEFB7),
                contentColor: Colors.black,
                textButton: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerButton(
    BuildContext context, {
    required InsightAnnotation insightAnnotation,
    required Color backgroundColor,
    required Color contentColor,
    bool textButton = false,
    EdgeInsets padding = const EdgeInsets.all(VERY_SMALL_SPACE),
  }) {
    final AppLocalizations appLocalizations = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    String buttonText;
    IconData iconData;
    switch (insightAnnotation) {
      case InsightAnnotation.YES:
        buttonText = appLocalizations.yes;
        iconData = Icons.check;
        break;
      case InsightAnnotation.NO:
        buttonText = appLocalizations.no;
        iconData = Icons.clear;
        break;
      case InsightAnnotation.MAYBE:
        buttonText = appLocalizations.skip;
        iconData = Icons.question_mark;
    }

    return Padding(
      padding: padding,
      child: TextButton.icon(
        onPressed: () => onAnswer(insightAnnotation),
        style: textButton
            ? null
            : ButtonStyle(
                backgroundColor: MaterialStateProperty.all(backgroundColor),
                shape: MaterialStateProperty.all(
                  const RoundedRectangleBorder(
                    borderRadius: ROUNDED_BORDER_RADIUS,
                  ),
                ),
              ),
        icon: Icon(
          iconData,
          color: contentColor,
          size: 36,
        ),
        label: Text(
          buttonText,
          style: theme.textTheme.headline2!.apply(color: contentColor),
        ),
      ),
    );
  }
}
