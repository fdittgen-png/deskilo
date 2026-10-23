// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2862 — writes the published schema of workspace XML and its reference
// page from tool/workspace_xml_reference.dart.
//
//   dart run tool/build_workspace_xml_schema.dart
import 'dart:io';

import 'workspace_xml_reference.dart';

void main() {
  Directory('web/workspace-xml').createSync(recursive: true);
  File('web/workspace-xml/schema.xsd').writeAsStringSync(workspaceXmlXsd());
  File('web/workspace-xml/index.html')
      .writeAsStringSync(workspaceXmlReferenceHtml());
}
