# Verifica della versione 0.5

Compilazione nativa Swift 5.8.1 su macOS Intel: riuscita.

Test eseguiti sull’eseguibile in cartelle temporanee, con chiavi di prova:

- Calcoli decimali, sconti e IVA, inclusi prezzi con più di due decimali nell’XML.
- Controllo formale P.IVA, XML ben formato e riferimenti delle note di credito.
- Numerazione progressiva, divieto di doppia registrazione e di riscrittura da una bozza obsoleta.
- Blocco delle modifiche ai documenti registrati.
- Incassi parziali e rifiuto degli incassi superiori al saldo; rettifiche del saldo con note di credito.
- Magazzino non negativo e consumo collegato a lavoro e lotto.
- Controlli di completezza di dichiarazione MDR e documento di consegna.
- Archivio/allegati cifrati, backup cifrato, rifiuto di password errata e alterazione dei dati.
- Ripristino dell’archivio e degli allegati; mantenimento dei progressivi già riservati sul Mac.
- Archivio corrotto rifiutato senza sovrascriverlo e migrazione della versione precedente.
- PDF multipagina: generazione e rilettura delle pagine con Core Graphics; rendering visuale separato con PDFKit.

Esito: tutti superati.

Verifica visuale: cruscotto e scheda dispositivo renderizzati da SwiftUI; PDF renderizzati con PDFKit e controllati. Le immagini di anteprima contengono dati fittizi, non caricati nell’archivio reale.

Il test PDF automatico usa Core Graphics: PDFKit nel pacchetto avviato da terminale ha causato un arresto nella registrazione con LaunchServices in questo ambiente. Il rendering delle anteprime è stato verificato con l’eseguibile non impacchettato.

Non verificati: avvio grafico del pacchetto da Finder in questo ambiente, ciclo completo interattivo su tutte le configurazioni Mac, accesso al Portachiavi e autenticazione sul Mac dell’utente, schema XSD fiscale corrente, tutti i controlli SDI, invio/ricevute/conservazione fiscale e validazione normativa dei processi e dei modelli del laboratorio. Non è un’attestazione di conformità normativa.

### Calendario

Verifica automatica della pianificazione senza accedere a calendari reali: esclusione di altri moduli, lavori consegnati e archiviati; assenza di nomi e dati clinici nei titoli; durata di 23 ore al cambio dell’ora legale; compatibilità dell’archivio senza configurazione calendario. Compilazione della richiesta EventKit moderna risolta a runtime e fallback macOS 13.

Non è stato eseguito un collegamento al calendario personale né verificato l’arrivo degli eventi sul server Google. L’utente deve autorizzare l’app, scegliere il proprio calendario e verificare la prima sincronizzazione. Nessuna richiesta di accesso o scrittura su calendari reali viene eseguita dai test.

### Aggiornamenti e logo

Integrazione Sparkle 2.10.0 con controllo manuale e automatico opzionale; installazione silenziosa disabilitata. Configurati HTTPS, firma Ed25519 di feed e pacchetto, verifica prima dell’estrazione, nessuna scadenza della verifica del feed e nessuna profilazione di sistema. Lo script di release non include la chiave privata e verifica le firme dopo averle generate. Icona ICNS prodotta nelle risoluzioni standard e logo SVG/PNG controllato visivamente.

La sostituzione e il riavvio di un’app installata con una versione successiva non sono verificati su un archivio reale. Il canale remoto richiede la pubblicazione di una release GitHub e la relativa verifica pubblica.

### Password giornaliera e anni

Test con archivio e chiave temporanei: primo accesso bloccato senza password, configurazione, riapertura nella stessa giornata, nuova giornata bloccata, blocco manuale, rifiuto di password errata, divieto di salvare schede mentre bloccato, cambio password e rifiuto della precedente, persistenza cifrata del verificatore e salt casuale. Suddivisione lavori in anni, inclusione degli archiviati e passaggio d’anno nel fuso italiano. Nessun dato personale reale usato nei test.
