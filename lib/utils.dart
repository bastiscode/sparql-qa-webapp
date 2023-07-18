import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webapp/api.dart';

String formatS(double s) {
  if (s < 1) {
    final ms = s * 1000;
    return "${ms.round()}ms";
  } else {
    return "${s.toStringAsFixed(2)}s";
  }
}

int numBytes(String s) {
  return utf8.encode(s).length;
}

String formatB(double b) {
  if (b > 1000) {
    b /= 1000;
    return "${b.toStringAsFixed(2)}kB";
  } else {
    return "${b.round()}B";
  }
}

String formatRuntime(Runtime runtime) {
  String s =  "Took ${formatS(runtime.clientS)} in total, "
      "thereof ${formatS(runtime.backendS)} in the backend";
  if (runtime.executionS == null) return s;
  return "$s and ${formatS(runtime.executionS!)} executing SPARQL";
}
