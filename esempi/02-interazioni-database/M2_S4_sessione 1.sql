-- ================================================================
--  MODULO 2 - SEZIONE 4 | Lock, deadlock e concorrenza avanzata
-- ================================================================


-- ================================================================
--  SETUP - Contesto database e tabella di lavoro
-- ================================================================
USE AdventureWorks;
GO

-- Verifica connessione: deve restituire le righe delle tabelle principali
SELECT 'Production.Product'      AS Tabella, COUNT(*) AS Righe FROM Production.Product
UNION ALL SELECT 'Sales.SalesOrderHeader',            COUNT(*) FROM Sales.SalesOrderHeader
UNION ALL SELECT 'Sales.SalesOrderDetail',            COUNT(*) FROM Sales.SalesOrderDetail;
GO

-- Tabella di appoggio per test
DROP TABLE IF EXISTS dbo.DemoTotale;

GO


SELECT TOP (8000) SalesOrderID, OrderDate, TotalDue
INTO dbo.DemoTotale
FROM Sales.SalesOrderHeader
WHERE TotalDue > 0;
GO

ALTER TABLE dbo.DemoTotale ADD CONSTRAINT PK_DemoTotale PRIMARY KEY (SalesOrderID);
GO

SELECT * FROM dbo.DemoTotale;
GO
-- Risultato atteso: 8000 righe (i primi 8000 ordini con importo totale > 0)


-- ================================================================
--  1. Un lock Exclusive blocca la lettura concorrente
--
--  💡 Con isolation di default (READ COMMITTED) una scrittura non
--     confermata blocca chi vuole leggere la stessa riga.
-- ================================================================

-- >>> SESSIONE 1 - step 1: apre la transazione e tiene un lock X sulla riga
BEGIN TRAN
UPDATE dbo.DemoTotale
SET TotalDue = TotalDue + 1
OUTPUT inserted.SalesOrderID
WHERE SalesOrderID = (SELECT MIN(SalesOrderID) FROM dbo.DemoTotale);

-- NON fare COMMIT: passa alla Sessione 2


-- >>> SESSIONE 1 - step 3: sblocca la Sessione 2
COMMIT;
GO

SELECT name, is_read_committed_snapshot_on
FROM sys.databases
WHERE name = 'AdventureWorks';

-- attivazione RCSI
alter database adventureworks SET SINGLE_USER WITH ROLLBACK IMMEDIATE
alter database adventureworks set read_committed_snapshot ON;
alter database adventureworks SET MULTI_USER;


-- disattivazione RCSI
alter database adventureworks SET SINGLE_USER WITH ROLLBACK IMMEDIATE
alter database adventureworks set read_committed_snapshot OFF;
alter database adventureworks SET MULTI_USER;


-- ================================================================
--  2 - Lock escalation
--
--  💡 Oltre ~5.000 lock sulla stessa istruzione, SQL Server converte
--     i lock di riga/pagina in un unico lock di TABELLA.
-- ================================================================

-- >>> SESSIONE 1: UPDATE che tocca tutte le righe (forza il comportamento)
BEGIN TRAN;
UPDATE dbo.DemoTotale
SET TotalDue = TotalDue;   -- su una tabella grande il lock diventa OBJECT (X)

UPDATE Production.Product
SET ListPrice = ListPrice;  -- su una tabella piccola sceglie lock più granulare

ROLLBACK;



-- ================================================================
--  3 - Riprodurre un deadlock
--
--  💡 Due transazioni che toccano le stesse righe in ordine inverso
--     si bloccano a vicenda: SQL Server termina una VITTIMA (errore 1205).
--     Esegui i passi ALTERNANDO le due sessioni, nell'ordine dei numeri.
-- ================================================================

-- >>> SESSIONE 1 - step 1
BEGIN TRAN;
UPDATE dbo.DemoTotale
SET TotalDue = TotalDue
WHERE SalesOrderID = (SELECT MIN(SalesOrderID) FROM dbo.DemoTotale);   -- riga 1


-- >>> SESSIONE 1 - step 3 (resta in attesa della riga 2)
UPDATE dbo.DemoTotale
SET TotalDue = TotalDue
WHERE SalesOrderID = (SELECT MAX(SalesOrderID) FROM dbo.DemoTotale);


-- Una delle due sessioni riceve:
--   Msg 1205 ... chosen as the deadlock victim. Rerun the transaction.

-- >>> Nella sessione sopravvissuta:
COMMIT;
-- La vittima e' gia' stata annullata da SQL Server (rollback automatico).
GO




-- ================================================================
--  PULIZIA
-- ================================================================
DROP TABLE IF EXISTS dbo.DemoTotale;
GO




