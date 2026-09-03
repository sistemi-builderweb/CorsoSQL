--   ==================================================================
--   Modulo 2 - Sezione 3 - Transazioni e concorrenza
--   ==================================================================

USE AdventureWorks;   -- adatta il nome se la tua copia si chiama diversamente
GO
SET NOCOUNT ON;
GO



--  ==================================================================
--  1 - Transazione esplicita atomica
--  Le due UPDATE devono riuscire entrambe, oppure nessuna. 
--  ==================================================================
SELECT ProductID, LocationID, Quantity
FROM   Production.ProductInventory
WHERE  ProductID IN (1, 2) AND LocationID = 1;

BEGIN TRANSACTION;


    UPDATE Production.ProductInventory
    SET    Quantity = Quantity - 5
    WHERE  ProductID = 1 AND LocationID = 1;

    UPDATE Production.ProductInventory
    SET    Quantity = Quantity + 5
    WHERE  ProductID = 2 AND LocationID = 1;

-- A questo punto le modifiche sono visibili solo a QUESTA transazione.
    SELECT ProductID, LocationID, Quantity
    FROM   Production.ProductInventory
    WHERE  ProductID IN (1, 2) AND LocationID = 1;

ROLLBACK;

-- Verifica: i valori sono di nuovo quelli originali
SELECT ProductID, LocationID, Quantity
FROM   Production.ProductInventory
WHERE  ProductID IN (1, 2) AND LocationID = 1;
GO


--  ==================================================================
--  2 - @@TRANCOUNT e transazioni nidificate
--  Ogni BEGIN aumenta il contatore di 1; ogni COMMIT lo diminuisce,
--  ma solo il COMMIT esterno (contatore a 0) rende permanenti le
--  modifiche; un ROLLBACK (senza nome) azzera il contatore.
--  ==================================================================

BEGIN TRANSACTION;
PRINT 'Dopo BEGIN esterno: ' + CAST(@@TRANCOUNT AS varchar(2));      -- 1

    BEGIN TRANSACTION;
    PRINT 'Dopo BEGIN interno: ' + CAST(@@TRANCOUNT AS varchar(2));  -- 2

    COMMIT TRANSACTION;  -- NON persiste: decrementa soltanto
    PRINT 'Dopo COMMIT interno: ' + CAST(@@TRANCOUNT AS varchar(2)); -- 1

ROLLBACK TRANSACTION;    -- annulla TUTTO, azzera il contatore
PRINT 'Dopo ROLLBACK: ' + CAST(@@TRANCOUNT AS varchar(2));          -- 0
GO


--  ==================================================================
--   3 - SAVEPOINT - rollback parziale
--   SAVE TRANSACTION nome crea un punto di ripristino interno.
--   ROLLBACK TRANSACTION nome annulla solo il lavoro successivo al
--   savepoint, senza chiudere la transazione e senza toccare @@TRANCOUNT.
--  ==================================================================
BEGIN TRANSACTION;
    SELECT Quantity FROM Production.ProductInventory WHERE ProductID = 1 AND LocationID = 1;

    UPDATE Production.ProductInventory
    SET    Quantity = Quantity - 3
    WHERE  ProductID = 1 AND LocationID = 1;     -- modifica A (vogliamo tenerla)

    SAVE TRANSACTION dopo_A;                      -- punto di ripristino

    UPDATE Production.ProductInventory
    SET    Quantity = Quantity - 400
    WHERE  ProductID = 1 AND LocationID = 1;     -- modifica B (vogliamo scartarla)

    ROLLBACK TRANSACTION dopo_A;                  -- annulla solo B, NON A

-- Solo la modifica A risulta applicata dentro la transazione
SELECT Quantity FROM Production.ProductInventory WHERE ProductID = 1 AND LocationID = 1;

ROLLBACK TRANSACTION;  -- chiusura demo: ripristina tutto

SELECT Quantity FROM Production.ProductInventory WHERE ProductID = 1 AND LocationID = 1;


-- ==================================================================
-- 4 - Fenomeni di concorrenza: DIRTY READ (procedura a DUE sessioni)

-- Apri sessione 2 in altra finestra
-- ==================================================================

SELECT ProductID, ListPrice FROM Production.Product WHERE ProductID = 1;

-- SESSIONE 1  (esegui per primo SOLO questo blocco, e NON committare)
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;

UPDATE Production.Product
SET    ListPrice = ListPrice + 1000
WHERE  ProductID = 1;

-- NON eseguire COMMIT/ROLLBACK adesso: passa alla Sessione 2.



-- SESSIONE 1  ROLLBACK per annullare la modifica e ripristinare il prezzo originale
ROLLBACK TRANSACTION;

-- Verifica: il prezzo e' di nuovo quello originale
SELECT ProductID, ListPrice FROM Production.Product WHERE ProductID = 1;
GO

-- ==================================================================
-- 4.1 - Fenomeni di concorrenza: REPEATABLE READ (procedura a DUE sessioni)

-- Apri sessione 2 in altra finestra
-- ==================================================================

-- SESSIONE 1  (esegui per primo SOLO questo blocco, e NON committare)
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
--SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

BEGIN TRANSACTION;

-- prima lettura
SELECT ProductID, ListPrice AS Lettura1
FROM   Production.Product
WHERE  ProductID = 1;      
-- NON committare: passa alla Sessione 2

-- NON eseguire COMMIT/ROLLBACK adesso: passa alla Sessione 2.

