# DentalLab 0.4 per Mac

Versione di sviluppo con interfaccia rinnovata, archivio locale cifrato e moduli per un laboratorio italiano di dispositivi odontotecnici su misura in regime ordinario.

## Avvio

Apri **DentalLab.app**. Richiede macOS 13 o successivo. Il pacchetto è compilato per Mac Intel; su Apple Silicon richiede Rosetta oppure la ricompilazione sul Mac con `./compila.sh`. È firmato localmente ad hoc, non notarizzato da Apple: l’eventuale autorizzazione di macOS va valutata dall’utente. Al primo avvio il Portachiavi può richiedere di autorizzare l’accesso alla chiave dell’archivio.

L’app inizia vuota. Nessun dato dimostrativo viene caricato nell’archivio reale. Le immagini di anteprima usano dati fittizi.

1. Apri Impostazioni e compila i dati del laboratorio, sedi produttive e riferimenti delle procedure.
2. In Impostazioni controlla anno/serie/prossimo numero se hai documenti precedenti emessi fuori dall’app; poi inserisci i clienti con i dati fiscali e gli indirizzi.
3. Crea un lavoro, collega il cliente e usa un codice paziente quando possibile.
4. Compila Dispositivo e Fascicolo; allega la prescrizione e le evidenze.
5. Inserisci lavorazioni e prezzi nelle Righe. IVA/natura/riferimento fiscale vanno scelti per ogni riga.
6. Dal menu del lavoro crea preventivo, documento di consegna, dichiarazione o fattura.
7. Esporta un backup completo protetto da password su un supporto separato.

## Moduli disponibili

- **Panoramica e scadenze**: produzione, consegne, saldi, scorte e scadenze delle schede qualità/sorveglianza.
- **Clienti e pazienti**: anagrafiche con dati strutturati; codici paziente senza imporre il nome completo.
- **Lavori**: stato, prescrizione, tipo dispositivo, classe valutata dal fabbricante, denti/colore, fascicolo e allegati.
- **Listino e preventivi**: righe, quantità, prezzi, sconti, IVA e natura fiscale; totali con decimali.
- **Consegne**: destinatario, indirizzo, data trasporto, causale, vettore e colli; righe senza prezzi nel PDF.
- **Fatture**: TD01 e note di credito TD04 per clienti italiani con P.IVA, regime RF01; numero assegnato nella registrazione; XML FPR12, PDF, incassi parziali e annotazioni manuali degli esiti SDI.
- **Magazzino**: lotti, fornitori, unità, scadenze, soglia minima, carichi/scarichi e consumo collegato al lavoro; impedisce quantità negative.
- **Conformità**: dichiarazione strutturata per dispositivi su misura e controllo di completezza; conserva il testo dei materiali al momento della registrazione e i dati del fabbricante/cliente.
- **Qualità**: non conformità, controlli e azioni correttive con analisi, responsabile ed efficacia.
- **Sorveglianza**: reclami, incidenti, piani PMS/PMCF, rapporti e PSUR, azioni di sicurezza; registri e allegati da compilare con la propria procedura.
- **Attività**: cronologia delle modifiche e delle operazioni. Non è un audit trail certificato.

## Documenti registrati

La registrazione assegna un numero per tipo e anno e blocca il contenuto. Non equivale a emissione fiscale, trasmissione, firma o validazione normativa. Per rettificare una fattura, crea una nota di credito collegata. Le note registrate riducono il saldo da incassare; eventuali rimborsi a clienti già pagati non sono gestiti automaticamente.

Le dichiarazioni hanno il nome corretto per il dispositivo su misura, riferimenti alla prescrizione e ai requisiti dell’Allegato I, indicazione del paziente, sostanze/tessuti, eccezioni motivate, luoghi di fabbricazione, controlli e spazio firma. Sono esclusi dal percorso di registrazione i dispositivi su misura impiantabili di classe III, che richiedono una procedura aggiuntiva.

## Limiti per l’uso professionale

Questa versione **non è dichiarata integralmente conforme alla normativa né pronta per la produzione senza verifica**. È necessario validare con il laboratorio e i suoi consulenti i documenti, i processi e il trattamento fiscale effettivo. Vedi REQUISITI-E-LIMITI.md.

