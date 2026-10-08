# DentalLab per macOS

Gestionale locale per un laboratorio odontotecnico italiano. **Versione di sviluppo: non certificata né pronta per l’uso fiscale o clinico senza verifica.**

![Logo DentalLab](Logo.png)

[Scarica l’app dalle release](https://github.com/yn7wvz64hj-oss/DentalLab/releases/latest).

Richiede macOS 13 o successivo. Il pacchetto 0.4 è per Mac Intel; su Apple Silicon richiede Rosetta o ricompilazione. Archivio cifrato, moduli di laboratorio, consegne su Google Calendar tramite Calendario del Mac, aggiornamenti Sparkle firmati e logo a dente.

L’app è firmata ad hoc, non notarizzata. Leggi [LEGGIMI.md](LEGGIMI.md), [REQUISITI-E-LIMITI.md](REQUISITI-E-LIMITI.md) e [VERIFICA.md](VERIFICA.md) prima dell’uso.

## Compilare

Esegui `./compila.sh` su macOS con Command Line Tools. Poi `DentalLab.app/Contents/MacOS/DentalLab --self-test`.

Nessun archivio reale o chiave privata è incluso nel repository. Il controllo degli aggiornamenti non carica dati di laboratorio. Sparkle è distribuito con la propria licenza in Vendor/SPARKLE-LICENSE.
