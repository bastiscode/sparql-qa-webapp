import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webapp/colors.dart';
import 'dart:convert';

import 'package:webapp/components/message.dart';
import 'package:webapp/config.dart';
import 'package:window_location_href/window_location_href.dart' as whref;

class ApiResult<T> {
  int statusCode;
  String? message;
  T? value;

  ApiResult(this.statusCode, {this.message, this.value}) {
    assert(this.message != null || this.value != null);
    assert(!(this.message == null && this.value == null));
  }
}

class ModelInfo {
  String name;
  String description;
  List<String> tags;

  ModelInfo(this.name, this.description, this.tags);
}

class BackendInfo {
  List<String> gpuInfos;
  String cpuInfo;
  double timeout;

  BackendInfo(this.gpuInfos, this.cpuInfo, this.timeout);
}

class Runtime {
  int b;
  double backendS;
  double clientS;
  double? executionS;

  Runtime(this.b, this.backendS, this.clientS, {this.executionS});

  static Runtime fromJson(
    dynamic json,
    double clientS,
    double? executionS,
  ) {
    return Runtime(
      json["b"],
      json["s"],
      clientS,
      executionS: executionS,
    );
  }
}

class ModelOutput {
  List<String> raw;
  List<String> input;
  List<String> output;
  List<String>? corrected;
  List<String>? sparql;
  List<dynamic>? specialTokens;
  ExecutionResult? execution;
  Runtime runtime;

  bool get hasSparql => sparql != null;

  bool get hasExecution => execution != null;

  ModelOutput(
    this.raw,
    this.input,
    this.output,
    this.runtime, {
    this.corrected,
    this.sparql,
    this.specialTokens,
    this.execution,
  });
}

class Record {
  String type;
  String value;
  String? label;

  Record(this.type, this.value, {this.label});

  Widget toWidget() {
    switch (type) {
      case "uri":
        {
          String val = value.split("/").last;
          if (label != null) {
            val = "$label ($val)";
          }
          return Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  child: Text(
                    val,
                    style: const TextStyle(color: uniBlue),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    final _ = await launchUrl(Uri.parse(value));
                  },
                ),
              ),
            ],
          );
        }
      default:
        // default case, includes literal
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText(
            label ?? value,
          ),
        );
    }
  }
}

class ExecutionResult {
  List<String> vars;
  List<Map<String, Record?>> results;

  ExecutionResult(
    this.vars,
    this.results,
  );

  int get length => results.length;
}

enum Feedback { helpful, unhelpful }

String feedbackToString(Feedback feedback) {
  switch (feedback) {
    case Feedback.helpful:
      return "helpful";
    case Feedback.unhelpful:
      return "unhelpful";
  }
}

class Api {
  late final String _baseURL;
  late final String _webBaseURL;

  String get webBaseURL => _webBaseURL;

  Api._privateConstructor() {
    String? href = whref.href;
    if (href != null) {
      if (href.endsWith("/")) {
        href = href.substring(0, href.length - 1);
      }
      String rel = baseURL;
      if (rel.startsWith("/")) {
        rel = rel.substring(1);
      }
      if (kReleaseMode) {
        // for release mode use href
        _baseURL = "$href/$rel";
      } else {
        // for local development use localhost
        _baseURL = "http://localhost:40000/$rel";
      }
      _webBaseURL = href;
    } else {
      throw UnsupportedError("unknown platform");
    }
  }

  static final Api _instance = Api._privateConstructor();

  static Api get instance {
    return _instance;
  }

  Future<ApiResult<List<ModelInfo>>> models() async {
    try {
      final res = await http.get(Uri.parse("$_baseURL/models"));
      if (res.statusCode != 200) {
        return ApiResult(
          res.statusCode,
          message: "error getting models: ${res.body}",
        );
      }
      final json = jsonDecode(res.body);
      List<ModelInfo> modelInfos = [];
      for (final modelInfo in json["models"]) {
        modelInfos.add(
          ModelInfo(
            modelInfo["name"],
            modelInfo["description"],
            modelInfo["tags"].cast<String>(),
          ),
        );
      }
      return ApiResult(res.statusCode, value: modelInfos);
    } catch (e) {
      return ApiResult(500, message: "internal error: $e");
    }
  }

  Future<ApiResult<BackendInfo>> info() async {
    try {
      final res = await http.get(Uri.parse("$_baseURL/info"));
      if (res.statusCode != 200) {
        return ApiResult(
          res.statusCode,
          message: "error getting backend info: ${res.body}",
        );
      }
      final json = jsonDecode(res.body);
      return ApiResult(
        res.statusCode,
        value: BackendInfo(
          json["gpu"].cast<String>(),
          json["cpu"],
          json["timeout"] as double,
        ),
      );
    } catch (e) {
      return ApiResult(500, message: "internal error: $e");
    }
  }

