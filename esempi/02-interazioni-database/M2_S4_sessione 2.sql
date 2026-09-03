-- ================================================================
--  MODULO 2 - SEZIONE 4 | Lock, deadlock e concorrenza avanzata
-- ================================================================



-- ================================================================
--  1. Un lock Exclusive blocca la lettura concorrente
--
--  💡 Con isolation di default (READ COMMITTED) una scrittura non
--     confermata blocca chi vuole leggere la stessa riga.
-- ================================================================

-- >>> SESSIONE B - step 2: prova a leggere la stessa riga -> resta in attesa
SELECT *
FROM dbo.DemoTotale
WHERE SalesOrderID = (SELECT MIN(SalesOrderID) FROM dbo.DemoTotale);

GO




-- ================================================================
--  3 - Riprodurre un deadlock
--
--  💡 Due transazioni che toccano le stesse righe in ordine inverso
--     si bloccano a vicenda: SQL Server termina una VITTIMA (errore 1205).
--     Esegui i passi ALTERNANDO le due sessioni, nell'ordine dei numeri.
-- ================================================================


-- >>> SESSIONE 2 - step 2
BEGIN TRAN;
UPDATE dbo.DemoTotale
SET TotalDue = TotalDue
WHERE SalesOrderID = (SELECT MAX(SalesOrderID) FROM dbo.DemoTotale);   -- riga 2

-- >>> SESSIONE 2 - step 4 (chiude il ciclo -> deadlock rilevato)
UPDATE dbo.DemoTotale
SET TotalDue = TotalDue
WHERE SalesOrderID = (SELECT MIN(SalesOrderID) FROM dbo.DemoTotale);
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
 
PRINT 'Job assegnato sessione 2: ' + CAST(@JobID AS VARCHAR);
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
    @LockTimeout = 5000;
 
IF @ris >= 0
BEGIN
    PRINT 'Lock applicativo ottenuto, elaborazione esclusiva in corso...';
    WAITFOR DELAY '00:00:05';
END
ELSE
    PRINT 'Lock non ottenuto (timeout o errore): ' + CAST(@ris AS VARCHAR);
 
EXEC sp_releaseapplock @Resource = 'DemoImportJob';
COMMIT;
GO
 
