-- =====================================================================
-- Modulo 3 - Sezione 3: Definizione indici - script di esempi
-- =====================================================================

-- =====================================================================
-- 0. Preparazione
-- =====================================================================

SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

DROP TABLE IF EXISTS dbo.demo_SalesOrderDetail, dbo.demo_SalesOrderHeader, dbo.demo_Product, dbo.demo_Address;

SELECT * INTO dbo.demo_SalesOrderDetail FROM Sales.SalesOrderDetail;
CREATE UNIQUE CLUSTERED INDEX PK_demo_SOD ON dbo.demo_SalesOrderDetail (SalesOrderID, SalesOrderDetailID);

SELECT * INTO dbo.demo_SalesOrderHeader FROM Sales.SalesOrderHeader;
CREATE UNIQUE CLUSTERED INDEX PK_demo_SOH ON dbo.demo_SalesOrderHeader (SalesOrderID);

SELECT * INTO dbo.demo_Product FROM Production.Product;
CREATE UNIQUE CLUSTERED INDEX PK_demo_Product ON dbo.demo_Product (ProductID);

SELECT * INTO dbo.demo_Address FROM Person.Address;
CREATE UNIQUE CLUSTERED INDEX PK_demo_Address ON dbo.demo_Address (AddressID);
GO
-- Righe e pagine delle copie (indice clustered = la tabella stessa)
SELECT OBJECT_NAME(object_id) AS tabella, row_count AS righe, in_row_data_page_count AS pagine
FROM sys.dm_db_partition_stats
WHERE object_id IN (OBJECT_ID('dbo.demo_SalesOrderDetail'), OBJECT_ID('dbo.demo_SalesOrderHeader'),
                    OBJECT_ID('dbo.demo_Product'), OBJECT_ID('dbo.demo_Address'))
  AND index_id = 1;
GO

-- =====================================================================
-- 1. A cosa serve un indice 
-- =====================================================================
--
-- Scan contro seek. Confrontare logical reads con il numero di pagine della tabella letto nella cella precedente.

-- Seek senza accesso scan perchè filtro su tutte le colonne della chiave clustered e quindi sa di preciso quale riga restituire
SELECT SalesOrderID, SalesOrderDetailID, ProductID, OrderQty
FROM dbo.demo_SalesOrderDetail
WHERE SalesOrderID = 43659 AND SalesOrderDetailID = 1;

-- Seek: la chiave clustered (SalesOrderID) porta alla riga con poche letture
SELECT SalesOrderID, SalesOrderDetailID, ProductID, OrderQty
FROM dbo.demo_SalesOrderDetail
WHERE SalesOrderID = 43659;

-- Scan: su ProductID non c'e' ancora un indice di supporto -> Clustered Index Scan, tutte le pagine
SELECT SalesOrderID, SalesOrderDetailID, ProductID, OrderQty
FROM dbo.demo_SalesOrderDetail
WHERE ProductID = 707;
GO

-- =====================================================================
-- 2. Struttura B-tree 
-- =====================================================================
--
-- Livelli e pagine dell'albero. Nel DMV index_level = 0 è la foglia; il livello più alto è la root.

-- Profondita' (numero di livelli) degli indici delle copie
SELECT OBJECT_NAME(i.object_id) AS tabella, i.name AS indice, i.type_desc,
       INDEXPROPERTY(i.object_id, i.name, 'IndexDepth') AS livelli
FROM sys.indexes i
WHERE i.object_id IN (OBJECT_ID('dbo.demo_SalesOrderDetail'), OBJECT_ID('dbo.demo_SalesOrderHeader'),
                      OBJECT_ID('dbo.demo_Product'), OBJECT_ID('dbo.demo_Address'))
  AND i.index_id > 0;

-- Pagine per livello: ogni livello ha tante righe quante sono le pagine del livello sotto
SELECT index_level, page_count, record_count, avg_record_size_in_bytes
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.demo_SalesOrderDetail'), 1, NULL, 'DETAILED')
ORDER BY index_level DESC;
GO

-- Root con una sola pagina, pochi livelli intermedi, foglia con le righe. Un seek costa circa quanti livelli ha l'albero.
-- La stessa profondità si ritrova su tabelle molto più grandi 


