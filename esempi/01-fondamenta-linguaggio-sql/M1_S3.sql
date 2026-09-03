/*******************************************************************************
 * MODULO 1 — SEZIONE 3: OPERAZIONI DML
 ******************************************************************************/

GO

-- ============================================================================
-- 1. INSERT — SINGOLA RIGA
-- ============================================================================

-- Esempio 1.1: INSERT con lista colonne (corretto)
BEGIN TRAN;

    INSERT INTO Production.ProductCategory
        (Name)
    VALUES
        ('Accessori custom');

    -- Verifico l'inserimento
    SELECT *
    FROM Production.ProductCategory
    WHERE Name = 'Accessori custom';

ROLLBACK;  -- Annullo per non inquinare il database


-- ============================================================================
-- 2. INSERT — RIGHE MULTIPLE
-- ============================================================================

-- Esempio 2.1: Multi-riga con VALUES (max 1.000 righe)
BEGIN TRAN;

    INSERT INTO Production.ProductCategory
        (Name)
    VALUES
        ('Categoria Demo A'),
        ('Categoria Demo B'),
        ('Categoria Demo C');

    SELECT @@ROWCOUNT AS RigheInserite;

    SELECT *
    FROM Production.ProductCategory
    WHERE Name LIKE 'Categoria Demo%';

ROLLBACK;

-- ============================================================================
-- 3. INSERT...SELECT e SELECT INTO
-- ============================================================================

-- Esempio 3.1: INSERT...SELECT — popolare una tabella esistente
-- Prima creo la tabella di destinazione
BEGIN TRAN;

    CREATE TABLE #ProductBackup (
        Name         NVARCHAR(50),
        ListPrice    MONEY,
        Color        NVARCHAR(15)
    );

    INSERT INTO #ProductBackup (Name, ListPrice, Color)
    SELECT Name, ListPrice, Color
    FROM Production.Product
    WHERE ListPrice > 100
      AND Color IS NOT NULL;

    SELECT @@ROWCOUNT AS RigheInserite;
    SELECT TOP 10 * FROM #ProductBackup ORDER BY ListPrice DESC;

    DROP TABLE #ProductBackup;

ROLLBACK;

-- Esempio 3.2: SELECT INTO — crea la tabella al volo
BEGIN TRAN;

    SELECT
        Name,
        ListPrice,
        Color,
        ProductSubcategoryID
    INTO #ProdottiCostosi
    FROM Production.Product
    WHERE ListPrice > 500;

     SELECT @@ROWCOUNT AS RigheInserite;
     SELECT TOP 10 * FROM #ProdottiCostosi ORDER BY ListPrice DESC;

    -- Nota: la tabella NON ha indici ne' vincoli
    EXEC tempdb..sp_help '#ProdottiCostosi';

    DROP TABLE #ProdottiCostosi;

ROLLBACK;

-- ============================================================================
-- 4. BULK INSERT — CARICAMENTO MASSIVO
-- ============================================================================

-- Esempio 4.1: BULK INSERT da file CSV
-- NOTA: per eseguire questo esempio serve un file CSV sul disco.
-- Creiamo prima il file di esempio e la tabella di destinazione.

BEGIN TRAN;

    -- Creo la tabella di staging
    CREATE TABLE #StagingProdotti (
        Nome       NVARCHAR(100),
        Prezzo     DECIMAL(10,2),
        Categoria  NVARCHAR(50)
    );

    -- In un caso reale, il file esiste gia' sul disco.
    -- La sintassi BULK INSERT sarebbe:
    
    BULK INSERT #StagingProdotti
    FROM 'C:\tmp\prodotti.csv'
    WITH (
        FIELDTERMINATOR = ';',      -- separatore colonne
        ROWTERMINATOR   = '\n',     -- separatore righe
        FIRSTROW        = 2         -- salta intestazione
    );
    


    SELECT * FROM #StagingProdotti;
    SELECT @@ROWCOUNT AS RigheCaricate;

    DROP TABLE #StagingProdotti;

ROLLBACK;

-- Esempio 4.2: Opzioni utili di BULK INSERT
/*
-- BATCHSIZE: commit ogni N righe (utile per file enormi)
BULK INSERT dbo.TargetTable
FROM 'C:\Data\big_file.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    FIRSTROW        = 2,
    BATCHSIZE       = 10000,    -- commit ogni 10.000 righe
    TABLOCK
);

-- ERRORFILE: salva le righe rifiutate
BULK INSERT dbo.TargetTable
FROM 'C:\Data\messy_data.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    FIRSTROW        = 2,
    MAXERRORS       = 100,                       -- tollera fino a 100 errori
    ERRORFILE       = 'C:\Data\rejected_rows',   -- righe rifiutate
    TABLOCK
);
*/

-- ============================================================================
-- 5. IDENTITY E SCOPE_IDENTITY()
-- ============================================================================

