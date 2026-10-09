# Interfaccia DentalLab

Mac e Windows condividono una direzione visiva moderna e professionale: navigazione blu notte, superfici chiare, accenti ciano e tipografia leggibile. Le schede arrotondate separano le informazioni; i pulsanti principali hanno una gerarchia distinta e gli elementi selezionati conservano un bordo visibile.

Il richiamo futuristico rimane discreto: gradienti leggeri, marchio vettoriale e, su Mac, una griglia di fondo tenue. Nessuna animazione continua distrae dalla compilazione delle schede. I controlli mantengono navigazione da tastiera e indicatori di focus.

Windows raggruppa informazioni principali, odontogramma e allegati in pannelli scorrevoli. Mac conserva la struttura SwiftUI esistente, con la stessa palette applicata a navigazione, accesso, schede e pulsanti. La disposizione segue i controlli nativi di ciascun sistema.

Le anteprime CI vengono renderizzate dall'applicazione con dati sintetici. Il comando `--preview percorso.png` non apre né modifica l'archivio dell'utente. Le build CI verificano entrambi i sistemi e il trasferimento dei backup nelle due direzioni.

## Organizzazione ispirata ai gestionali di settore

Il confronto del 9 ottobre 2026 usa pagine pubbliche dei produttori, senza accesso alle loro applicazioni o a una demo autenticata:

- [OrisLab Q](https://orisline.com/it/gestione-del-laboratorio-odontotecnico/): produzione, scadenze e collegamenti fra commessa, studio, paziente e documenti. DentalLab mette questi riferimenti nell'elenco e separa operatività, anagrafiche, amministrazione e documentazione.
- [Labnext](https://labnext.dental/features/): gestione del caso dalla ricezione alla consegna. DentalLab rende le fasi selezionabili dalla panoramica e mostra consegne odierne e ritardi.
- [DLCPM](https://help.dlcpm.net/DLCPMOnline/introduction.htm): accesso rapido a commesse, note e dati dello studio. DentalLab avvicina elenco e dettaglio su Windows e mantiene lo studio raggiungibile dalle azioni principali.

Le scelte sono una sintesi originale dei flussi pubblicamente descritti, non una copia dei layout proprietari. Non vengono aggiunti portali cloud, comunicazioni automatiche o funzioni fiscali non implementate.

### Cosa cambia nell'uso quotidiano

Windows apre **Oggi · panoramica**: lavori aperti, consegne odierne, ritardi, fasi di produzione e prossime consegne. La colonna sinistra contiene i moduli; quella centrale ricerca, filtro ed elenco; a destra si apre la scheda. I filtri escludono gli archiviati per impostazione predefinita; Oggi e In ritardo escludono anche i lavori consegnati. Archiviati resta consultabile in sola lettura. Backup, verifica e ripristino sono raccolti in **Archivio e sicurezza**.

Mac aggiunge scorciatoie alla panoramica e filtri separati per fase e data nelle schermate Lavori e Scadenze. Il comando **Azzera filtri** ripristina anche anno, ricerca e visualizzazione degli attivi. Gli elenchi mostrano il riferimento al paziente insieme allo studio.

La data di consegna è confrontata con il giorno locale, senza cambiare le date memorizzate. Il modello SQLite e il formato portabile non cambiano: non è necessaria una nuova migrazione. Otto verifiche sulla vera interfaccia WPF controllano filtri, archiviati, agenda, selezione, sezioni vuote e panoramica usando un archivio sintetico isolato.

### Lavorazione e colore per ogni dente

La mappa mostra solo le due arcate permanenti (32 elementi), senza la classificazione decidua. Su Windows il clic su un dente apre una finestra con lavorazione, scala e codice colore; il numero del dente è fisso. Si possono scegliere lavorazioni predefinite o inserirne una personalizzata. VITA classical offre i codici disponibili; le altre scale accettano un codice libero. Un dente già compilato apre i suoi valori per modificarli. Il riepilogo resta consultabile, con un comando dedicato di modifica.

Su Mac il clic seleziona il dente e carica la sua assegnazione nei controlli sotto la mappa. **Applica al dente** aggiorna quel solo elemento; la selezione multipla rimane disponibile. In entrambi i sistemi occorre salvare la scheda per registrare le modifiche.

Le vecchie assegnazioni decidue restano nei dati e nel riepilogo, nei documenti e nei backup: togliere le arcate dall'interfaccia non cancella informazioni già salvate. Le verifiche aggiuntive controllano la mappa permanente e l'indipendenza delle assegnazioni, insieme alla conservazione dei dati precedenti.

### Direzione visiva futuristica

La testata della schermata usa blu notte e testo chiaro. I pannelli hanno un effetto vetro chiaro ottenuto con gradienti e trasparenza, bordi ciano e una piccola linea ciano/viola. I pulsanti principali sfumano dall'indaco al petrolio; il fondo mostra una griglia tecnica tenue. Il contrasto rimane alto nei campi e nei dati, senza animazioni continue. Il fondo viene disegnato con geometrie vettoriali native, evitando dipendenze da effetti Metal sul Mac e mantenendo invisibili alle interazioni le decorazioni.
