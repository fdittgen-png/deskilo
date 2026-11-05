// SPDX-License-Identifier: AGPL-3.0-or-later
// Synthetic bank statement used by the Demo reconciliation journey. No real
// account or bank data; opening 100.00 + 50.00 - 10.00 = closing 140.00.
const String demoReconciliationStatementXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08">
  <BkToCstmrStmt><GrpHdr><MsgId>DEMO-REPORT</MsgId></GrpHdr><Stmt>
    <Id>DEMO-REPORT-202601</Id>
    <Acct><Id><Othr><Id>DEMO-REPORT-ACCOUNT</Id></Othr></Id><Ccy>EUR</Ccy></Acct>
    <Bal><Tp><CdOrPrtry><Cd>OPBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">100.00</Amt><CdtDbtInd>CRDT</CdtDbtInd><Dt><Dt>2026-01-01</Dt></Dt></Bal>
    <Bal><Tp><CdOrPrtry><Cd>CLBD</Cd></CdOrPrtry></Tp><Amt Ccy="EUR">140.00</Amt><CdtDbtInd>CRDT</CdtDbtInd><Dt><Dt>2026-01-31</Dt></Dt></Bal>
    <Ntry><Amt Ccy="EUR">50.00</Amt><CdtDbtInd>CRDT</CdtDbtInd><Sts><Cd>BOOK</Cd></Sts><BookgDt><Dt>2026-01-15</Dt></BookgDt><ValDt><Dt>2026-01-16</Dt></ValDt><AcctSvcrRef>DEMO-REPORT-1</AcctSvcrRef><NtryDtls><TxDtls><RmtInf><Ustrd>Demo receipt</Ustrd></RmtInf></TxDtls></NtryDtls></Ntry>
    <Ntry><Amt Ccy="EUR">10.00</Amt><CdtDbtInd>DBIT</CdtDbtInd><Sts><Cd>BOOK</Cd></Sts><BookgDt><Dt>2026-01-20</Dt></BookgDt><ValDt><Dt>2026-01-21</Dt></ValDt><AcctSvcrRef>DEMO-REPORT-2</AcctSvcrRef><NtryDtls><TxDtls><RmtInf><Ustrd>Named unmatched stationery</Ustrd></RmtInf></TxDtls></NtryDtls></Ntry>
  </Stmt></BkToCstmrStmt>
</Document>
''';
