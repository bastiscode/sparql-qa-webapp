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
  String s = "Took ${formatS(runtime.clientS)} in total, "
      "thereof ${formatS(runtime.backendS)} in the backend";
  if (runtime.executionS == null) return s;
  return "$s and ${formatS(runtime.executionS!)} executing SPARQL";
}

String formatSparql(String sparql) {
  sparql = sparql.replaceAll(RegExp(r"\s+", dotAll: true), " ");
  final prefixRegex = RegExp(
    r"(\s*prefix\s+\S+:\s*<.*?>\s*)",
    dotAll: true,
    caseSensitive: false,
  );
  sparql = sparql.replaceAllMapped(
    prefixRegex,
    (m) => "${m.group(1)!.trim()}\n",
  );
  final brackets = RegExp(
    r"(\s*([{}])\s*)",
    dotAll: true,
  );
  int currOpen = 0;
  sparql = sparql.replaceAllMapped(
    brackets,
    (m) {
      if (m.group(2) == "{") {
        currOpen++;
      } else {
        currOpen--;
      }
      return "\n${m.group(1)!.trim()}\n${"  " * currOpen}";
    },
  );
  return sparql;
}

String processOutput(String output, List<dynamic> specialTokens) {
  for (final special in specialTokens) {
    output = output.replaceAll(special["token"], special["replacement"]);
  }
  return output;
}