Il sito dell’Agenzia delle Entrate ha bloccato il recupero dello schema XSD corrente durante lo sviluppo. L’XML è controllato per struttura ben formata e alcuni dati/calcoli, ma **non è ancora validato contro l’XSD ufficiale corrente né contro tutti i controlli SDI**. Utilizzalo solo dopo verifica con il servizio fiscale. Non sono inclusi invio SDI, acquisizione automatica ricevute, firma elettronica, conservazione fiscale a norma, PA/estero, split payment, ritenute o altri regimi speciali. Il bollo va determinato e impostato manualmente.

I moduli MDR gestiscono dati e documenti, ma non fanno classificazione automatica, valutazione clinica, valutazione dei rischi o segnalazioni alle autorità al posto del fabbricante. Piani PMS/PMCF e PSUR sono registri da compilare e allegare, non rapporti clinici generati automaticamente.

## Archivio e backup

Cartella: `~/Library/Application Support/DentalLab`.

- `archivio.dlvault`: dati cifrati con AES-256-GCM.
- `FileCifrati`: allegati cifrati singolarmente. Limite 100 MB per file.
- `BackupLocali`: ultime 60 copie cifrate del database prima di ogni modifica. Gli allegati precedenti non vengono rimossi automaticamente.
- Chiave locale nel Portachiavi, non nel progetto. Le copie locali richiedono la chiave di questo Mac.
- **Backup completo portabile**: file `.dlbackup`, protetto da password di almeno 12 caratteri (PBKDF2-HMAC-SHA256, 310.000 iterazioni, sale casuale e AES-GCM); include dati e allegati, con limite complessivo di 500 MB per gli allegati.

Ripristina da Backup > Ripristina backup, scegli il file e inserisci la password. La password errata o un file alterato vengono rifiutati. Il contenuto viene verificato prima di sostituire i dati. Sul Mac attuale il ripristino mantiene i progressivi già riservati per evitare riuso dei numeri. Su un altro Mac, verifica i progressivi contro i documenti realmente emessi, anche successivi alla data del backup. Il ripristino mantiene una copia locale della versione precedente e conserva gli allegati precedenti per recupero. Il backup su disco esterno si avvia manualmente; le copie automatiche locali non proteggono dal guasto del disco.

PDF, XML e allegati esportati sono copie in chiaro. Proteggi il Mac con le misure appropriate al tuo caso. Il pulsante di blocco usa l’autenticazione macOS se disponibile; non c’è ancora un blocco automatico per inattività.

L’archivio della prima versione viene importato al primo avvio. I vecchi JSON, backup e allegati in chiaro restano conservati: dopo verifica del trasferimento e di un backup completo, pianifica la loro rimozione. Non vengono cancellati automaticamente per evitare perdita di dati.

## Verifica e sorgenti

Sorgenti in `Sources/DentalLab` e `Sources/CryptoSupport`. Compila con `./compila.sh`, oppure con Xcode completo e `swift build -c release`.

Il programma offre `--self-test`: i test usano cartelle temporanee e chiavi di prova, senza toccare l’archivio reale. Coprono conti decimali, IVA, controllo P.IVA, struttura XML e precisione, numerazione, documenti bloccati anche da bozze obsolete, incassi, note di credito, magazzino, consumi/lotti, controlli di completezza MDR/DDT, cifratura, password errata, alterazione backup, ripristino allegati, archivio corrotto, migrazione e PDF multipagina.

La verifica visuale usa rendering nativo delle viste SwiftUI e dei PDF con l’eseguibile non impacchettato. L’avvio grafico del pacchetto da Finder non è stato verificato in questo ambiente. Non sostituisce una prova completa interattiva su tutte le configurazioni Mac e sui processi del laboratorio.

## Google Calendar

L’account Google deve essere già presente nell’app Calendario di macOS, con il calendario desiderato visibile e modificabile. Il collegamento usa EventKit: macOS gestisce l’autenticazione e la sincronizzazione con Google, senza inserire password Google in DentalLab.

1. Apri **Impostazioni → Google Calendar → Autorizza calendari** e concedi l’accesso completo nella richiesta di macOS.
2. Seleziona il calendario sotto l’account Google corretto; consigliato un calendario dedicato a DentalLab. L’elenco comprende anche calendari locali: verifica il nome dell’account.
3. Scegli se aggiornare automaticamente dopo i salvataggi, premi **Collega e sincronizza** e conferma il calendario e i dati inviati.
4. Verifica nell’app Calendario del Mac e poi in Google Calendar. La conferma di DentalLab riguarda il salvataggio locale; il completamento sul server Google dipende da macOS, dall’account e dalla connessione.

