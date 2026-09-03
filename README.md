# Corso SQL Server — Esempi e Setup Rapido

Repository con tutti gli esempi (notebook/script SQL) usati nelle sezioni del corso, basati sul database di esempio **AdventureWorks** di Microsoft.

## 🚀 Avvio in 3 passi

1. **Installa Visual Studio Code** (se non già presente): https://code.visualstudio.com/

2. **Apri la cartella in VSCode**
   Alla prima apertura VSCode propone da solo l'installazione delle estensioni consigliate (vedi `.vscode/extensions.json`): accetta con un click ("Install All"). Le estensioni sono:
   - **SQL Server (mssql)** — connessione al server ed esecuzione query
   - **MSSQL Scripts and Utilities** — script rapidi di amministrazione/DML
   - **MSSQL Snippets** — snippet T-SQL per scrivere query più in fretta
   - **Poor Man's T-SQL Formatter** — formattazione automatica del codice T-SQL

   In alternativa: apri la scheda Estensioni (`Ctrl+Shift+X`), cerca ciascun nome e clicca "Install".

3. **Collega la tua istanza SQL Server**
   Scarica backup db da cartella specifica e fai restore con nome AdventureWorks su istanza locale
   - Backup ufficiale Microsoft: https://learn.microsoft.com/en-us/sql/samples/adventureworks-install-configure
   - Scarica il file `AdventureWorks2019.bak`
   - Ripristinalo con SSMS (tasto destro su *Databases* → *Restore Database*) oppure da riga di comando:
     ```sql
     RESTORE DATABASE AdventureWorks2019
     FROM DISK = 'C:\percorso\AdventureWorks2019.bak'
     WITH MOVE 'AdventureWorks2017' TO 'C:\percorso\dati\AdventureWorks2019.mdf',
          MOVE 'AdventureWorks2017_log' TO 'C:\percorso\dati\AdventureWorks2019_log.ldf';
     ```
     (i nomi logici dei file dentro il `.bak` possono variare: usa prima `RESTORE FILELISTONLY FROM DISK = '...'` per verificarli)

   Con l'estensione mssql installata, apri la Command Palette (`Ctrl+Shift+P`) → `MS SQL: Connect` e inserisci i parametri della tua istanza (server, autenticazione, database `AdventureWorks2019`).

   Poi esegui `scripts/verify-setup.sql` sulla connessione: se la query restituisce righe con conteggi > 0, la connessione e il database sono a posto.

## Struttura repository

```
esempi/
  01-fondamenta-linguaggio-sql/
  02-interazioni-database/
  03-ddl-struttura-database/
  ...              ← una cartella per sezione, allineata al piano didattico
scripts/
  verify-setup.sql            ← query di controllo per verificare connessione e dati
docs/
  ...                         ← eventuali note aggiuntive per l'auto-approfondimento
.vscode/extensions.json       ← estensioni consigliate (mssql e plugin correlati)
```

## Per approfondire in autonomia

Il database completo **AdventureWorks2019** (OLTP) può essere scaricato anche manualmente dai backup ufficiali Microsoft:
https://learn.microsoft.com/en-us/sql/samples/adventureworks-install-configure

Lo script `scripts/restore-adventureworks.sh` lo fa già in automatico, ma sapere dove trovarlo manualmente è utile se vuoi provare anche altre versioni (es. AdventureWorksDW per esempi di reporting/analytics).

## Note per chi mantiene la repo

Ogni cartella in `esempi/` corrisponde a una sezione del piano didattico e contiene gli script/notebook usati nelle demo delle slide di quella sezione, per garantire linearità tra le presentazioni successive.
