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
