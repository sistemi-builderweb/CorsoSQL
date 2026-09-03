-- ============================================================
-- MODULO 2 - SEZIONE 3 | Tabelle temporanee
-- ============================================================

USE AdventureWorks;
GO

SET NOCOUNT ON;
SET STATISTICS IO, TIME ON;     -- osserva "logical reads" e tempi nei messaggi
GO


-- ============================================================
-- 1. PERCHÉ MATERIALIZZARE UN RISULTATO INTERMEDIO
-- ============================================================
-- Una tabella temporanea "fotografa" un risultato e lo riusa piu' volte
-- senza ricalcolarlo. Utile quando un'aggregazione costosa serve in piu'
-- punti della stessa elaborazione.

PRINT '--- 1. Aggregazione costosa di base ---';
SELECT  sod.ProductID,
        SUM(sod.OrderQty)   AS TotQty,
        SUM(sod.LineTotal)  AS TotFatt,
        COUNT(*)            AS NumRighe
FROM    Sales.SalesOrderDetail AS sod
GROUP BY sod.ProductID;
GO


-- ============================================================
-- 2. TABELLA TEMPORANEA LOCALE  (#temp)
-- ============================================================
-- Vive in tempdb, visibile solo alla sessione che la crea. Eliminata a fine
-- sessione/batch. Supporta statistiche, indici, vincoli e ALTER TABLE.

-- ── 2.1 Creazione esplicita + popolamento ─────────────────────
IF OBJECT_ID('tempdb..#VenditePerProdotto') IS NOT NULL
    DROP TABLE #VenditePerProdotto;

CREATE TABLE #VenditePerProdotto
(
    ProductID  INT   NOT NULL,
    TotQty     INT   NOT NULL,
    TotFatt    MONEY NOT NULL,
    NumRighe   INT   NOT NULL
);

INSERT INTO #VenditePerProdotto (ProductID, TotQty, TotFatt, NumRighe)
SELECT  sod.ProductID, SUM(sod.OrderQty), SUM(sod.LineTotal), COUNT(*)
FROM    Sales.SalesOrderDetail AS sod
GROUP BY sod.ProductID;

-- Ora il risultato si riusa quante volte serve, senza riaggregare
PRINT '--- 2.1 Riuso del risultato materializzato ---';
SELECT  p.Name, v.TotQty, v.TotFatt
FROM    #VenditePerProdotto AS v
JOIN    Production.Product   AS p ON p.ProductID = v.ProductID
WHERE   v.TotQty > 1000
ORDER BY v.TotQty DESC;
GO


-- ============================================================
-- 3. SELECT ... INTO  vs  CREATE TABLE + INSERT
-- ============================================================
-- SELECT INTO crea e popola in un colpo solo, deducendo i tipi dalla query.
-- Comoda e spesso piu' veloce, MA non copia indici, vincoli o default.

-- ── 3.1 SELECT INTO: struttura dedotta automaticamente ────────
IF OBJECT_ID('tempdb..#TopProdotti') IS NOT NULL
    DROP TABLE #TopProdotti;

SELECT  sod.ProductID,
        SUM(sod.OrderQty)  AS TotQty
INTO    #TopProdotti
FROM    Sales.SalesOrderDetail AS sod
GROUP BY sod.ProductID;

-- ── 3.2 CREATE + INSERT: controllo pieno su tipi, PK, default ─
IF OBJECT_ID('tempdb..#TopProdotti2') IS NOT NULL
    DROP TABLE #TopProdotti2;

CREATE TABLE #TopProdotti2
(
    ProductID INT NOT NULL PRIMARY KEY,   -- controllo pieno su tipi e chiave
    TotQty    INT NOT NULL
);
INSERT INTO #TopProdotti2 (ProductID, TotQty)
SELECT sod.ProductID, SUM(sod.OrderQty)
FROM   Sales.SalesOrderDetail AS sod
GROUP BY sod.ProductID;
GO

/* Verifica tabelle create*/
/*'--- 3.3 Colonne ---';*/
SELECT  CASE WHEN t.name LIKE '#TopProdotti2%'
             THEN '#TopProdotti2 (CREATE+INSERT)'
             ELSE '#TopProdotti  (SELECT INTO)'  END AS Tabella,
        c.name        AS Colonna,
        ty.name       AS Tipo,
        c.is_nullable AS Nullable       -- TotQty: 1 con SELECT INTO, 0 con CREATE
FROM    tempdb.sys.tables  AS t
JOIN    tempdb.sys.columns AS c  ON c.object_id     = t.object_id
JOIN    tempdb.sys.types   AS ty ON ty.user_type_id = c.user_type_id
WHERE   t.name LIKE '#TopProdotti%'
ORDER BY Tabella, c.column_id;
 
/*'--- 3.3 Indici e chiavi---'; */
SELECT  CASE WHEN t.name LIKE '#TopProdotti2%'
             THEN '#TopProdotti2 (CREATE+INSERT)'
             ELSE '#TopProdotti  (SELECT INTO)'  END AS Tabella,
        i.type_desc      AS Struttura,   -- HEAP vs CLUSTERED
        i.is_primary_key AS PK
FROM    tempdb.sys.tables  AS t
JOIN    tempdb.sys.indexes AS i ON i.object_id = t.object_id
WHERE   t.name LIKE '#TopProdotti%'
ORDER BY Tabella, i.index_id;

-- ============================================================
-- 4. INDICI E STATISTICHE SU #temp
-- ============================================================
-- Sulle #temp l'optimizer crea e usa statistiche reali: su set grandi un
-- indice mirato trasforma le scansioni successive in seek.

IF OBJECT_ID('tempdb..#OrdiniCliente') IS NOT NULL
    DROP TABLE #OrdiniCliente;

CREATE TABLE #OrdiniCliente
(
    CustomerID   INT   NOT NULL,
    TotaleDovuto MONEY NOT NULL
);

INSERT INTO #OrdiniCliente (CustomerID, TotaleDovuto)
SELECT  soh.CustomerID, SUM(soh.TotalDue)
FROM    Sales.SalesOrderHeader AS soh
GROUP BY soh.CustomerID;

-- 4.1 PRIMA dell'indice: filtro su TotaleDovuto -> scansione dell'heap ──
--      (attiva "Include Actual Execution Plan" con Ctrl+M per vederlo)
SELECT  c.AccountNumber, oc.TotaleDovuto
FROM    #OrdiniCliente AS oc
JOIN    Sales.Customer AS c ON c.CustomerID = oc.CustomerID
WHERE   oc.TotaleDovuto > 50000;
 
-- 4.2 Indice sulla colonna FILTRATA (TotaleDovuto), CustomerID in INCLUDE ──
--      Cosi' l'indice copre anche la colonna del join. Creato DOPO il
--      popolamento: le statistiche nascono gia' complete.
CREATE NONCLUSTERED INDEX IX_OrdiniCliente_Totale
    ON #OrdiniCliente (TotaleDovuto)
    INCLUDE (CustomerID);
 
-- 4.3 DOPO l'indice: stessa query -> Index Seek su IX_OrdiniCliente_Totale ──
--      Il range "TotaleDovuto > 50000" diventa un seek; CustomerID e' coperto,
--      quindi niente key lookup sulla #temp.
SELECT  c.AccountNumber, oc.TotaleDovuto
FROM    #OrdiniCliente AS oc
JOIN    Sales.Customer AS c ON c.CustomerID = oc.CustomerID
WHERE   oc.TotaleDovuto > 50000;
 
GO


-- ============================================================
-- 5. TABELLA TEMPORANEA GLOBALE  (##temp)
-- ============================================================
-- Visibile a TUTTE le sessioni. Esiste finche' la sessione creatrice e' attiva
-- E qualcuno la sta usando. Da usare con parsimonia: nessun isolamento.

IF OBJECT_ID('tempdb..##ReportCondiviso') IS NOT NULL
    DROP TABLE ##ReportCondiviso;

SELECT  soh.SalesPersonID,
        SUM(soh.TotalDue) AS Totale
INTO    ##ReportCondiviso
FROM    Sales.SalesOrderHeader AS soh
WHERE   soh.SalesPersonID IS NOT NULL
GROUP BY soh.SalesPersonID;

-- Un'altra sessione puo' leggere ##ReportCondiviso finche' resta in vita
SELECT * FROM ##ReportCondiviso ORDER BY Totale DESC;

DROP TABLE ##ReportCondiviso;   -- pulizia esplicita consigliata
GO


-- ============================================================
-- 6. VARIABILE TABELLA  (@table)
-- ============================================================
-- Scope limitato al batch/procedura.
-- Vive comunque in tempdb (NON "in memoria"). 
-- Indicizzazione limitata: solo PK/UNIQUE o indici inline. Nessuna statistica.
-- Non viene annullata dal ROLLBACK.

DECLARE @Categorie TABLE
(
    ProductCategoryID INT          NOT NULL PRIMARY KEY,   -- vincolo = indice
    Nome              NVARCHAR(50) NOT NULL,
    INDEX IX_Nome NONCLUSTERED (Nome)                      -- indice inline (2014+)
);

INSERT INTO @Categorie (ProductCategoryID, Nome)
SELECT ProductCategoryID, Name
FROM   Production.ProductCategory;

SELECT * FROM @Categorie ORDER BY Nome;
GO

-- ── 6.1 Le @table sopravvivono al ROLLBACK (utile per logging/audit) ──
DECLARE @Log TABLE (Messaggio NVARCHAR(100), Istante DATETIME2 DEFAULT SYSDATETIME());

BEGIN TRAN;
    INSERT INTO @Log (Messaggio) VALUES (N'Operazione tentata');
ROLLBACK;   -- la transazione torna indietro...

SELECT * FROM @Log;   -- ...ma la riga di log resta!
GO


-- ============================================================
-- 7. QUANDO MATERIALIZZARE: CTE RIUSATA  ->  #temp
-- ============================================================
-- Una CTE NON e' materializzata: ogni riferimento la riesegue. Se
-- un'aggregazione costosa serve piu' volte, calcolarla una sola volta in
-- #temp e' meglio.
SET STATISTICS TIME ON;

-- ── 7.1 PRIMA - la CTE viene espansa e RIESEGUITA a ogni riferimento ──
WITH VenditePerProdotto AS (
    SELECT sod.ProductID, SUM(sod.OrderQty) AS TotOrdini
    FROM   Sales.SalesOrderDetail AS sod
    GROUP BY sod.ProductID
)
SELECT p.Name, vpp.TotOrdini
FROM   VenditePerProdotto AS vpp
JOIN   Production.Product  AS p ON p.ProductID = vpp.ProductID
WHERE  vpp.TotOrdini > (SELECT AVG(TotOrdini) FROM VenditePerProdotto);
-- ^ La sub-aggregazione nella WHERE riesegue di nuovo la CTE.
GO

-- ── 7.2 DOPO - aggrego UNA volta in #temp, poi riuso il risultato ──
IF OBJECT_ID('tempdb..#Vendite') IS NOT NULL DROP TABLE #Vendite;

SELECT sod.ProductID, SUM(sod.OrderQty) AS TotOrdini
INTO   #Vendite
FROM   Sales.SalesOrderDetail AS sod
GROUP BY sod.ProductID;

DECLARE @Media DECIMAL(18,4) = (SELECT AVG(TotOrdini) FROM #Vendite);

SELECT p.Name, v.TotOrdini
FROM   #Vendite          AS v
JOIN   Production.Product AS p ON p.ProductID = v.ProductID
WHERE  v.TotOrdini > @Media;
GO



SET STATISTICS IO, TIME OFF;
GO
-- ============================================================
-- FINE - Sezione 3 - Tabelle temporanee
-- ============================================================