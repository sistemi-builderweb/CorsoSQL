# Corso SQL Server — Esempi e Setup Rapido

Repository con tutti gli esempi (notebook/script SQL) usati nelle sezioni del corso, basati sul database di esempio **AdventureWorks** di Microsoft.

Il setup richiede solo Visual Studio Code e una tua istanza SQL Server locale su cui ripristinare il backup fornito.

## 🚀 Avvio in 5 passi

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

   A questo punto la cartella `CorsoSQL` è aperta in VSCode. Installa queste 4 estensioni (se VSCode ti propone da solo un popup "Install All" / "Show Recommendations" in basso a destra, puoi usare quello — ma non sempre     compare, quindi installale così):
   - Apri il pannello Estensioni: `Ctrl+Shift+X`
   - In cima alla lista, sotto "WORKSPACE RECOMMENDATIONS", vedrai le 4 estensioni consigliate per questa repo: clicca **Install** su ciascuna
   - Se quella sezione non appare, cerca ciascun nome nella casella di ricerca in alto e clicca **Install**:
      - **SQL Server (mssql)** — connessione al server ed esecuzione query
      - **MSSQL Scripts and Utilities** — script rapidi di amministrazione/DML
      - **MSSQL Snippets** — snippet T-SQL per scrivere query più in fretta
      - **Poor Man's T-SQL Formatter** — formattazione automatica del codice T-SQL

   
   <sub>In alternativa: apri la scheda Estensioni (`Ctrl+Shift+X`), cerca ciascun nome e clicca "Install".</sub>
   

3. Creazione istanza locale SQL Server per ospitare db di test
   - Scarica [SQL Server Express (gratuito)](https://go.microsoft.com/fwlink/p/?linkid=2216019&clcid=0x409&culture=en-us&country=us)
   - Avvia il setup e scegli l'installazione "Basic": accetta i valori proposti di default
   - A fine installazione annota il nome dell'istanza mostrato a schermo (di solito NOMEPC\SQLEXPRESS): ti servirà per connetterti da VSCode
   - Non serve installare SSMS: da qui in poi puoi fare tutto da VSCode con l'estensione mssql

4. **Ripristina il database sulla tua istanza SQL Server locale**
   - Connettiti alla tua istanza: Ctrl+Shift+P → MS SQL: Connect
   - Nell'Object Explorer (icona database a sinistra), tasto destro su Databases → Restore Database 
   - Scegli "From backup file", seleziona il file AdventureWorks.bak (estratto dallo zip)
   - Verifica che il nome database sia **AdventureWorks** → clicca Restore

5. **Esegui script di verifica**
   - Tasto dx su database AdventureWorks, seleziona "Nuova query"
   - Esegui `scripts/verify-setup.sql` sulla connessione: se la query restituisce righe con conteggi > 0, la connessione e il database sono a posto.

## 🚀 Utilizzo script di test
   - Nell'Object Explorer (icona database a sinistra), 'Explorer'
   - Aprendo cartella 'scripts' della repository è possibile eseguire gli script di test
   - Alla prima esecuzione chiederà di connettersi al database di test e occorre selezionare AdventureWorks
   
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