-- Esempio 4.1: Confronto tra le tre funzioni
BEGIN TRAN;

    INSERT INTO Production.ProductCategory
        (Name)
    VALUES
        ('Test Identity');

    SELECT
        SCOPE_IDENTITY()                          AS [SCOPE_IDENTITY()],
        @@IDENTITY                                AS [@@IDENTITY],
        IDENT_CURRENT('Production.ProductCategory') AS [IDENT_CURRENT];
    -- In assenza di trigger, i tre valori coincidono.
    -- Con trigger su ProductCategory che inserisce in un'altra tabella
    -- con identity, @@IDENTITY restituirebbe l'identity dell'altra tabella!

ROLLBACK;

-- ============================================================================
-- 6. UPDATE — SINTASSI BASE
-- ============================================================================

-- Esempio 12.1: UPDATE semplice con verifica preventiva

-- PASSO 1: verifico cosa tocchero'
SELECT
    ProductID,
    Name,
    ListPrice
FROM Production.Product
WHERE Name = 'HL Road Frame - Black, 58';

-- PASSO 2: eseguo l'UPDATE (in transazione per sicurezza)
BEGIN TRAN;

    UPDATE Production.Product
    SET    ListPrice = 1499.99
    WHERE  Name = 'HL Road Frame - Black, 58';

    SELECT @@ROWCOUNT AS RigheAggiornate;

    -- Verifico il risultato
    SELECT ProductID, Name, ListPrice
    FROM Production.Product
    WHERE Name = 'HL Road Frame - Black, 58';

ROLLBACK;

-- Esempio 12.2: UPDATE di piu' colonne contemporaneamente
BEGIN TRAN;

    UPDATE Production.Product
    SET    ListPrice     = ListPrice * 1.05,
           ModifiedDate  = GETDATE()
    WHERE  ProductSubcategoryID = 1;  -- Mountain Bikes

    SELECT @@ROWCOUNT AS RigheAggiornate;

ROLLBACK;

-- ============================================================================
-- 7. UPDATE CON FROM E JOIN
-- ============================================================================

-- Esempio 12.1: UPDATE con JOIN (sintassi T-SQL proprietaria)
-- Aumenta del 10% il prezzo di tutti i Mountain Bikes

-- Prima verifico con SELECT
SELECT
    p.ProductID,
    p.Name,
    p.ListPrice,
    p.ListPrice * 1.10 AS NuovoPrezzo,
    s.Name AS Sottocategoria
FROM Production.Product p
JOIN Production.ProductSubcategory s
     ON p.ProductSubcategoryID = s.ProductSubcategoryID
WHERE s.Name = 'Mountain Bikes';

-- Poi eseguo
BEGIN TRAN;

    UPDATE p
    SET    p.ListPrice = p.ListPrice * 1.10
    FROM   Production.Product p
    JOIN   Production.ProductSubcategory s
           ON p.ProductSubcategoryID = s.ProductSubcategoryID
    WHERE  s.Name = 'Mountain Bikes';

    SELECT @@ROWCOUNT AS RigheAggiornate;

ROLLBACK;

-- Esempio 12.2: Rischio JOIN con duplicati (DIMOSTRAZIONE)
-- Creo una situazione in cui il JOIN produce duplicati
BEGIN TRAN;

    -- Tabella sorgente con duplicati intenzionali
    CREATE TABLE #PrezziAggiornati (
        ProductID INT,
        NuovoPrezzo MONEY
    );

    INSERT INTO #PrezziAggiornati VALUES (1, 100.00);
    INSERT INTO #PrezziAggiornati VALUES (1, 200.00);  -- Duplicato!

    -- Questo UPDATE e' non deterministico:
    -- quale dei due prezzi verra' usato? 100 o 200?
    UPDATE p
    SET    p.ListPrice = pa.NuovoPrezzo
    FROM   Production.Product p
    JOIN   #PrezziAggiornati pa ON p.ProductID = pa.ProductID;

    -- SQL Server NON da' errore, sceglie una riga a caso!
    SELECT ProductID, Name, ListPrice
    FROM Production.Product
    WHERE ProductID = 1;

    DROP TABLE #PrezziAggiornati;

ROLLBACK;

-- ============================================================================
-- 8. DELETE VS TRUNCATE
-- ============================================================================

-- Esempio 12.1: DELETE con WHERE
BEGIN TRAN;

    -- Prima verifico
    SELECT COUNT(*) AS RighePrimaDelete
    FROM Production.ProductReview;

    DELETE FROM Production.ProductReview
    WHERE Rating < 3;

    SELECT @@ROWCOUNT AS RigheCancellate;

    SELECT COUNT(*) AS RigheDopoDelete
    FROM Production.ProductReview;

ROLLBACK;

-- Esempio 12.2: DELETE vs TRUNCATE su tabella temporanea
BEGIN TRAN;

    SELECT Name, ListPrice
    INTO #TestDelete
    FROM Production.Product;

    SELECT COUNT(*) AS PrimaDiTutto FROM #TestDelete;

    -- DELETE: logga riga per riga, identity NON resettata
    DELETE FROM #TestDelete WHERE ListPrice = 0;
    SELECT @@ROWCOUNT AS RigheEliminate_Delete;

    
     -- TRUNCATE: svuota tutto, resettando identity

    -- TRUNCATE: istantanea, svuota tutto, resetta identity
    TRUNCATE TABLE #TestDelete;
    SELECT COUNT(*) AS DopoTruncate FROM #TestDelete;

    SELECT SCOPE_IDENTITY() AS IdentityDopoTruncate;

    DROP TABLE #TestDelete;

