# Corso SQL Server — Esempi e Setup Rapido

Repository con tutti gli esempi (notebook/script SQL) usati nelle sezioni del corso, basati sul database di esempio **AdventureWorks** di Microsoft.

Il setup richiede solo Visual Studio Code e una tua istanza SQL Server locale su cui ripristinare il backup fornito.

## 🚀 Avvio in 3 passi

1. **Installa Visual Studio Code** (se non l'hai già fatto): https://code.visualstudio.com/
   Aprilo una volta installato.

2. **Clona la repo direttamente da dentro VSCode** (non serve terminale né sapere Git):

   **Scorciatoia più veloce:** clicca questo link — se il browser chiede il permesso di aprire VSCode, conferma:
   [👉 Clona CorsoSQL in VSCode](https://vscode.dev/redirect?url=vscode://vscode.git/clone?url=https://github.com/sistemi-builderweb/CorsoSQL.git)
   Si apre VSCode con l'indirizzo della repo già inserito: scegli solo la cartella dove salvarla e, a fine clonazione, clicca **Apri** quando richiesto.

   <details>
   <summary><sub>Se il link non funziona (metodo manuale)</sub></summary>

   - <sub>Premi `Ctrl+Shift+P` (si apre la Command Palette in alto)</sub>
   - <sub>Digita `Git: Clone` e premi Invio</sub>
   - <sub>Se è la prima volta, VSCode potrebbe chiederti di installare Git: segui il link proposto e installa (basta cliccare "Avanti" per tutta l'installazione), poi riavvia VSCode e ripeti questo passo</sub>
   - <sub>Incolla questo indirizzo quando richiesto: `https://github.com/sistemi-builderweb/CorsoSQL.git`</sub>
   - <sub>Scegli una cartella sul tuo PC dove salvarla (es. Desktop o Documenti)</sub>
   - <sub>Quando la clonazione finisce, VSCode chiede "Apri il repository clonato?" → clicca **Apri** (o "Open")</sub>

   </details>

   A questo punto la cartella `CorsoSQL` è aperta in VSCode. Alla prima apertura, VSCode propone da solo l'installazione delle estensioni consigliate (vedi `.vscode/extensions.json`): accetta con un click ("Install All"). Le estensioni sono:
   - **SQL Server (mssql)** — connessione al server ed esecuzione query
   - **MSSQL Scripts and Utilities** — script rapidi di amministrazione/DML
   - **MSSQL Snippets** — snippet T-SQL per scrivere query più in fretta
   - **Poor Man's T-SQL Formatter** — formattazione automatica del codice T-SQL

   
   <sub>In alternativa: apri la scheda Estensioni (`Ctrl+Shift+X`), cerca ciascun nome e clicca "Install".</sub>
   

3. **Ripristina il database sulla tua istanza SQL Server locale**
   Ti verrà fornito il file di backup `AdventureWorks.bak`. Ripristinalo così:
   - In **SSMS** (o dall'estensione mssql di VSCode): tasto destro su *Databases* → *Restore Database* → seleziona il file `.bak` → nel campo *Database* scrivi `AdventureWorks` → OK.
   - Oppure da query, sostituendo i percorsi con i tuoi:
     ```sql
     RESTORE DATABASE AdventureWorks
     FROM DISK = 'C:\percorso\AdventureWorks.bak'
     WITH MOVE 'AdventureWorks2017' TO 'C:\percorso\dati\AdventureWorks.mdf',
          MOVE 'AdventureWorks2017_log' TO 'C:\percorso\dati\AdventureWorks_log.ldf',
          REPLACE;
     ```
     (i nomi logici dopo `MOVE` possono variare in base al backup: prima lancia `RESTORE FILELISTONLY FROM DISK = 'C:\percorso\AdventureWorks.bak'` per vederli ed eventualmente correggerli)

   Con l'estensione mssql installata, apri la Command Palette (`Ctrl+Shift+P`) → `MS SQL: Connect` e inserisci i parametri della tua istanza (server, autenticazione, database `AdventureWorks`).

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

## Note per chi mantiene la repo

Ogni cartella in `esempi/` corrisponde a una sezione del piano didattico e contiene gli script/notebook usati nelle demo delle slide di quella sezione, per garantire linearità tra le presentazioni successive.