-- =====================================================================
-- 3. Indice clustered 
-- =====================================================================
--

DROP TABLE IF EXISTS dbo.demo_Vendite;

-- La PK non è obbligatoriamente clustered
CREATE TABLE dbo.demo_Vendite (
    VenditaID  INT IDENTITY NOT NULL,
    OrderDate  DATE NOT NULL,
    Totale     MONEY NOT NULL,
    CONSTRAINT PK_Vendite
        PRIMARY KEY NONCLUSTERED (VenditaID) );

-- Ordine fisico scelto in modo esplicito
CREATE CLUSTERED INDEX IX_Vendite_OrderDate
    ON dbo.demo_Vendite (OrderDate, VenditaID);
GO
INSERT INTO dbo.demo_Vendite (OrderDate, Totale)
SELECT CAST(OrderDate AS date), TotalDue FROM dbo.demo_SalesOrderHeader;

SELECT i.name, i.type_desc, i.is_primary_key, i.is_unique
FROM sys.indexes i WHERE i.object_id = OBJECT_ID('dbo.demo_Vendite');
GO

-- Requisiti della chiave clustered.
--
-- STRETTA E CRESCENTE. Stessi dati e stesso indice non clustered su OrderDate, ma clustered su INT IDENTITY da una parte e su UNIQUEIDENTIFIER casuale (NEWID()) dall'altra. Confrontare le pagine dell'indice non clustered (che porta con sé la chiave clustered)

DROP TABLE IF EXISTS dbo.demo_CluInt, dbo.demo_CluGuid;

CREATE TABLE dbo.demo_CluInt  (ID int IDENTITY NOT NULL, OrderDate date NOT NULL, Totale money NOT NULL,
                               CONSTRAINT PK_demo_CluInt  PRIMARY KEY CLUSTERED (ID));
CREATE TABLE dbo.demo_CluGuid (ID uniqueidentifier NOT NULL CONSTRAINT DF_demo_CluGuid DEFAULT NEWID(), OrderDate date NOT NULL, Totale money NOT NULL,
                               CONSTRAINT PK_demo_CluGuid PRIMARY KEY CLUSTERED (ID));

INSERT INTO dbo.demo_CluInt  (OrderDate, Totale) SELECT OrderDate, Totale FROM dbo.demo_Vendite CROSS JOIN (VALUES (1),(2),(3),(4),(5)) v(n);
INSERT INTO dbo.demo_CluGuid (OrderDate, Totale) SELECT OrderDate, Totale FROM dbo.demo_Vendite CROSS JOIN (VALUES (1),(2),(3),(4),(5)) v(n);

CREATE NONCLUSTERED INDEX IX_demo_CluInt_OrderDate  ON dbo.demo_CluInt  (OrderDate);
CREATE NONCLUSTERED INDEX IX_demo_CluGuid_OrderDate ON dbo.demo_CluGuid (OrderDate);
GO
SELECT OBJECT_NAME(ps.object_id) AS tabella, i.name AS indice, i.type_desc, ps.used_page_count AS pagine,
       CAST(ps.used_page_count * 8 / 1024.0 AS decimal(10,1)) AS MB
FROM sys.dm_db_partition_stats ps
JOIN sys.indexes i ON i.object_id = ps.object_id AND i.index_id = ps.index_id
WHERE ps.object_id IN (OBJECT_ID('dbo.demo_CluInt'), OBJECT_ID('dbo.demo_CluGuid'))
ORDER BY tabella, i.index_id;


-- UNIVOCA Se l'indice clustered non è dichiarato UNIQUE, SQL Server aggiunge ai duplicati un uniquifier interno. 
-- Stesse colonne, stesse righe: cambia solo la dichiarazione.

DROP TABLE IF EXISTS dbo.demo_CluDup, dbo.demo_CluUniq;

CREATE TABLE dbo.demo_CluDup  (ID int NOT NULL, OrderDate date NOT NULL, Totale money NOT NULL);
CREATE TABLE dbo.demo_CluUniq (ID int NOT NULL, OrderDate date NOT NULL, Totale money NOT NULL);

