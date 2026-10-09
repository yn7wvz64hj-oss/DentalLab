# Archivio locale e trasferimento USB

Questa versione introduce SQLite su macOS e una prima applicazione Windows compatibile con i backup. È una versione di sviluppo: eseguire una prova con dati sintetici e verificare una copia del proprio archivio prima dell'uso operativo.

## Installazione

**Mac:** macOS 13 o successivo, Intel o Apple Silicon. Con Xcode Command Line Tools eseguire `bash compila.sh`, poi `DentalLab.app/Contents/MacOS/DentalLab --self-test`. La compilazione produce un'app per l'architettura del Mac utilizzato; la CI produce Intel. L'app rimane firmata ad hoc, non notarizzata. Copiarla in Applicazioni secondo le istruzioni in LEGGIMI.md. Non disinstallare il Portachiavi o eliminare l'archivio precedente.

**Windows:** Windows 10/11 x64, SDK .NET 8 per compilare. Da questa cartella:

```powershell
dotnet build Windows/DentalLab.Windows/DentalLab.Windows.csproj -c Release
dotnet run --project Windows/DentalLab.Tests/DentalLab.Tests.csproj -c Release
dotnet publish Windows/DentalLab.Windows/DentalLab.Windows.csproj -c Release -r win-x64 --self-contained true -o dist/windows
```

Copiare **tutta** `dist/windows` su disco locale ed eseguire `DentalLab.exe`. La distribuzione autonoma include .NET: non richiede l'SDK sul computer dell'operatore. Il pacchetto non è firmato Authenticode e non comprende installer o aggiornamenti automatici. Gli artifact della CI restano pacchetti di sviluppo, non release certificate.

## Posizione e migrazione dei dati

- Mac: `~/Library/Application Support/DentalLab`.
- Windows: `%LOCALAPPDATA%\DentalLab`.
- SQLite: `archivio.sqlite`, schema fisico 1, modello applicativo 2.
- Una riga `archive` contiene lo snapshot Codable/JSON cifrato AES-256-GCM; `revisions` conserva le ultime 60 revisioni cifrate. Non è SQLCipher: intestazioni e metadati SQLite restano leggibili, il contenuto delle schede è cifrato. Nessun indice con nomi di pazienti in chiaro.
- Allegati: `FileCifrati`, cifrati singolarmente; dopo un ripristino si usa una sottocartella UUID. Le generazioni precedenti rimangono per recuperare le revisioni e non vengono eliminate automaticamente.
- Chiave locale Mac: Portachiavi esistente `it.dentallab.vault.v2`. Windows: `local.key` protetta con DPAPI per l'utente Windows corrente.

Al primo avvio su Mac, se SQLite non esiste, l'app legge `archivio.dlvault` con la chiave originale. Se manca anche questo, importa `archivio.json` e i relativi `Allegati` come in precedenza. SQLite viene pubblicato solo dopo scrittura e verifica di una copia temporanea. I sorgenti precedenti **non vengono cancellati**. Le vecchie copie JSON possono contenere dati in chiaro: la loro eventuale eliminazione va decisa dopo aver verificato il backup.

Non avviare una versione precedente sullo stesso archivio dopo la migrazione: leggerebbe il vecchio `archivio.dlvault`, che non viene più aggiornato. I backup nuovi richiedono questa versione su entrambi i computer. I vecchi backup `DLBACK02` con payload versione 1 sono ancora importabili.

## Un solo computer operativo

È un archivio offline, non un servizio LAN. Il programma impedisce due istanze sul medesimo archivio; Windows usa anche un mutex di macchina. Un blocco si libera all'uscita o al crash, senza dover cancellare manualmente `.lock`.

Due computer offline con copie autonome non possono conoscere lo stato reciproco. **Non è possibile garantire tecnicamente l'esclusione globale di due computer senza un coordinatore condiviso.** Il vincolo operativo è quindi: un solo computer attivo, backup e chiusura prima del passaggio. Non usare SQLite direttamente da USB, cartelle di rete, OneDrive, Dropbox o sincronizzatori. La chiavetta serve a trasportare il backup, non l'archivio in uso.

1. Sul computer attivo salvare le modifiche, scegliere Backup / Esporta, selezionare un file `.dlbackup` sulla USB e una password di almeno 12 caratteri. L'app verifica il contenuto prima di scrivere e rilegge il file dopo la scrittura.
2. Eseguire anche Verifica backup, conservare la password separatamente e chiudere DentalLab.
3. Espellere la USB dal sistema, collegarla al secondo computer e aprire DentalLab.
4. Scegliere Ripristina, inserire la password, controllare la verifica e confermare la sostituzione. Ripetere l'intera procedura per tornare al primo computer.

Il ripristino **sostituisce**, non unisce, i due archivi. Se entrambi sono stati modificati indipendentemente, fermarsi e conservare due backup distinti: non esiste una fusione automatica. I progressivi sul computer ricevente non diminuiscono, ma ciò non impedisce duplicazioni fiscali già avvenute lavorando in parallelo.

## Contenuto e compatibilità