ROLLBACK;

-- ============================================================================
-- 9. DML IN BATCH — PATTERN TOP + WHILE
-- ============================================================================

-- Esempio 12.1: DELETE in batch
-- Simuliamo una pulizia di log su tabella grande
BEGIN TRAN;

    -- Creo una tabella di esempio con molte righe
    SELECT
        ROW_NUMBER() OVER (ORDER BY a.object_id) AS LogID,
        DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 1000, GETDATE()) AS DataLog,
        a.name AS Messaggio
    INTO #LogArchivio
    FROM sys.objects a
    CROSS JOIN sys.objects b;

    SELECT COUNT(*) AS RigheTotali FROM #LogArchivio;

    -- Delete in batch: 1000 righe alla volta
    DECLARE @batch INT = 1;
    DECLARE @totale INT = 0;

    WHILE @batch > 0
    BEGIN
        DELETE TOP (1000)
        FROM #LogArchivio
        WHERE DataLog < DATEADD(YEAR, -1, GETDATE());

        SET @batch = @@ROWCOUNT;
        SET @totale = @totale + @batch;

        -- In produzione, qui si potrebbe aggiungere WAITFOR DELAY
        -- per dare respiro alle altre query
        --WAITFOR DELAY '00:00:01';  -- pausa di 1 secondo (opzionale)
    END;

    PRINT 'Totale righe eliminate: ' + CAST(@totale AS VARCHAR(20));

    SELECT COUNT(*) AS RigheRimaste FROM #LogArchivio;

    DROP TABLE #LogArchivio;

ROLLBACK;

-- ============================================================================
-- 10. OUTPUT — CATTURARE LE RIGHE MODIFICATE
-- ============================================================================

-- Esempio 12.1: INSERT con OUTPUT
BEGIN TRAN;

    INSERT INTO Production.ProductCategory
        (Name)
    OUTPUT
        INSERTED.ProductCategoryID,
        INSERTED.Name,
        INSERTED.ModifiedDate
    VALUES
        ('Categoria Output Demo');

    -- L'OUTPUT restituisce un result set con i dati appena inseriti

ROLLBACK;

-- Esempio 12.2: DELETE con OUTPUT INTO (audit)
BEGIN TRAN;

    -- Tabella di audit
    CREATE TABLE #AuditEliminazioni (
        ProductReviewID INT,
        ProductID       INT,
        ReviewerName    NVARCHAR(50),
        Rating          INT,
        DataEliminazione DATETIME
    );

    DELETE FROM Production.ProductReview
    OUTPUT
        DELETED.ProductReviewID,
        DELETED.ProductID,
        DELETED.ReviewerName,
        DELETED.Rating,
        GETDATE()
    INTO #AuditEliminazioni
    WHERE Rating < 3;

    SELECT * FROM #AuditEliminazioni;

    DROP TABLE #AuditEliminazioni;

ROLLBACK;

-- Esempio 12.3: UPDATE con OUTPUT — prima e dopo
BEGIN TRAN;

    UPDATE Production.Product
    SET    ListPrice = ListPrice * 1.10
    OUTPUT
        INSERTED.ProductID,
        DELETED.ListPrice   AS VecchioPrezzo,
        INSERTED.ListPrice  AS NuovoPrezzo
    WHERE ProductSubcategoryID = 1;  -- Mountain Bikes

ROLLBACK;

-- ============================================================================
-- 11. TRANSAZIONE IMPLICITA VS ESPLICITA
-- ============================================================================

-- Esempio 12.1: Transazione esplicita — trasferimento fondi
-- (simulazione: uso tabelle temporanee)
BEGIN TRAN;

    CREATE TABLE #Saldi (
        ContoID  INT PRIMARY KEY,
        Nome     NVARCHAR(50),
        Importo  MONEY
    );

    INSERT INTO #Saldi VALUES (1, 'Alice', 1000.00);
    INSERT INTO #Saldi VALUES (2, 'Bob',   500.00);

    SELECT 'PRIMA' AS Momento, * FROM #Saldi;

    -- Trasferimento: Alice -> Bob, 200 EUR
    BEGIN TRAN Trasferimento;

        UPDATE #Saldi SET Importo = Importo - 200 WHERE ContoID = 1;
        UPDATE #Saldi SET Importo = Importo + 200 WHERE ContoID = 2;

        -- Verifico
        SELECT 'DOPO' AS Momento, * FROM #Saldi;

        -- Se tutto OK: COMMIT
        -- Se qualcosa non va: ROLLBACK
        COMMIT TRAN Trasferimento;

    DROP TABLE #Saldi;

ROLLBACK;


