import 'package:collection/collection.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webapp/api.dart' as A;
import 'package:webapp/base_view.dart';
import 'package:webapp/colors.dart';
import 'package:webapp/components/links.dart';
import 'package:webapp/components/message.dart';
import 'package:webapp/components/presets.dart';
import 'package:webapp/config.dart';
import 'package:webapp/home_model.dart';
import 'package:webapp/utils.dart';

Widget wrapScaffold(Widget widget) {
  return SafeArea(child: Scaffold(body: widget));
}

Widget wrapPadding(Widget widget) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: widget,
  );
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final TextEditingController inputController = TextEditingController();
  final FocusNode inputFocus = FocusNode();

  bool showPipelineInfo = false;

  @override
  void initState() {
    super.initState();

    inputController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    inputController.dispose();
    super.dispose();
  }

  Future<void> Function() launchOrMessage(String address) {
    return () async {
      bool success = false;
      try {
        success = await launchUrl(Uri.parse(address));
      } finally {
        if (!success) {
          showMessage(
            context,
            Message("could not open $address", Status.error),
          );
        }
      }
    };
  }

  @override
  Widget build(BuildContext homeContext) {
    return BaseView<HomeModel>(
      onModelReady: (model) async {
        await model.init(inputController);
      },
      builder: (context, model, child) {
        Future.delayed(
          Duration.zero,
          () {
            while (model.messages.isNotEmpty) {
              final message = model.messages.removeFirst();
              showMessage(context, message);
            }
          },
        );
        if (!model.ready) {
          return wrapScaffold(
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          );
        } else if (model.ready && !model.available) {
          return wrapScaffold(
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Could not find any models, "
                    "please check your backends and reload.",
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await model.init(inputController);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("Reload"),
                  )
                ],
              ),
            ),
          );
        }
        return SafeArea(
          child: Scaffold(
            body: SingleChildScrollView(
              child: wrapPadding(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildInputOutput(model),
                    const SizedBox(height: 8),
                    buildPipeline(model),
                    if (links.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      buildLinks(),
                    ]
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildLinks() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        maintainState: true,
        initiallyExpanded: false,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text("Additional material"),
        childrenPadding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 16,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: links
                .map((l) => LinkChip(
                      l,
                      launchOrMessage(l.url),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget buildPipeline(HomeModel model) {
    String? infoText;
    if (model.validModel) {
      final info = model.modelInfos.firstWhere(
        (info) => info.name == model.model,
      );
      infoText = info.description;
      if (info.tags.isNotEmpty) {
        infoText += " (${info.tags.join(', ')})";
      }
    }
    final validPresets =
        presets.where((preset) => model.isValidPreset(preset)).toList();
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        maintainState: true,
        initiallyExpanded: !model.validModel,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text(
          "Model selection",
          style: TextStyle(fontSize: 18),
        ),
        subtitle: const Text(
          "The model determines quality and latency of the generated answer",
        ),
        childrenPadding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 16,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (validPresets.isNotEmpty) ...[
            Presets(
              presets: validPresets,
              model: model.model,
              onSelected: (preset) {
                setState(
                  () {
                    if (preset == null) {
                      model.model = null;
                    } else {
                      model.model = preset.model;
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 8)
          ],
          DropdownButtonFormField<String>(
            value: model.model,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.question_answer_outlined,
                color: model.validModel ? uniBlue : null,
              ),
              suffixIcon: IconButton(
                splashRadius: 16,
                tooltip: "Clear model",
                color: uniRed,
                icon: const Icon(Icons.clear),
                onPressed: model.validModel
                    ? () {
                        setState(() {
                          model.model = null;
                        });
                      }
                    : null,
              ),
              hintText: "Select a model",
              labelText: "Question answering model",
              helperMaxLines: 10,
              helperText: infoText,
            ),
            icon: const Icon(Icons.arrow_drop_down_rounded),
            items: model.modelInfos.map<DropdownMenuItem<String>>(
              (modelInfo) {
                return DropdownMenuItem(
                  value: modelInfo.name,
                  child: Text(modelInfo.name),
                );
              },
            ).toList(),
            onChanged: (String? modelName) {
              if (modelName == null) return;
              setState(
                () {
                  model.model = modelName;
                },
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: model.validModel
                    ? () async {
                        await model.saveModel();
                        setState(() {
                          showMessage(
                            context,
                            Message("Saved model settings", Status.info),
                          );
                        });
                      }
                    : null,
                icon: const Icon(Icons.save, size: 16),
                style: ElevatedButton.styleFrom(
                  backgroundColor: uniBlue,
                ),
                label: const Text("Save model settings"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget inputTextField(HomeModel model) {
    final canRun =
        model.validModel && !model.waiting && inputController.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: launchOrMessage(
              "https://ad.informatik.uni-freiburg.de",
            ),
            child: SizedBox(
              width: 160,
              child: Image.network(
                "${A.api.webBaseURL}"
                "/assets/images/logo.png",
              ),
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          trailing: IconButton(
            icon: const Icon(
              Icons.info_outlined,
            ),
            splashRadius: 16,
            tooltip: "Show backend information",
            onPressed: () {
              if (model.backendInfo == null) {
                showMessage(
                  context,
                  Message(
                    "backend info not available",
                    Status.warn,
                  ),
                );
                return;
              }
              showInfoDialog(
                model.backendInfo!,
              );
            },
          ),
          title: const Text(
            title,
            style: TextStyle(fontSize: 22),
          ),
          subtitle: const Text(
            description,
            style: TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: model.inputController,
          maxLength: 128,
          readOnly: model.waiting,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          onSubmitted: canRun
              ? (text) async {
                  await model.runPipeline(text);
                }
              : null,
          focusNode: inputFocus,
          autofocus: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: "Enter your question",
            helperText:
                model.hasResults ? formatRuntime(model.output!.runtime) : null,
            helperMaxLines: 2,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: canRun
                      ? () async {
                          await model.runPipeline(
                            model.inputController.text,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.start),
                  color: uniBlue,
                  tooltip: "Run model on question",
                  splashRadius: 16,
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: "Clear question",
                  splashRadius: 16,
                  color: uniRed,
                  onPressed: !model.waiting && model.hasInput
                      ? () {
                          setState(
                            () {
                              model.inputController.value =
                                  const TextEditingValue(
                                text: "",
                                selection: TextSelection.collapsed(offset: 0),
                              );
                            },
                          );
                        }
                      : null,
                ),
                IconButton(
                    icon: Icon(
                      model.sc ? Icons.spellcheck : Icons.spellcheck_outlined,
                    ),
                    tooltip:
                        "${model.sc ? "Disable" : "Enable"} spell checking",
                    splashRadius: 16,
                    onPressed: () {
                      setState(
                        () {
                          model.sc = !model.sc;
                        },
                      );
                    }),
                IconButton(
                    icon: Icon(
                      model.hq
                          ? Icons.high_quality
                          : Icons.high_quality_outlined,
                    ),
                    tooltip: "${model.hq ? "Disable" : "Enable"} high quality",
                    splashRadius: 16,
                    onPressed: () {
                      setState(
                        () {
                          model.hq = !model.hq;
                        },
                      );
                    }),
                if (examples.isNotEmpty)
                  IconButton(
                    onPressed: !model.waiting
                        ? () async {
                            final example = await showExamplesDialog(
                              examples,
                            );
                            if (example != null) {
                              setState(
                                () {
                                  inputController.value = TextEditingValue(
                                    text: example,
                                    composing: TextRange.collapsed(
                                      example.length,
                                    ),
                                  );
                                  inputFocus.requestFocus();
                                },
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.list),
                    tooltip: "Choose an example question",
                    splashRadius: 16,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildInputOutput(HomeModel model) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          children: [
            inputTextField(model),
            if (model.waiting)
              const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            if (model.hasResults) ...[
              const SizedBox(height: 8),
              outputField(model)
            ],
            const SizedBox(height: 8)
          ],
        ),
      ),
    );
  }

  Widget outputField(HomeModel model) {
    final output = model.output!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            initiallyExpanded: false,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text("Detailed information"),
            childrenPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 16,
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Input"),
              const Divider(
                height: 2,
                color: uniBlue,
              ),
              const SizedBox(height: 8),
              SelectableText(output.input.join("\n")),
              const SizedBox(height: 16),
              const Text("Output"),
              const Divider(
                height: 2,
                color: uniBlue,
              ),
              const SizedBox(height: 8),
              SelectableText(output.output.join("\n")),
              if (output.hasSparql) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text("SPARQL"),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () async {
                        final sparqlEnc = Uri.encodeQueryComponent(
                          formatSparql(
                            output.sparql!.first,
                          ),
                        );
                        await launchOrMessage(
                          "https://qlever.cs.uni-freiburg.de/"
                          "wikidata/?query=$sparqlEnc",
                        )();
                      },
                      tooltip: "View in QLever",
                      splashRadius: 16,
                      icon: const Icon(
                        Icons.open_in_new,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const Divider(
                  height: 2,
                  color: uniBlue,
                ),
                const SizedBox(height: 8),
                SelectableText(output.sparql!.join("\n")),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...output.hasExecution
                    ? [
                        Text(
                          "${output.execution!.results.length} result"
                          "${output.execution!.results.length != 1 ? "s" : ""}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: uniDarkGray,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        resultTable(output.execution!)
                      ]
                    : [const Text("No execution")],
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(
                      child: Text(
                        "Is this output helpful to answer your question?",
                        style: TextStyle(
                          fontSize: 12,
                          color: uniDarkGray,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: "Helpful",
                      iconSize: 12,
                      splashRadius: 12,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.thumb_up_outlined,
                        color: model.feedback == A.Feedback.helpful
                            ? uniBlue
                            : uniDarkGray,
                      ),
                      onPressed: model.gaveFeedback
                          ? null
                          : () async {
                              final success = await model.giveFeedback(
                                A.Feedback.helpful,
                              );
                              if (success) {
                                setState(() {
                                  model.feedback = A.Feedback.helpful;
                                });
                              } else if (mounted) {
                                showMessage(
                                    context,
                                    Message(
                                      "failed to send feedback",
                                      Status.warn,
                                    ));
                              }
                            },
                    ),
                    IconButton(
                      tooltip: "Not helpful",
                      iconSize: 12,
                      splashRadius: 12,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.thumb_down_outlined,
                        color: model.feedback == A.Feedback.unhelpful
                            ? uniBlue
                            : uniDarkGray,
                      ),
                      onPressed: model.gaveFeedback
                          ? null
                          : () async {
                              final success = await model.giveFeedback(
                                A.Feedback.unhelpful,
                              );
                              if (success) {
                                setState(() {
                                  model.feedback = A.Feedback.unhelpful;
                                });
                              } else if (mounted) {
                                showMessage(
                                    context,
                                    Message(
                                      "failed to send feedback",
                                      Status.warn,
                                    ));
                              }
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget resultTable(
    A.ExecutionResult execution, {
    int topK = 100,
  }) {
    return Table(
      children: [
        TableRow(
          children: execution.vars
              .map((v) => SelectableText(
                    v,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
        ),
        ...execution.results.take(topK).map((result) {
          return TableRow(
            children: execution.vars
                .map((v) => (result[v]?.toWidget() ?? const Text("-")))
                .toList(),
          );
        }),
      ],
    );
  }

  showInfoDialog(A.BackendInfo info) async {
    const optionPadding = EdgeInsets.symmetric(vertical: 8, horizontal: 8);
    await showDialog(
      context: context,
      builder: (infoContext) {
        return SimpleDialog(
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          title: const Text(
            "Info",
            textAlign: TextAlign.center,
          ),
          children: [
            SimpleDialogOption(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 2,
                child: Column(
                  children: [
                    const SimpleDialogOption(
                      padding: optionPadding,
                      child: Text(
                        "Backend",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    SimpleDialogOption(
                      padding: optionPadding,
                      child: Text(
                        "Timeout: ${info.timeout.toStringAsFixed(2)} seconds",
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SimpleDialogOption(
                      padding: optionPadding,
                      child: Text(
                        "CPU: ${info.cpuInfo}",
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ...info.gpuInfos.mapIndexed(
                      (idx, info) => SimpleDialogOption(
                        padding: optionPadding,
                        child: Text(
                          "GPU ${idx + 1}: $info",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget exampleGroup(
    String groupName,
    List<String> items,
    Function(String) onSelected,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              visualDensity: VisualDensity.compact,
              title: Text(
                groupName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListView.builder(
              itemCount: items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (listContext, idx) {
                return ListTile(
                  visualDensity: VisualDensity.compact,
                  title: Text(items[idx]),
                  subtitle: Text("Question ${idx + 1}"),
                  onTap: () => onSelected(items[idx]),
                  // leading: const Icon(Icons.notes),
                );
              },
            )
          ],
        ),
      ),
    );
  }

  Future<String?> showExamplesDialog(Map<String, List<String>> examples) async {
    return await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        final exampleGroups = examples.entries
            .map((entry) {
              return exampleGroup(
                entry.key,
                entry.value,
                (item) => Navigator.of(dialogContext).pop(item),
              );
            })
            .toList()
            .cast<Widget>();
        return Dialog(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(children: exampleGroups),
            ),
          ),
        );
      },
    );
  }
}