-- DOPO UPDATE della Sessione 2, la Sessione 1 riesegue la SELECT: il valore letto non e' lo stesso della prima lettura (NON REPEATABLE READ)
-- Avviene perchè il lock shared della Sessione 1 viene rilasciato dopo la prima lettura, e la Sessione 2 può modificare il dato.
SELECT ProductID, ListPrice AS Lettura2
FROM   Production.Product
WHERE  ProductID = 1;   

-- SESSIONE 1  ROLLBACK per annullare la modifica e ripristinare il prezzo originale
ROLLBACK TRANSACTION;



-- ==================================================================
-- 4.2 - Fenomeni di concorrenza: PHANTOM READ (procedura a DUE sessioni)

-- Apri sessione 2 in altra finestra
-- ==================================================================

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; 
--SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;  
BEGIN TRANSACTION;

-- prima lettura del range
SELECT ProductID, Name, ListPrice
FROM   Production.Product
WHERE  ListPrice BETWEEN 100 AND 200
ORDER  BY ProductID;

-- NON committare: passa alla Sessione 2

-- NON eseguire COMMIT/ROLLBACK adesso: passa alla Sessione 2.

-- DOPO INSERT della Sessione 2, la Sessione 1 riesegue la SELECT: il recordset letto non e' lo stesso della prima lettura e ho in più record inserito in sessione 2 (PHANTOM READ)
-- Avviene perchè il lock shared della Sessione 1 blocca solo le righe lette e non il key-range filtrato, ma non impedisce l'inserimento di nuove righe che soddisfano la condizione della query.
SELECT ProductID, Name, ListPrice
FROM   Production.Product
WHERE  ListPrice BETWEEN 100 AND 200
ORDER  BY ProductID;      -- compare 'Phantom Widget': è il phantom

ROLLBACK

-- ==================================================================
-- 4.3 - Fenomeni di concorrenza: LOST UPDATE (procedura a DUE sessioni)

-- Apri sessione 2 in altra finestra
-- ==================================================================

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
--SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRANSACTION;

SELECT ListPrice AS PrezzoLetto
INTO   #s1
FROM   Production.Product WHERE ProductID = 1;

SELECT * FROM #s1;   -- es. 1000.00

-- NON committare: passa alla Sessione 2

-- NON eseguire COMMIT/ROLLBACK adesso: passa alla Sessione 2.
UPDATE Production.Product
SET    ListPrice = (SELECT PrezzoLetto FROM #s1) + 100   -- 1000 + 100
WHERE  ProductID = 1;

COMMIT TRANSACTION;
DROP TABLE #s1;

SELECT ListPrice FROM Production.Product WHERE ProductID = 1;
-- 1100.00 e non 1150.00: l'aggiornamento della Sessione 2 è andato perso




-- Ripristina valore pre-test
UPDATE Production.Product
SET    ListPrice = 1000
WHERE  ProductID = 1;

/*------------------------------------------------------------------
  6 - Livelli di isolamento a confronto
  SET TRANSACTION ISOLATION LEVEL controlla quali fenomeni sono
  ammessi. Riferimento:

    Livello            | Dirty | Non-rep. | Phantom | Lost update
    -------------------+-------+----------+---------+------------
    READ UNCOMMITTED   |  si   |   si     |   si    |   si
    READ COMMITTED (d) |  no   |   si     |   si    |   si
    REPEATABLE READ    |  no   |   no     |   si    |   no
    SERIALIZABLE       |  no   |   no     |   no    |   no
    SNAPSHOT           |  no   |   no     |   no    |   no (*)

  (*) Sotto SNAPSHOT un lost update non passa in silenzio: viene
      rilevato come conflitto di aggiornamento (errore 3960).

  La query seguente mostra il livello attivo sulla sessione corrente.
------------------------------------------------------------------*/
SELECT CASE transaction_isolation_level
           WHEN 0 THEN 'Unspecified'
           WHEN 1 THEN 'ReadUncommitted'
           WHEN 2 THEN 'ReadCommitted'
           WHEN 3 THEN 'RepeatableRead'
           WHEN 4 THEN 'Serializable'
           WHEN 5 THEN 'Snapshot'
       END AS livello_corrente
FROM sys.dm_exec_sessions
WHERE session_id = @@SPID;
GO


/*------------------------------------------------------------------
  7 - RCSI e SNAPSHOT (versioning)
  Le isolation a versioning fanno si' che i lettori non blocchino
  gli scrittori (e viceversa), leggendo una versione coerente da tempdb.

  ATTENZIONE: le ALTER DATABASE seguenti modificano OPZIONI di
  database; eseguile solo su un'istanza di prova. RCSI richiede che
  non vi siano altre connessioni attive sul database.
  Le righe sono commentate di proposito: decommenta solo su un
  ambiente di test dedicato.
------------------------------------------------------------------*/
-- Abilitare RCSI (richiede sessione esclusiva sul database):
-- ALTER DATABASE AdventureWorks2022 SET READ_COMMITTED_SNAPSHOT ON;

-- Abilitare SNAPSHOT isolation:
-- ALTER DATABASE AdventureWorks2022 SET ALLOW_SNAPSHOT_ISOLATION ON;

-- Esempio d'uso di SNAPSHOT in una transazione (dopo averlo abilitato):
-- SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
-- BEGIN TRANSACTION;
--     SELECT ProductID, ListPrice FROM Production.Product WHERE ProductID = 1;
--     -- ... lavoro coerente con lo snapshot iniziale ...
-- ROLLBACK TRANSACTION;

-- Stato attuale delle opzioni:
SELECT name, is_read_committed_snapshot_on, snapshot_isolation_state_desc
FROM sys.databases WHERE database_id = DB_ID();
GO