import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webapp/api.dart';
import 'package:webapp/base_model.dart';
import 'package:webapp/components/message.dart';
import 'package:webapp/components/presets.dart';
import 'package:webapp/utils.dart';

class HomeModel extends BaseModel {
  static const maxLiveLength = 512;

  BackendInfo? backendInfo;
  List<ModelInfo> modelInfos = [];
  String? model;
  ModelOutput? output;

  List<String> input = [];
  int _inputBytes = 0;

  int get inputBytes => _inputBytes;

  Queue<Message> messages = Queue();

  late TextEditingController inputController;

  bool get validModel =>
      model != null &&
      modelInfos.indexWhere((info) => info.name == model!) != -1;

  bool _ready = false;

  bool get ready => _ready;

  bool get available => modelInfos.isNotEmpty;

  bool _waiting = false;

  bool get waiting => _waiting;

  bool get hasResults => output != null;

  double get totalClientRuntime => output?.runtime.clientS ?? 0.0;

  double get totalBackendRuntime => output?.runtime.backendS ?? 0.0;

  bool get hasInput => inputController.text.isNotEmpty;

  bool hideModel = false;

  bool sc = false;

  bool hq = true;

  Future<void> init(
    TextEditingController inputController,
  ) async {
    this.inputController = inputController;

    final modelRes = await api.models();
    if (modelRes.value != null) {
      modelInfos = modelRes.value!;
    }

    final infoRes = await api.info();
    if (infoRes.value != null) {
      backendInfo = infoRes.value!;
    }

    final prefs = await SharedPreferences.getInstance();
    hideModel = prefs.getBool("hideModel") ?? false;
    model = prefs.getString("model");
    if (!validModel) {
      model = null;
      hideModel = false;
    }

    _ready = true;
    notifyListeners();
  }

  saveModel() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("model", model!);
    prefs.setBool("hideModel", hideModel);
  }

  bool isValidPreset(Preset preset) {
    return modelInfos.indexWhere((info) => info.name == preset.model) != -1;
  }

  Future<void> runPipeline(String inputString) async {
    _waiting = true;
    output = null;
    input.clear();
    notifyListeners();
    final inputLines = inputString.trimRight().split("\n").toList();
    final result = await api.runPipeline(
      inputLines,
      model!,
      sc,
      hq,
    );
    if (result.statusCode == 200) {
      output = result.value!;
      input = inputLines;
      _inputBytes = numBytes(inputString);
    } else {
      messages.add(errorMessageFromApiResult(result));
    }
    _waiting = false;
    notifyListeners();
  }
}
