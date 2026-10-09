# Ambito normativo e validazione ancora necessaria

Ambito concordato: laboratorio in Italia, dispositivi odontotecnici su misura, un solo utilizzatore su Mac, regime fiscale ordinario. Revisione dei riferimenti: 8 ottobre 2026.

Questo documento distingue le funzioni implementate dagli adempimenti professionali. Un’interfaccia completa e dei campi obbligatori non attestano che un dispositivo, un processo o un documento siano conformi.

| Area | Funzione implementata | Verifica o servizio ancora necessario |
| --- | --- | --- |
| Dichiarazione su misura | Modello, campi strutturati, prescrizione allegata, verifica di completezza, numerazione, spazio firma | Verifica del modello per i dispositivi effettivi, conferma e firma del fabbricante; non una dichiarazione UE generica o un’autorizzazione al marchio CE |
| Fascicolo tecnico | Progettazione, processo, prestazioni, rischi, controlli, istruzioni e allegati | Contenuto tecnico/clinico, evidenze e procedure reali, classificazione corretta |
| Tracciabilità | Materiale/lotto/fornitore e consumo per lavoro, fotografia dei riferimenti nel documento registrato | Completezza dei certificati dei materiali e collegamenti ai fornitori; verifica dei dati reali |
| Qualità e sorveglianza | Registri per NC, azioni, reclami, PMS/PMCF, rapporti e PSUR | Piani e rapporti adeguati alla classe/tipologia; gestione delle scadenze del processo e invio delle segnalazioni dove richiesto |
| Fabbricante | Profilo, sedi, riferimento iscrizione e PRRC | Iscrizione e aggiornamenti al Ministero, qualifica/competenze e procedure; l’app non effettua registrazioni ministeriali |
| Fatture | B2B Italia RF01, TD01/TD04, righe/IVA/natura, copie PDF, preparazione XML FPR12 | Validazione XSD corrente, controlli SDI, verifica IVA/bollo, trasmissione e ricevute, conservazione; nessun servizio fiscale connesso |
| Privacy e sicurezza | Codici paziente, dati locali cifrati, chiave Portachiavi, backup cifrato, blocco manuale macOS | Individuazione dei ruoli e della base giuridica, informative, minimizzazione, accessi, conservazione e valutazione del rischio; nessuna conformità GDPR automatica |
| Conservazione documenti | Archivio e backup senza cancellazione automatica dei registrati, data orientativa nel documento | Policy e prove di recupero periodiche; il backup non equivale alla conservazione fiscale a norma |
| Distribuzione Mac | Eseguibile e pacchetto compilati, firma ad hoc | Developer ID/notarizzazione, prove su hardware/versioni diverse; questo pacchetto è Intel |

## Riferimenti ufficiali consultati

- [Regolamento (UE) 2017/745, testo consolidato](https://eur-lex.europa.eu/legal-content/IT/TXT/?uri=CELEX%3A02017R0745-20250110): articoli 10, 21, 52 e sorveglianza, Allegato XIII per i dispositivi su misura. La dichiarazione ha tempi minimi di conservazione differenti per dispositivi impiantabili e non impiantabili; il software espone il riferimento ma la policy deve essere verificata nel caso concreto.
- [Ministero della Salute: iscrizione elenco fabbricanti su misura](https://www.salute.gov.it/new/it/sistema-informativo/iscrizione-elenco-dei-fabbricanti-dei-dispositivi-medici-su-misura/): registrazione attraverso il servizio ministeriale esterno.
- [Agenzia delle Entrate: guida alla fatturazione elettronica](https://www1.agenziaentrate.gov.it/web_app_entrate/fatturazione_elettronica.html/1000): predisposizione XML, trasmissione e gestione tramite SDI.
- [FatturaPA: tabella ufficiale del formato ordinario](https://www.fatturapa.gov.it/export/documenti/fatturapa/v1.3/Rappresentazione-tabellare-fattura-ordinaria.pdf): riferimento strutturale. Questa tabella non prova la validazione contro l’ultimo schema.
- [Garante Privacy: misure di sicurezza](https://garanteprivacy.it/temi/cybersecurity/misure-di-sicurezza): misure proporzionate al rischio e verifica della loro efficacia.

## Blocco concreto della validazione fiscale

Le pagine e i download correnti dell’Agenzia delle Entrate hanno risposto HTTP 403; il tentativo da browser è stato bloccato dal client. Non è stato possibile acquisire e validare lo schema ufficiale corrente. L’app non mostra quindi un’etichetta di conformità fiscale o una conferma di emissione basata sui soli controlli locali.

Percorso necessario prima dell’uso: ottenere lo schema e le specifiche correnti dall’Agenzia, validare gli esempi del laboratorio, completare i controlli specifici richiesti e collegare/testare il servizio SDI e di conservazione scelto. L’app preparata non ha inviato dati o documenti a servizi esterni.
# Aggiornamento SQLite e Windows

Per i requisiti e limiti della nuova versione vedere [ARCHIVIO-PORTABILE.md](ARCHIVIO-PORTABILE.md), che prevale sulle descrizioni precedenti di persistenza e backup riportate sotto.
