# DentalLab per macOS e Windows

Gestionale locale per un laboratorio odontotecnico italiano. **Versione di sviluppo: non certificata né pronta per l’uso fiscale o clinico senza verifica.**

![Logo DentalLab](Logo.png)

[Scarica l’app dalle release](https://github.com/yn7wvz64hj-oss/DentalLab/releases/latest).

Richiede macOS 13 o successivo. Il pacchetto 0.6 è per Mac Intel; su Apple Silicon richiede Rosetta o ricompilazione. Archivio cifrato, moduli di laboratorio, consegne su Google Calendar tramite Calendario del Mac, aggiornamenti Sparkle firmati e logo a dente, password al primo avvio della giornata e lavori suddivisi per anno di consegna e mappa dentale con lavorazione e colore per elemento.

L’app è firmata ad hoc, non notarizzata. Leggi [LEGGIMI.md](LEGGIMI.md), [REQUISITI-E-LIMITI.md](REQUISITI-E-LIMITI.md) e [VERIFICA.md](VERIFICA.md) prima dell’uso.

## Compilare

Esegui `./compila.sh` su macOS con Command Line Tools. Poi `DentalLab.app/Contents/MacOS/DentalLab --self-test`.

Nessun archivio reale o chiave privata è incluso nel repository. Il controllo degli aggiornamenti non carica dati di laboratorio. Sparkle è distribuito con la propria licenza in Vendor/SPARKLE-LICENSE.

## Archivio locale e backup USB

La versione in questo branch migra l'archivio Mac a SQLite con snapshot cifrati conservando i sorgenti precedenti. Include una prima app Windows WPF che legge e scrive lo stesso backup cifrato, verifica l'integrità e crea una copia completa prima del ripristino. Windows gestisce pazienti, studi, lavori, odontogrammi, colori, allegati e dichiarazioni collegate ai lavori con PDF, stampa e registrazione; i moduli fiscali e di magazzino avanzati restano sul Mac.

Leggi [ARCHIVIO-PORTABILE.md](ARCHIVIO-PORTABILE.md) per installazione Windows, migrazione, trasferimento USB, recupero e limiti. Un solo computer deve essere operativo: il blocco locale impedisce istanze simultanee sullo stesso archivio, ma due copie offline su computer diversi richiedono una procedura di passaggio. La modalità di scambio tramite disco condiviso/VPN è descritta in [SINCRONIZZAZIONE-VPN.md](SINCRONIZZAZIONE-VPN.md); consente uso alternato, senza un database aperto in rete o modifiche simultanee.

Dalla scheda lavoro usa **Conformità…** per creare o riaprire la dichiarazione, salvarla in PDF e stamparla. La mappa offre **Selezione multipla** e selezione delle arcate. Guida: [CONFORMITA-E-DENTI.md](CONFORMITA-E-DENTI.md). I pacchetti Windows/Mac e gli installer dell’ultima build riuscita sono negli artifact di GitHub Actions.
