// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3932 -- the Spanish sandbox TEST submission: a record built from an invoice
// preview on a chain of its own, and the SOAP document that carries one record
// to the AEAT. The live records and their chain stay in `verifactu.dart`; a
// test touches none of them.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:xml/xml.dart';

import 'verifactu.dart';

/// The SOAP envelope and the AEAT's submission schema (SuministroLR), which
/// wraps the records of one submission.
const _soapNamespace = 'http://schemas.xmlsoap.org/soap/envelope/';
const _submissionNamespace =
    'https://www2.agenciatributaria.gob.es/static_files/common/internet/'
    'dep/aplicaciones/es/aeat/tike/cont/ws/SuministroLR.xsd';

/// The record of a sandbox TEST submission, built from an invoice preview (a
/// test number outside the series; nothing issued). It starts a chain of its
/// own: it takes no predecessor, so it can never claim a live record's huella,
/// and no live record can be derived from it. A test is an ordinary alta: a
/// credit note or a replacement is refused.
VerifactuRecord verifactuTestRecordFor({
  required RegisterDocument preview,
  required RegisterParty seller,
  required RegisterParty buyer,
  required DateTime generatedAt,
}) {
  if (preview.isCreditNote || preview.replacesNumber.isNotEmpty) {
    throw ArgumentError.value(
      preview.number,
      'preview',
      'a test record is an ordinary alta, not a rectification',
    );
  }
  return verifactuRecordFor(
    invoice: preview,
    seller: seller,
    buyer: buyer,
    previousHuella: '',
    generatedAt: generatedAt,
  );
}

/// The SOAP document of a submission of ONE record: the AEAT's
/// RegFactuSistemaFacturacion with its header naming the issuer, wrapping the
/// record. The authenticating certificate belongs to the connection, not to
/// the document.
String verifactuSubmissionXml(
  VerifactuRecord r, {
  required String issuerName,
  String description = 'Servicios de espacio de trabajo',
  VerifactuSystem system = const VerifactuSystem(),
}) {
  final record = XmlDocument.parse(
    verifactuRecordXml(
      r,
      issuerName: issuerName,
      description: description,
      system: system,
    ),
  ).rootElement;
  final recordNamespace = record.name.namespaceUri ?? '';
  final b = XmlBuilder();
  b.processing('xml', 'version="1.0" encoding="UTF-8"');
  b.element(
    'soapenv:Envelope',
    nest: () {
      b.namespace(_soapNamespace, 'soapenv');
      b.namespace(_submissionNamespace, 'sum');
      b.namespace(recordNamespace, 'sum1');
      b.element('soapenv:Header');
      b.element(
        'soapenv:Body',
        nest: () {
          b.element(
            'sum:RegFactuSistemaFacturacion',
            nest: () {
              b.element(
                'sum:Cabecera',
                nest: () {
                  b.element(
                    'sum1:ObligadoEmision',
                    nest: () {
                      b.element(
                        'sum1:NombreRazon',
                        nest: () => b.text(issuerName),
                      );
                      b.element('sum1:NIF', nest: () => b.text(r.issuerNif));
                    },
                  );
                },
              );
              b.element(
                'sum:RegistroFactura',
                nest: () => b.xml(record.toXmlString()),
              );
            },
          );
        },
      );
    },
  );
  return b.buildDocument().toXmlString(pretty: true, indent: '  ');
}
