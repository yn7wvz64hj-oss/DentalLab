# Disco condiviso tramite VPN

DentalLab può scambiare l'archivio completo cifrato attraverso una cartella del disco di un router, raggiungibile tramite VPN e condivisione file. Non occorre un computer centrale sempre acceso. Ogni postazione mantiene SQLite e gli allegati cifrati localmente; sul disco vengono pubblicati backup portabili e un manifesto dell'ultima versione. Il database SQLite non viene aperto sulla rete.

## Preparazione

1. Collega la VPN e verifica di poter leggere e scrivere nella cartella del disco da entrambe le postazioni. Usa una cartella dedicata a DentalLab.
2. Su Windows il percorso può essere `\\indirizzo-del-router\condivisione\cartella`. Su Mac monta prima la condivisione SMB nel Finder, poi seleziona la sua cartella sotto `/Volumes`.
3. Scegli una password condivisa di almeno 12 caratteri. Deve essere identica sulle postazioni ed è distinta dalla password locale di accesso. Non viene salvata sul disco o nei file di configurazione: si inserisce all'apertura della sessione.
4. Sul computer che contiene l'archivio da condividere, apri **Archivio e sicurezza → Sincronizzazione su disco VPN** su Windows, oppure **Impostazioni → Disco condiviso e sincronizzazione** sul Mac. Se la cartella è vuota viene pubblicato l'archivio corrente.
5. Sull'altra postazione scegli la medesima cartella e password. Il primo collegamento richiede una conferma: la versione sul disco sostituisce quella locale, dopo una copia preventiva completa in `PrimaDelRipristino`. Non unisce archivi diversi. Esporta prima un backup se entrambe le postazioni contengono dati da conservare.

Il percorso della cartella e l'ultima versione utilizzata restano nella configurazione locale della postazione, fuori dal backup portabile. Non includono la password della VPN o quella dell'archivio condiviso.

## Uso quotidiano

Collega la VPN e apri DentalLab. Su Windows la sessione configurata parte dopo l'accesso locale, inserendo la password condivisa; sul Mac si apre la schermata di collegamento. L'app verifica il manifesto, il backup cifrato e gli allegati, e importa un aggiornamento prima di lavorare. Il ripristino conserva una copia preventiva e i progressivi già riservati.

Salva normalmente le schede. Alla chiusura dell'app vengono pubblicati i dati salvati, poi viene rilasciata la prenotazione sul disco. Sul Mac usa **DentalLab → Esci**. Puoi pubblicare durante la sessione dal medesimo comando di sincronizzazione; la prenotazione rimane fino alla chiusura. Solo dopo la chiusura riuscita puoi aprire l'altra postazione. Non è una sincronizzazione in tempo reale e non permette modifiche contemporanee.

Ogni pubblicazione crea un file `.dlbackup` con nome UUID, lo rilegge e verifica, quindi aggiorna atomicamente `dentallab-head.json`. Il manifesto contiene versione, identificativo e SHA-256 del backup, senza nomi dei pazienti. Le copie precedenti non vengono cancellate automaticamente: controlla lo spazio del disco e conserva anche un backup indipendente.

## Interruzioni e conflitti

- Una prenotazione `.dentallab-session`, creata senza sovrascrivere un file esistente, impedisce l'avvio di due sessioni. La prenotazione non scade automaticamente: una VPN interrotta non autorizza un altro computer a prendere il posto del primo.
- Se il disco non è disponibile all'apertura, la postazione configurata non può iniziare una sessione di modifica condivisa. Windows annulla l'apertura; Mac impedisce i salvataggi finché non è collegato. Nessuna nuova cartella remota viene creata automaticamente.
- Se la rete cade durante il lavoro, i salvataggi locali rimangono disponibili. Se la pubblicazione o il rilascio fallisce, la chiusura viene annullata. Ricollega VPN e disco e riprova. Non cancellare la prenotazione mentre una postazione è ancora aperta.
- Se il disco contiene una nuova versione e ci sono anche modifiche locali successive all'ultima sincronizzazione, l'app segnala il conflitto. Non applica merge e non sovrascrive automaticamente nessuno dei due archivi. Esporta le copie da conservare e scegli esplicitamente l'archivio da usare.
- Dopo un crash può rimanere una prenotazione. Chiudi DentalLab su **tutte** le postazioni, conserva un backup delle modifiche locali e verifica la versione condivisa prima di rimuovere manualmente `.dentallab-session`. Non è possibile provare automaticamente che un computer scollegato abbia cessato di lavorare.
- Per una riconfigurazione dopo un conflitto, conserva prima un backup locale; solo dopo aver scelto la versione da importare puoi rimuovere il file locale `sync-state.json` e usare di nuovo la conferma del primo collegamento. Non cancellare SQLite, la chiave locale o gli allegati. Per disattivare la configurazione si può rimuovere `sync-folder.txt` solo a sessione conclusa: eventuali modifiche offline richiederanno una successiva riconciliazione esplicita.

## Limiti e verifiche

La condivisione deve garantire creazione esclusiva e rinomina atomica dei file. La VPN fornisce il collegamento; non modifica questi requisiti del server SMB. Nessuna garanzia di lock globale dopo una rimozione manuale della prenotazione o modifiche esterne ai file. Non pubblicare SMB o FTP direttamente su Internet.

Si applicano i limiti dei backup portabili: 100 MB/allegato, 500 MB complessivi di allegati, 750 MB/file. Ogni pubblicazione è completa, quindi può essere lenta su una VPN. Le operazioni dipendono dai timeout del sistema operativo e possono occupare temporaneamente l'interfaccia. La password condivisa rimane solo nella memoria della sessione.

I test automatici usano cartelle isolate con dati sintetici: esclusione di una seconda postazione, passaggio dei dati, copia preventiva, password errata, conflitti, interruzione della cartella condivisa, errore di pubblicazione e manifesto scomparso. Le build CI provano anche il manifesto e il backup condiviso Windows → Swift → Windows. Questi test non sostituiscono una prova sul disco reale del router: nessuna connessione al disco dell'operatore viene eseguita durante la build.
