import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:webapp/components/links.dart';
import 'package:webapp/components/presets.dart';

// some general configuration options
const String title = "SPARQL question answering";
const String description =
    "Answer natural language questions over knowledge graphs";
const String lastUpdated = "Jul. 4, 2023";

const String baseURL = "/api";

// display links to additional resources on the website,
// will be shown as action chips below the title bar
const List<Link> links = [
  Link(
    "Code",
    "https://github.com/bastiscode/deep-sparql",
    icon: FontAwesomeIcons.github,
  ),
  Link(
    "Wikidata indices",
    "https://github.com/bastiscode/wikidata-natural-language-index",
    icon: FontAwesomeIcons.github,
  ),
  Link(
    "Wikidata indices",
    "https://ad-wikidata-index.cs.uni-freiburg.de",
    icon: Icons.text_snippet_outlined,
  ),
];

// examples
const Map<String, List<String>> examples = {
  "Simple questions": [
    "Where was Albert Einstein born?",
    "What does Angela Merkel do?",
    "How old is Barack Obama?",
    "On which continent is Bangladesh?",
    "What type of movie is Interstellar by Christopher Nolan?"
  ],
};

// display clickable choice chips inside pipeline selection
// that set a specific model for each task on click,
// default preset is always assumed to be the first in
// the following list
const List<Preset> presets = [];