INSERT INTO dbo.demo_CluDup  (ID, OrderDate, Totale) SELECT VenditaID, OrderDate, Totale FROM dbo.demo_Vendite;
INSERT INTO dbo.demo_CluUniq (ID, OrderDate, Totale) SELECT VenditaID, OrderDate, Totale FROM dbo.demo_Vendite;

CREATE CLUSTERED INDEX        IX_demo_CluDup  ON dbo.demo_CluDup  (OrderDate);      -- non univoco: molte righe per data
CREATE UNIQUE CLUSTERED INDEX IX_demo_CluUniq ON dbo.demo_CluUniq (OrderDate, ID);  -- univoco
GO
SELECT OBJECT_NAME(object_id) AS tabella, page_count, avg_record_size_in_bytes
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.demo_CluDup'), 1, NULL, 'DETAILED') WHERE index_level = 0
UNION ALL
SELECT OBJECT_NAME(object_id), page_count, avg_record_size_in_bytes
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.demo_CluUniq'), 1, NULL, 'DETAILED') WHERE index_level = 0;
GO
-- Da osservare: a intuito la seconda riga dovrebbe avere page_count maggiore perchè l'indice ha due colonne e quindi record più lunghi.
-- però nella pratica potrebbe non essere così a causa dell'uniquifier aggiunto dall'indice non univoco.

-- =====================================================================
-- 5. Indice non clustered
-- =====================================================================
--
-- Prima di eseguire la SELECT conviene sapere quante righe ha il valore cercato: nella cella successiva.

-- Quante righe hanno il valore piu' frequente, e quante il valore piu' raro?
SELECT TOP (1) 'piu'' frequente' AS valore, ProductID, COUNT(*) AS righe FROM dbo.demo_SalesOrderDetail GROUP BY ProductID ORDER BY COUNT(*) DESC;
SELECT TOP (1) 'piu'' raro'      AS valore, ProductID, COUNT(*) AS righe FROM dbo.demo_SalesOrderDetail GROUP BY ProductID ORDER BY COUNT(*) ASC, ProductID;


CREATE NONCLUSTERED INDEX IX_SOD_ProductID
    ON dbo.demo_SalesOrderDetail (ProductID);
GO
-- Predicato selettivo: Index Seek ?
SELECT SalesOrderID, OrderQty
FROM dbo.demo_SalesOrderDetail
WHERE ProductID = 870;
GO


SELECT SalesOrderID, OrderQty
FROM dbo.demo_SalesOrderDetail
WHERE ProductID = 807
OPTION (RECOMPILE);   -- il valore della variabile entra nella stima
GO

-- Da osservare: il numero di righe di ProductID = 870 decide il piano. OrderQty non è nell'indice, quindi ogni riga trovata richiede 
--un Key Lookup: con molte righe l'optimizer può preferire lo scan del clustered anche se l'indice esiste (tipping point). Con un prodotto raro compare il seek con lookup.




-- =====================================================================
-- 6. Key lookup e covering index (slide 10)
-- =====================================================================

-- COVERING INDEX: l'indice "copre" tutta la query
CREATE NONCLUSTERED INDEX IX_SOD_ProductID_Cover
    ON dbo.demo_SalesOrderDetail (ProductID)
    INCLUDE (OrderQty);
GO

SELECT ProductID, OrderQty FROM dbo.demo_SalesOrderDetail WHERE ProductID = 807;
SELECT ProductID, OrderQty FROM dbo.demo_SalesOrderDetail WHERE ProductID = 870;
GO

-- Da osservare: con IX_SOD_ProductID_Cover sparisce l'operatore *Key Lookup* per entrambi i valori e il seek su 870 diventa possibile perché il costo del lookup non esiste più (la soglia si sposta in alto: sezione 11).
-- Costo del covering: pagine più larghe (sezione 8).