  Future<bool> feedback(
    String question,
    String sparql,
    Feedback feedback,
  ) async {
    try {
      final data = {
        "question": question,
        "sparql": sparql,
        "feedback": feedbackToString(feedback),
      };
      final res = await http.post(
        Uri.parse("$_baseURL/feedback"),
        body: jsonEncode(data),
        headers: {"Content-Type": "application/json"},
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<ApiResult<List<String>>> correct(List<String> questions) async {
    final pipeline = Uri.encodeComponent(
      ",,transformer with whitespace correction nmt",
    );
    final res = await http.post(
      Uri.parse(
        "https://spelling-correction.cs.uni-freiburg.de/api/run"
        "?pipeline=$pipeline",
      ),
      body: {"text": questions.join("\n")},
    );
    if (res.statusCode != 200) {
      return ApiResult(
        res.statusCode,
        message: "failed to correct $questions",
      );
    } else {
      final json = jsonDecode(res.body);
      return ApiResult(
        res.statusCode,
        value: json["output"]["sec"]["text"].cast<String>(),
      );
    }
  }

  Future<ApiResult<ExecutionResult>> execute(String sparql) async {
    final res = await http.post(
      Uri.parse(qleverEndpoint),
      body: sparql,
      headers: {"Content-type": "application/sparql-query"},
    );
    final json = jsonDecode(res.body);
    if (res.statusCode != 200) {
      return ApiResult(
        res.statusCode,
        message: json["exception"] ?? "unknown exception",
      );
    }
    List<String> vars = json["head"]["vars"].cast<String>();
    List<Map<String, Record?>> results = [];
    for (final binding in json["results"]["bindings"]) {
      Map<String, Record?> result = {};
      for (final vr in vars) {
        final vrBinding = binding?[vr];
        if (vrBinding == null) {
          result[vr] = null;
          continue;
        }
        final type = vrBinding["type"];
        final value = vrBinding["value"];
        result[vr] = Record(type, value);
      }
      results.add(result);
    }
    return ApiResult(
      res.statusCode,
      value: ExecutionResult(vars, results),
    );
  }

  Future<void> addLabels(
    String sparql,
    ExecutionResult ex, {
    String lang = "en",
  }) async {
    final entRegex = RegExp(r"^http://www.wikidata.org/entity/Q\d+$");
    final entVars = ex.vars.where((vr) {
      final val = ex.results.firstOrNull?[vr]?.value;
      return val != null && entRegex.hasMatch(val);
    }).toList();
    final entLabelVarsStr = entVars.map((vr) => "?${vr}Label").join(" ");
    final filterLabelStr = entVars.map((vr) {
      return "OPTIONAL { ?$vr rdfs:label ?${vr}Label "
          "FILTER(LANG(?${vr}Label) = \"$lang\") }";
    }).join(" ");
    final pfxRegex = RegExp(
      r"(prefix\s+\S+:\s*<.+>)",
      dotAll: true,
      caseSensitive: false,
    );
    final sparqlPrefixes =
        pfxRegex.allMatches(sparql).map((m) => m.group(1)).join(" ");
    final subSparql = sparql.replaceAll(pfxRegex, "");
    final labelRes = await execute(
      "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> "
      "$sparqlPrefixes "
      "SELECT $entLabelVarsStr WHERE { { $subSparql } $filterLabelStr }",
    );
    if (labelRes.statusCode != 200) return;
    for (final (i, rec) in labelRes.value!.results.indexed) {
      for (final vr in entVars) {
        ex.results[i][vr]?.label = rec["${vr}Label"]?.value;
      }
    }
  }

  Future<ApiResult<dynamic>> _post(
    String url,
    dynamic data,
  ) async {
    final res = await http.post(
      Uri.parse(url),
      body: jsonEncode(data),
      headers: {"Content-Type": "application/json"},
    );
    return ApiResult(
      res.statusCode,
      message: res.body,
      value: res.statusCode == 200 ? jsonDecode(res.body) : null,
    );
  }

  Future<ApiResult<ModelOutput>> runPipeline(
    List<String> input,
    String model,
    bool correctFirst,
    bool highQuality,
    bool withLabels,
  ) async {
    try {
      final stop = Stopwatch()..start();
      List<String>? corrected;
      if (correctFirst) {
        final res = await correct(input);
        if (res.statusCode != 200) {
          return ApiResult(
            res.statusCode,
            message: "correction failed: ${res.message}",
          );
        }
        corrected = res.value!;
      }
      var data = {
        "questions": corrected ?? input,
        "model": model,
        "search_strategy": highQuality ? "beam" : "greedy",
        "beam_width": 5,
        "subgraph_constraining": highQuality,
        "qlever_endpoint": qleverEndpoint
      };
      final res = await _post(
        "$_baseURL/answer",
        data,
      );
      if (res.statusCode != 200) {
        return ApiResult(
          res.statusCode,
          message: "model failed: ${res.message}",
        );
      }
      List<String>? sparql = res.value["sparql"]?.cast<String>();
      ExecutionResult? execution;
      double? executionS;
      if (sparql != null) {
        final exStop = Stopwatch()..start();
        assert(sparql.length == 1);
        final res = await execute(sparql.first);
        if (res.statusCode != 200) {
          return ApiResult(
            res.statusCode,
            message: "execution failed: ${res.message}",
          );
        }
        execution = res.value!;
        if (false && withLabels) {
          await addLabels(sparql.first, execution);
        }
        executionS = exStop.elapsedMicroseconds / 1e6;
      }
      final output = ModelOutput(
        input,
        res.value["input"].cast<String>(),
        res.value["raw"].cast<String>(),
        Runtime.fromJson(
          res.value["runtime"],
          stop.elapsedMicroseconds / 1e6,
          executionS,
        ),
        corrected: corrected,
        sparql: sparql,
        specialTokens: res.value["special_tokens"],
        execution: execution,
      );
      return ApiResult(200, value: output);
    } catch (e) {
      return ApiResult(500, message: "internal error: $e");
    }
  }
}

final api = Api.instance;

Message errorMessageFromApiResult(ApiResult result) {
  return Message("${result.statusCode}: ${result.message}", Status.error);
}