Il backup comprende tutto il modello: pazienti, studi (`Clienti`), lavori, odontogrammi permanenti e decidui, scale e colori, profilo, documenti e righe, stato registrato, pagamenti, magazzino, movimenti, attività, progressivi e tutti gli allegati referenziati. Non comprende file esterni mai allegati né file cifrati orfani. I documenti già generati come PDF/XML sono inclusi solo se allegati a una scheda.

Formato: `DLBACK02` (8 byte), sale casuale (16 byte), nonce AES-GCM (12 byte), ciphertext e tag (16 byte). Chiave derivata dalla password UTF-8 con PBKDF2-HMAC-SHA256, 310000 iterazioni, 32 byte. Dentro il messaggio autenticato: JSON payload 2, `database`, `files` (base64) e `fileHashes` (SHA-256 esadecimale minuscolo). UUID maiuscoli, date in secondi dal 1 gennaio 2001 UTC, importi JSON numerici: compatibili con Codable Swift. Non si convertono date in stringhe o importi in double per riscrivere il modello importato. AES-GCM autentica anche il manifesto e il database.

Windows permette creazione e modifica di pazienti, studi e contatti, lavorazioni, stato, scadenze, odontogrammi, colori e allegati; consulta anche le altre schede e documenti. Conserva campi non esposti dall'editor, righe economiche e importi senza ricostruirli. Fatture e magazzino sono in sola lettura; numerazione/registrazione, incassi, PDF/XML fiscale, conformità avanzata, calendario macOS e Sparkle restano funzioni del Mac. Windows non è ancora una replica completa di tutti i moduli Mac. Le schede registrate o archiviate sono bloccate anche su Windows.

Password giornaliera e collegamento al calendario sono impostazioni del computer ricevente: il ripristino mantiene l'accesso locale e disattiva il collegamento calendario importato. Su un nuovo computer si imposta la propria password di accesso, distinta da quella del backup.

## Verifica e ripristino sicuro

Prima di modificare dati vengono controllati formato, versioni, autenticazione AES-GCM, schede duplicate, progressivi, identificativi allegati, riferimenti, limiti e impronte SHA-256 (payload 2). Verifica backup è utilizzabile senza ripristinare.

Prima del ripristino si crea `PrimaDelRipristino/<UUID>`: copia SQLite tramite l'API backup e copia completa degli allegati e, ove presenti, dei sorgenti legacy. Windows include `local.key`; su Mac la chiave resta nel Portachiavi. Se la copia preventiva fallisce, il ripristino si ferma. Queste copie non vengono eliminate automaticamente e vanno gestite secondo la propria politica di conservazione.

Gli allegati vengono scritti e riletti in una nuova generazione; i loro identificativi logici restano identici, preservando i riferimenti e le impronte dei documenti emessi. Una transazione SQLite pubblica snapshot e generazione insieme. Un errore prima del commit lascia l'archivio attuale invariato e rimuove la generazione parziale. Dopo un crash prima del commit può restare una cartella orfana cifrata, ignorata dal programma. L'hardware o la chiavetta possono comunque guastarsi: conservare più copie verificate.

Per tornare alla copia preventiva, chiudere l'app e copiare l'intero contenuto di quella directory in **una nuova cartella locale**. Windows può aprirla con `DentalLab.exe --archive C:\Percorso\Recupero` usando lo stesso utente Windows. Su Mac conservare l'originale, sostituire la cartella archivio solo ad app chiusa e mantenere la chiave originale nel Portachiavi. Le copie locali non sono portabili a un altro account: per quello usare `.dlbackup` e password. Se manca la chiave locale, non eliminarla o generarne un'altra sull'archivio originale: importare un backup portabile in un archivio nuovo.

## Limiti e validazione

Limiti condivisi: 100 MB per allegato, 500 MB di allegati nel backup, 750 MB per file di backup. Cifratura e serializzazione lavorano in memoria; richiedono spazio libero e RAM e possono bloccare temporaneamente l'interfaccia con archivi grandi. Non c'è SQL normalizzato per paziente: questa migrazione privilegia la conservazione del modello Swift e usa SQLite per atomicità e revisioni. Non sostituisce controlli clinici/fiscali, conservazione a norma, autorizzazioni per ruoli o una strategia di backup dell'organizzazione.

Test locali eseguiti su Windows: build Release dell'app WPF e 34 verifiche del motore, incluse password errata, troncamento, alterazione, manifesti, vecchi backup, blocco seconda istanza, SQLite dopo riavvio, limite revisioni, DPAPI, dati corrotti/chiave assente e interruzioni dopo copia, dopo allegato e prima del commit. Un avviso NuGet `NU1900` indica che in questa sessione non è stato possibile interrogare il servizio degli avvisi di vulnerabilità; non è una verifica di assenza di vulnerabilità.

La CI in `.github/workflows/archive.yml` compila Windows, genera un backup sintetico C#, compila ed esegue tutti gli autotest Swift su Mac Intel, importa il backup Windows e rilegge il backup Swift su Windows. Il completamento della CI è necessario prima di promuovere il cambiamento. In questa sessione non sono stati eseguiti test grafici/manuali delle interfacce né una build Swift locale, perché l'host è Windows.

Riferimenti tecnici: [API backup SQLite](https://www.sqlite.org/backup.html), [DPAPI ProtectedData](https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.protecteddata), [runner GitHub](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