-- =====================================================================
-- 7. Indici compositi: l'ordine delle colonne (slide 11)
-- =====================================================================
--
-- Indice su (ProductID, ModifiedDate). Le query selezionano solo le due colonne dell'indice, così il piano dipende dalla chiave e non dai lookup.
-- L'hint WITH (INDEX(...)) serve solo a isolare l'indice sotto esame dagli altri indici sulla stessa tabella.
--
-- Nel piano cercare la differenza tra Seek Predicates (usati per posizionarsi nell'albero) e Predicate (valutato riga per riga, residuo), e confrontare Number of Rows Read con Actual Number of Rows.
CREATE NONCLUSTERED INDEX IX_SOD_ProductID_ModifiedDate
    ON dbo.demo_SalesOrderDetail (ProductID, ModifiedDate);
GO
-- 1) Solo la prima colonna: seek efficiente
SELECT ProductID, ModifiedDate FROM dbo.demo_SalesOrderDetail WITH (INDEX(IX_SOD_ProductID_ModifiedDate))
WHERE ProductID = 707;

-- 2) Entrambe le colonne: seek ottimale, due Seek Predicates
SELECT ProductID, ModifiedDate FROM dbo.demo_SalesOrderDetail WITH (INDEX(IX_SOD_ProductID_ModifiedDate))
WHERE ProductID = 707 AND ModifiedDate >= '2013-06-01';

-- 3) Solo la seconda colonna: nessun seek, al massimo scansione dell'indice
SELECT ProductID, ModifiedDate FROM dbo.demo_SalesOrderDetail WITH (INDEX(IX_SOD_ProductID_ModifiedDate))
WHERE ModifiedDate >= '2014-01-01';

-- 4) ORDER BY allineato alla chiave: nessun operatore Sort
SELECT ProductID, ModifiedDate FROM dbo.demo_SalesOrderDetail WITH (INDEX(IX_SOD_ProductID_ModifiedDate))
ORDER BY ProductID, ModifiedDate;

-- 5) ORDER BY sulla seconda colonna: Sort necessario
SELECT ProductID, ModifiedDate FROM dbo.demo_SalesOrderDetail WITH (INDEX(IX_SOD_ProductID_ModifiedDate))
ORDER BY ModifiedDate;
GO

-- Direzione dell'ordinamento. La chiave definisce anche ASC/DESC (default ASC): l'indice si può leggere all'indietro, ma non con direzioni miste.

-- Tutto DESC: scansione all'indietro, nessun Sort
SELECT ProductID, ModifiedDate FROM dbo.demo_SalesOrderDetail WITH (INDEX(IX_SOD_ProductID_ModifiedDate))
ORDER BY ProductID DESC, ModifiedDate DESC;

-- Direzioni miste: Sort necessario
SELECT ProductID, ModifiedDate FROM dbo.demo_SalesOrderDetail WITH (INDEX(IX_SOD_ProductID_ModifiedDate))
ORDER BY ProductID ASC, ModifiedDate DESC;
GO

-- Prima le uguaglianze, poi i range. Stesse due colonne, ordine invertito. Il predicato è ProductID = 707 AND ModifiedDate >= ....

CREATE NONCLUSTERED INDEX IX_SOD_ModifiedDate_ProductID
    ON dbo.demo_SalesOrderDetail (ModifiedDate, ProductID);
GO
-- Ordine corretto: uguaglianza prima, range dopo
SELECT ProductID, ModifiedDate FROM dbo.demo_SalesOrderDetail WITH (INDEX(IX_SOD_ProductID_ModifiedDate))
WHERE ProductID = 707 AND ModifiedDate >= '2013-01-01';

-- Ordine invertito: range prima
SELECT ProductID, ModifiedDate FROM dbo.demo_SalesOrderDetail WITH (INDEX(IX_SOD_ModifiedDate_ProductID))
WHERE ProductID = 707 AND ModifiedDate >= '2013-01-01';
GO

-- Da osservare: nel secondo piano ModifiedDate compare nei *Seek Predicates* e ProductID in *Predicate*; Number of Rows Read è molto più alto delle righe restituite e le letture logiche crescono di conseguenza.


-- =====================================================================
-- 8. Included columns
-- =====================================================================
--
-- Codice della slide su Production.Product (qui demo_Product). La tabella è piccola (poche pagine): l'optimizer può preferire comunque la scansione, quindi confrontare piano e letture usando anche l'hint.

CREATE NONCLUSTERED INDEX IX_Product_SubCat
    ON dbo.demo_Product (ProductSubcategoryID)
    INCLUDE (Name, ListPrice, StandardCost);