-- ================================================================
-- 4. PREPARAZIONE: TABELLA DI CODA DI ESEMPIO
-- Una coda di "ordini da elaborare", popolata da AdventureWorks.
-- ================================================================
DROP TABLE IF EXISTS dbo.DemoJobs;
GO
 
CREATE TABLE dbo.DemoJobs (
    JobID               INT IDENTITY PRIMARY KEY,
    SalesOrderID        INT NOT NULL,
    Stato               VARCHAR(20) NOT NULL DEFAULT ('In attesa'),
    PresoInCaricoDa     SYSNAME NULL,
    DataPresaInCarico   DATETIME2 NULL
);
GO
 
INSERT INTO dbo.DemoJobs (SalesOrderID)
SELECT TOP (200) SalesOrderID
FROM Sales.SalesOrderHeader
ORDER BY SalesOrderID;
GO
 
 
-- ================================================================
-- 4.1 PATTERN NON SICURO (race condition)
-- Eseguire questo blocco da due sessioni quasi in contemporanea:
-- è frequente vedere lo stesso JobID assegnato a entrambe.
-- ================================================================
DECLARE @JobID INT;
 
SELECT TOP (1) @JobID = JobID
FROM dbo.DemoJobs
WHERE Stato = 'In attesa';
 
-- finestra di rischio: qui un'altra sessione puo' leggere lo stesso JobID
WAITFOR DELAY '00:00:05';
 
UPDATE dbo.DemoJobs
SET Stato = 'In lavorazione', PresoInCaricoDa = SUSER_SNAME(), DataPresaInCarico = SYSDATETIME()
WHERE JobID = @JobID;
 
PRINT 'Job assegnato sessione 1: ' + CAST(@JobID AS VARCHAR);
GO
 
 
-- Reset della coda prima della prossima demo
UPDATE dbo.DemoJobs SET Stato = 'In attesa', PresoInCaricoDa = NULL, DataPresaInCarico = NULL;
GO
 
 
-- ================================================================
-- 4.2 READPAST + UPDLOCK + ROWLOCK
-- [SESSIONE 1] e [SESSIONE 2]: eseguire questo blocco in entrambe,
-- quasi in contemporanea. Ogni sessione deve prendere un JobID diverso
-- invece di restare in attesa.
-- ================================================================
BEGIN TRAN;
 
DECLARE @JobID INT;
SELECT TOP (1) @JobID = JobID
FROM dbo.DemoJobs WITH (UPDLOCK, ROWLOCK, READPAST)
WHERE Stato = 'In attesa'
ORDER BY JobID;
 
PRINT 'Job preso in carico: ' + CAST(@JobID AS VARCHAR);
WAITFOR DELAY '00:00:05';  -- tempo per osservare l'altra sessione
 
UPDATE dbo.DemoJobs
SET Stato = 'In lavorazione', PresoInCaricoDa = SUSER_SNAME(), DataPresaInCarico = SYSDATETIME()
WHERE JobID = @JobID;
 
COMMIT;
GO
 
 
-- Reset della coda
UPDATE dbo.DemoJobs SET Stato = 'In attesa', PresoInCaricoDa = NULL, DataPresaInCarico = NULL;
GO
 
 
-- ================================================================
-- 5. UPDATE ... OUTPUT (dequeue atomico in una sola istruzione)
-- ================================================================
;WITH ProssimoJob AS (
    SELECT TOP (1) *
    FROM dbo.DemoJobs WITH (READPAST)
    WHERE Stato = 'In attesa'
    ORDER BY JobID
)
UPDATE ProssimoJob
SET Stato = 'In lavorazione', PresoInCaricoDa = SUSER_SNAME(), DataPresaInCarico = SYSDATETIME()
OUTPUT inserted.JobID, inserted.SalesOrderID, inserted.DataPresaInCarico;
GO
 
 
-- ================================================================
-- 6. sp_getapplock: lock applicativo (sincronizzare processi, non righe)
-- [SESSIONE 1] e [SESSIONE 2]: eseguire in entrambe quasi in contemporanea.
-- La seconda sessione deve attendere fino al timeout o al rilascio.
-- ================================================================
BEGIN TRAN;
 
DECLARE @ris INT;
EXEC @ris = sp_getapplock
    @Resource = 'DemoImportJob',
    @LockMode = 'Exclusive',
    @LockTimeout = 10000;
 
IF @ris >= 0
BEGIN
    PRINT 'Lock applicativo ottenuto, elaborazione esclusiva in corso...';
    WAITFOR DELAY '00:00:10';
END
ELSE
    PRINT 'Lock non ottenuto (timeout o errore): ' + CAST(@ris AS VARCHAR);
 
EXEC sp_releaseapplock @Resource = 'DemoImportJob';
COMMIT;
GO
 
 
--PULIZIA (eseguire a fine demo)
 DROP TABLE IF EXISTS dbo.DemoJobs;
GO
 