Sono sincronizzate le date dei lavori non consegnati e non archiviati, come eventi per l’intera giornata in Europe/Rome, con titolo “DentalLab · Consegna DL-codice”. Non vengono copiati titolo del lavoro, nomi, pazienti, descrizioni o allegati. Il codice resta comunque un riferimento all’archivio: valuta accessi e condivisione del calendario.

La sincronizzazione è a senso unico, da DentalLab al calendario: gli spostamenti manuali nel calendario saranno sovrascritti al successivo aggiornamento. Vengono rimossi solo gli eventi riconosciuti come creati da questo collegamento quando il lavoro è consegnato o archiviato. Cambiare calendario lascia le vecchie copie nel precedente. “Disattiva automatico” conserva gli eventi e consente ancora aggiornamenti manuali. La sincronizzazione automatica funziona mentre DentalLab è aperto e l’archivio sbloccato; all’apertura riprende gli aggiornamenti pendenti. Dopo un ripristino del backup devi ricollegare il calendario; eventuali vecchi eventi vanno controllati per evitare copie.

Se neghi l’autorizzazione, modifica **Impostazioni di Sistema → Privacy e sicurezza → Calendari** e riprova. DentalLab non modifica gli altri eventi; l’autorizzazione completa è richiesta da EventKit per riconoscere e aggiornare i propri eventi.

Configurazione Google su Mac: https://support.google.com/calendar/answer/99358?co=GENIE.Platform%3DDesktop&hl=it-IT

## Aggiornamenti dall’app

La versione 0.4 integra Sparkle 2.10.0. Nel menu DentalLab e nelle Impostazioni trovi “Cerca aggiornamenti…”. Puoi abilitare il controllo automatico; l’installazione richiede sempre conferma. La verifica dell’appcast e del pacchetto usa Ed25519; un feed non firmato o un pacchetto alterato viene rifiutato prima dell’estrazione. Il controllo usa GitHub e non invia il tuo archivio. L’app non è notarizzata: le richieste del Portachiavi e di macOS possono comparire anche dopo un aggiornamento.

La prima installazione della 0.4 va fatta dal pacchetto scaricato: le versioni precedenti non contengono l’aggiornatore. Installa l’app in una cartella scrivibile e apri quella copia; salva le bozze e un backup prima di aggiornare. Gli aggiornamenti successivi sostituiscono l’app, lasciando l’archivio in Application Support. Per i dati cifrati serve sempre il Portachiavi originale o un backup completo con password.

Il canale previsto è https://github.com/yn7wvz64hj-oss/DentalLab/releases . Diventa operativo quando il repository pubblico e la prima release con i due asset sono pubblicati. Se GitHub è irraggiungibile o il feed manca, Sparkle mostra un errore: non significa che l’app sia aggiornata.

### Pubblicare una nuova versione

1. Incrementa CFBundleVersion e CFBundleShortVersionString in compila.sh; compila ed esegui --self-test.
2. Conserva la chiave privata di firma separatamente dal repository. La chiave pubblica è in Resources/UpdatePublicKey.txt. La chiave privata creata per questa installazione è nel file work/dentallab-update-private-key della cartella di lavoro Codex: non caricarla su GitHub e conservane una copia protetta.
3. Esegui `python3 Tools/prepara-release.py --key /percorso/chiave-privata --output /percorso/release` usando la stessa chiave. Lo script verifica firma locale dell’app, firma il pacchetto e il feed, e verifica le firme generate.
4. Crea una release GitHub con tag vVERSIONE e carica DentalLab-VERSIONE-mac.zip e appcast.xml. Impostala come release più recente. Controlla dall’app il feed pubblico e prova l’aggiornamento su una copia con dati di prova.

Il logo a dente è disponibile come Logo.png, Resources/Logo.svg e Resources/DentalLab.icns; la stessa forma è usata nella barra laterale.

Sparkle: https://sparkle-project.org/documentation/ . Licenza inclusa in Vendor/SPARKLE-LICENSE.