GO
-- seek su indice, non serve nessun lookup
SELECT Name, ListPrice, StandardCost
FROM dbo.demo_Product
WHERE ProductSubcategoryID = 1;

-- "A cambio dati restituiti salta l'indice": basta una colonna in piu'
SELECT Name, ListPrice, StandardCost, Color
FROM dbo.demo_Product
WHERE ProductSubcategoryID = 1;

-- Con l'indice forzato si vede il lookup che la seconda query cerca di evitare
SELECT Name, ListPrice, StandardCost, Color
FROM dbo.demo_Product WITH (INDEX(IX_Product_SubCat))
WHERE ProductSubcategoryID = 1;
GO

-- Costo delle colonne incluse. Dimensione di IX_SOD_ProductID (solo chiave) contro IX_SOD_ProductID_Cover (chiave + due colonne incluse) sulla tabella più grande.

SELECT i.name AS indice, ps.used_page_count AS pagine,
       CAST(ps.used_page_count * 8 / 1024.0 AS decimal(10,2)) AS MB
FROM sys.dm_db_partition_stats ps
JOIN sys.indexes i ON i.object_id = ps.object_id AND i.index_id = ps.index_id
WHERE ps.object_id = OBJECT_ID('dbo.demo_SalesOrderDetail') AND i.index_id > 1
ORDER BY pagine;

-- Le colonne incluse esistono solo nella foglia: non servono a cercare
SELECT ProductID, OrderQty, UnitPrice
FROM dbo.demo_SalesOrderDetail WITH (INDEX(IX_SOD_ProductID_Cover))
WHERE OrderQty = 1;      -- nessun seek: OrderQty non e' in chiave
GO

-- =====================================================================
-- 9. Indici filtrati 
-- =====================================================================
--
-- Codice della slide. Attenzione al valore scelto: prima di creare un indice filtrato si guarda la distribuzione del flag, perché l'indice ha senso su un sottoinsieme piccolo.

SELECT OnlineOrderFlag, COUNT(*) AS righe, CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS decimal(5,1)) AS pct
FROM dbo.demo_SalesOrderHeader
GROUP BY OnlineOrderFlag;
GO

-- Con OnlineOrderFlag = 1 l'indice contiene la maggioranza delle righe: meno pagine, meno manutenzione e statistiche più precise valgono poco. La demo segue la slide per mostrare la meccanica; poi si ripete con il valore minoritario (= 0), dove il filtro dà un vantaggio reale.

-- Solo gli ordini online
CREATE NONCLUSTERED INDEX IX_SOH_Online
    ON dbo.demo_SalesOrderHeader (OrderDate)
    INCLUDE (CustomerID, TotalDue)
    WHERE OnlineOrderFlag = 1;
GO
-- Usa l'indice filtrato
SELECT CustomerID, TotalDue
FROM dbo.demo_SalesOrderHeader
WHERE OnlineOrderFlag = 1
  AND OrderDate >= '2013-01-01';

-- NON lo usa: manca il predicato del filtro
SELECT CustomerID, TotalDue
FROM dbo.demo_SalesOrderHeader
WHERE OrderDate >= '2013-01-01';
GO

-- Confronto di dimensione: indice filtrato (maggioranza), filtrato sul sottoinsieme minoritario, indice completo
CREATE NONCLUSTERED INDEX IX_SOH_Offline
    ON dbo.demo_SalesOrderHeader (OrderDate) INCLUDE (CustomerID, TotalDue)
    WHERE OnlineOrderFlag = 0;

CREATE NONCLUSTERED INDEX IX_SOH_OrderDate_Full
    ON dbo.demo_SalesOrderHeader (OrderDate) INCLUDE (CustomerID, TotalDue);
GO
SELECT i.name AS indice, i.has_filter, i.filter_definition, ps.row_count AS righe, ps.used_page_count AS pagine
FROM sys.dm_db_partition_stats ps
JOIN sys.indexes i ON i.object_id = ps.object_id AND i.index_id = ps.index_id
WHERE ps.object_id = OBJECT_ID('dbo.demo_SalesOrderHeader') AND i.index_id > 1
ORDER BY pagine;
GO

