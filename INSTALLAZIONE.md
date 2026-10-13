# Installazione DentalLab

## Windows 10/11 x64

Scarica `DentalLab-Setup-Windows-x64.exe`, estrai lo ZIP di GitHub e apri il programma di installazione. Installa per l'utente corrente in `%LOCALAPPDATA%\Programs\DentalLab`, aggiunge DentalLab al menu Start e offre un collegamento sul desktop. Il runtime .NET è incluso: non occorre installarlo separatamente.

Chiudi DentalLab prima di aggiornare. Per la versione portabile precedente, installa con lo stesso account Windows: l'archivio resta in `%LOCALAPPDATA%\DentalLab` e viene riutilizzato. I dati, la chiave locale e la configurazione VPN non vengono inclusi nei file gestiti dall'installer e non vengono rimossi dalla disinstallazione. Una cartella scelta con `--archive` continua a richiedere quel parametro.

## Mac Intel, macOS 13 o successivo

Scarica `DentalLab-Installer-macOS-Intel.pkg`, estrai lo ZIP di GitHub e apri il pacchetto. Installa `DentalLab.app` in Applicazioni. Chiudi l'app prima di aggiornare. Archivio e Portachiavi restano separati dall'app; il pacchetto non esegue script di migrazione o cancellazione dei dati. Su Apple Silicon questa build Intel richiede Rosetta; non è una build nativa ARM.

## Firma e distribuzione

Questi pacchetti di sviluppo non hanno una firma di distribuzione Windows o una firma Developer ID/notarizzazione Apple: il sistema può chiedere conferma o bloccarne l'apertura. Su Mac usa, se disponibile, l'autorizzazione in Impostazioni di Sistema → Privacy e sicurezza dopo aver verificato la provenienza. Le build GitHub includono test del pacchetto, ma non certificano l'installazione su ogni configurazione reale.

Gli installer si scaricano dagli artifact dell'ultima esecuzione riuscita di GitHub Actions, accedendo a GitHub. Il codice aggiornato è nel branch della PR, finché non viene integrato in main.

Per sviluppatori: l'installer Windows si compila con Inno Setup 6 dopo la pubblicazione autonoma .NET. Il pacchetto Mac si genera con `productbuild --component DentalLab.app /Applications DentalLab-Installer-macOS-Intel.pkg`. Le icone PNG, ICO e ICNS derivano dal marchio vettoriale dell'app e si rigenerano con `Tools/make-icons.py` e Pillow.
