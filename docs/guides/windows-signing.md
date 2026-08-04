<!-- SPDX-License-Identifier: 0BSD -->

# Windows code signing (SmartScreen)

Windows SmartScreen shows **"Windows a protégé votre ordinateur /
Éditeur inconnu"** for every unsigned installer. The warning cannot be
suppressed from our side without a signature; users can bypass it once
via *Informations complémentaires → Exécuter quand même*, but the only
permanent fix is Authenticode-signing `deskilo.exe` and the MSI
(#449).

The `windows-msi` workflow already contains the signing steps. They
activate the moment two repository secrets exist and are skipped (with
a log notice) otherwise — the same honest-unsigned pattern as the
macOS DMG (#371).

## Owner setup

1. **Get a code-signing certificate.** Options, roughly by
   practicality:
   - **Azure Trusted Signing** (~10 €/month, identity validation
     against a company or a natural person; the modern route Microsoft
     itself pushes). Note: it signs via a cloud API, not a PFX — if
     you choose this, open an issue and the workflow will be switched
     to `azure/trusted-signing-action` with its five secrets instead.
   - **A classic OV certificate** (Certum ~ 25 €/year for open
     source, otherwise Sectigo/SSL.com/GlobalSign, 70–400 €/year).
     Ships as a PFX/P12 file or on a hardware token — buy the
     file-based (or cloud-HSM with PFX export) variant; token-only
     certificates cannot run in CI.
   - An **EV certificate** removes SmartScreen reputation build-up
     entirely but costs more and is usually token-bound.

   With an OV certificate, SmartScreen may still warn for the first
   days until Microsoft's reputation system has seen enough
   installs; that period is normal and ends on its own.

2. **Store the certificate as secrets** (GitHub → Settings → Secrets
   and variables → Actions):

   ```bash
   base64 -i codesign.pfx | gh secret set WINDOWS_CERT_PFX_BASE64
   gh secret set WINDOWS_CERT_PASSWORD   # the PFX password, typed on prompt
   ```

3. **Re-run the workflow**: `gh workflow run windows-msi.yml`. The log
   shows the signing steps running instead of the "shipping unsigned"
   notice; `signtool verify /pa DesKilo-*.msi` on any Windows machine
   confirms the signature.

## Already-installed handling

Each CI build stamps a unique, increasing MSI `ProductVersion`
(`major.minor.<run number>`), and the WiX `MajorUpgrade` element
replaces any older installed version automatically during install — no
manual uninstall needed. Only running an MSI *older* than the installed
one is refused, with a message pointing to Settings → Apps to
uninstall first.