-- Query parametriche. Il piano viene compilato senza conoscere il valore del parametro: l'optimizer non può dimostrare che il predicato della query implica quello del filtro, e ignora l'indice filtrato. Con OPTION (RECOMPILE) il valore è noto al momento della compilazione.

-- Il filtro NON e' dimostrabile: variabile o parametro
DECLARE @flag bit = 1;
SELECT CustomerID, TotalDue
FROM dbo.demo_SalesOrderHeader
WHERE OnlineOrderFlag = @flag AND OrderDate >= '2013-01-01';

-- Con RECOMPILE il valore e' incorporato nel piano: l'indice filtrato torna utilizzabile
SELECT CustomerID, TotalDue
FROM dbo.demo_SalesOrderHeader
WHERE OnlineOrderFlag = @flag AND OrderDate >= '2013-01-01'
OPTION (RECOMPILE);

-- Query parametrica vera (sp_executesql)
EXEC sys.sp_executesql
     N'SELECT CustomerID, TotalDue FROM dbo.demo_SalesOrderHeader WHERE OnlineOrderFlag = 1 AND OrderDate >= ''2013-01-01''',
     N'@flag bit', @flag = 1;
GO



-- =====================================================================
-- Selettività e tipping point 
-- =====================================================================
--
-- *Selettività = righe restituite / righe totali (%).* Si ricalcola la tabella della slide sulle copie: valori distinti, righe medie per valore e percentuale.


SELECT 'SalesOrderDetail.ProductID'  AS colonna, COUNT(DISTINCT ProductID)  AS valori_distinti, COUNT(*) * 1.0 / COUNT(DISTINCT ProductID ) as righe_per_valore, 100.0 / COUNT(DISTINCT ProductID) as selettivita
FROM dbo.demo_SalesOrderDetail
UNION ALL
SELECT 'SalesOrderHeader.TerritoryID', COUNT(DISTINCT TerritoryID), COUNT(*) * 1.0 / COUNT(DISTINCT TerritoryID), 100.0 / COUNT(DISTINCT TerritoryID)
FROM dbo.demo_SalesOrderHeader
UNION ALL
SELECT 'SalesOrderHeader.OnlineOrderFlag', COUNT(DISTINCT OnlineOrderFlag), COUNT(*) * 1.0 / COUNT(DISTINCT OnlineOrderFlag), 100.0 / COUNT(DISTINCT OnlineOrderFlag)
FROM dbo.demo_SalesOrderHeader;
GO



-- ### Tipping point
--
-- *Indicativamente tra ¼ e ⅓ delle pagine della tabella, espresso in righe.*

DECLARE @pagine int, @righe int;
SELECT @pagine = in_row_data_page_count, @righe = row_count
FROM sys.dm_db_partition_stats WHERE object_id = OBJECT_ID('dbo.demo_SalesOrderDetail') AND index_id = 1;

SELECT @righe AS righe_tabella, @pagine AS pagine_tabella,
       @pagine / 4 AS soglia_bassa_tipping, @pagine / 3 AS soglia_alta_tipping;


GO




-- =====================================================================
-- 17. Pulizia
-- =====================================================================
--
-- Elimina tutti gli oggetti demo_ creati (tabelle, procedure). Le statistiche e gli indici seguono le tabelle. Se in sezione 10 è stato attivato Query Store, la riga finale (commentata) lo disattiva.

DECLARE @s nvarchar(max) = N'';
SELECT @s += N'DROP PROCEDURE dbo.' + QUOTENAME(name) + N';' FROM sys.procedures WHERE name LIKE 'demo[_]%' AND schema_id = SCHEMA_ID('dbo');
SELECT @s += N'DROP TABLE dbo.'     + QUOTENAME(name) + N';' FROM sys.tables     WHERE name LIKE 'demo[_]%' AND schema_id = SCHEMA_ID('dbo');
EXEC sys.sp_executesql @s;
GO
-- Verifica: deve restituire 0 righe
SELECT name, type_desc FROM sys.objects WHERE name LIKE 'demo[_]%';

-- ALTER DATABASE CURRENT SET QUERY_STORE = OFF;   -- solo se l'avevate attivato per la demo
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
