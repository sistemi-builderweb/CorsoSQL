-- ════════════════════════════════════════════════════════════
--  Modulo 1 · Sezione 1 — Anatomia di una SELECT
-- ════════════════════════════════════════════════════════════

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.4       Alias di SELECT non disponibile in WHERE  ║
-- ╚══════════════════════════════════════════════════════════════╝
-- 💡 Commenta questo blocco e passa alla cella successiva per la versione corretta
--

-- ❌ Questo fallisce: 'Totale' non esiste ancora quando WHERE viene valutato
SELECT
    TotalDue AS Totale
FROM Sales.SalesOrderHeader
WHERE Totale > 1000;       -- Msg 207: Invalid column name 'Totale'

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.4       Alias di SELECT — versione corretta       ║
-- ╚══════════════════════════════════════════════════════════════╝
-- 💡 TotalDue nel WHERE, Totale come alias solo per la visualizzazione
--
-- ✅ Usa il nome originale della colonna nel WHERE
SELECT
    SalesOrderID,
    TotalDue        AS Totale,
    OrderDate       AS DataOrdine
FROM Sales.SalesOrderHeader
WHERE TotalDue > 1000          -- nome colonna originale
ORDER BY TotalDue DESC;

GO

-- ╔════════════════════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.4       Ordine di esecuzione — osservazione pratica con GROUP BY║
-- ╚════════════════════════════════════════════════════════════════════════════╝
-- 💡 ORDER BY è l'unica clausola che può usare gli alias di SELECT
--

-- L'alias di SELECT non è disponibile nel GROUP BY.
-- L'alias NON è disponibile in HAVING per le stesse ragioni.

-- ❌ Non funziona: 'Anno' è un alias di SELECT
SELECT YEAR(OrderDate) AS Anno, COUNT(*) AS N
FROM Sales.SalesOrderHeader
GROUP BY Anno;    -- errore

-- ✅ Ripeti l'espressione nel GROUP BY
SELECT
    YEAR(OrderDate)  AS Anno,
    COUNT(*)         AS NumOrdini
FROM Sales.SalesOrderHeader
GROUP BY YEAR(OrderDate)       -- stesso YEAR(), non l'alias
ORDER BY Anno;                 -- qui invece l'alias è disponibile 

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.5       SELECT * vs colonne esplicite             ║
-- ╚══════════════════════════════════════════════════════════════╝


-- ✅ Solo le colonne necessarie
-- L'optimizer può usare un indice su (Name, ListPrice, Color)
-- senza tornare alla riga base (key lookup)
SELECT
    p.Name          AS Prodotto,
    p.ListPrice     AS PrezzoListino,
    p.Color         AS Colore
FROM Production.Product p
WHERE p.ListPrice > 0
ORDER BY p.ListPrice DESC;

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.6       Operatori di confronto e logici           ║
-- ╚══════════════════════════════════════════════════════════════╝

-- Operatori base: =  <>  <  >  <=  >=  AND  OR  NOT
SELECT Name, ListPrice, Color
FROM Production.Product
WHERE ListPrice >= 500
  AND ListPrice <= 2000
  AND Color IS NOT NULL
ORDER BY ListPrice;

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.6       IN vs OR — leggibilità                    ║
-- ╚══════════════════════════════════════════════════════════════╝
-- 💡 L'optimizer trasforma IN in una serie di OR internamente — il piano è identico
--

-- IN è equivalente a più OR, ma più leggibile

-- Equivalenti — stesso piano di esecuzione
SELECT Name, Color, ListPrice
FROM Production.Product
WHERE Color IN ('Red', 'Blue', 'Black')
  AND ListPrice > 500;

-- Stesso risultato, meno leggibile
-- WHERE (Color = 'Red' OR Color = 'Blue' OR Color = 'Black')
--   AND ListPrice > 500

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.6       BETWEEN su numeri e su date               ║
-- ╚══════════════════════════════════════════════════════════════╝
--

-- BETWEEN è inclusivo su entrambi i lati: >= a AND <= b

-- Su numeri
SELECT Name, ListPrice
FROM Production.Product
WHERE ListPrice BETWEEN 500 AND 1500;

-- Su date: attenzione al tipo datetime
-- BETWEEN '2013-12-31' AND '2013-12-31' con tipo datetime
-- include solo le 00:00:00 del 31, non il resto del giorno
-- Preferisci il range esplicito per le date:
SELECT SalesOrderID, OrderDate, TotalDue
FROM Sales.SalesOrderHeader
WHERE OrderDate >= '2013-12-01'
  AND OrderDate <  '2014-01-01';   -- esclude il 1° gennaio, include tutto dicembre

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.6       LIKE — sargable e non sargable            ║
-- ╚══════════════════════════════════════════════════════════════╝
-- 💡 Attivare il piano di esecuzione effettivo mentre esegui
--

-- ✅ Sargable: pattern senza % iniziale — usa l'indice su Name
SELECT Name, ListPrice
FROM Production.Product
WHERE Name LIKE 'Chain%';

-- ❌ Non sargable: % iniziale — full scan su tutta la tabella
SELECT Name, ListPrice
FROM Production.Product
WHERE Name LIKE '%Chain%';

-- Verifica la differenza: esegui entrambe con il piano di esecuzione attivo
-- La prima mostra Index Seek, la seconda Index Scan o Table Scan

GO

-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.6      Gestione delle precedenze: AND prima di OR  ║
-- ╚═══════════════════════════════════════════════════════════════╝
-- 💡 Conta le righe restituite dalle tre query: la prima ne restituisce di più 
--

-- ❌ AND ha precedenza su OR: risultato diverso da quello atteso
-- Leggi come: Color='Red' OR (Color='Blue' AND ListPrice>500)
-- I prodotti rossi passano a qualsiasi prezzo
SELECT Name, Color, ListPrice
FROM Production.Product
WHERE  Color = 'Red'
    OR Color = 'Blue'
   AND ListPrice > 500;

-- ✅ Parentesi esplicite: comportamento corretto
SELECT Name, Color, ListPrice
FROM Production.Product
WHERE (Color = 'Red' OR Color = 'Blue')
  AND ListPrice > 500;

-- ✅ Con IN: ancora più leggibile
SELECT Name, Color, ListPrice
FROM Production.Product
WHERE Color IN ('Red', 'Blue')
  AND ListPrice > 500;

GO

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.8      Confronto diretto: sargable vs non sargable su date║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- 💡 Su poche righe la differenza è già percettibile. Su milioni di righe può essere di secondi vs millisecondi
--

-- ❌ NON SARGABLE: YEAR() sulla colonna impedisce l'uso dell'indice
-- SQL Server calcola YEAR() per ogni riga e poi confronta
SELECT COUNT(*) AS OrdiniNonSargable
FROM Sales.SalesOrderHeaderEnlarged
WHERE YEAR(OrderDate) = 2013;

-- ✅ SARGABLE: range esplicito — SQL naviga direttamente l'indice su OrderDate
SELECT COUNT(*) AS OrdiniSargable
FROM Sales.SalesOrderHeaderEnlarged
WHERE OrderDate >= '2013-01-01'
  AND OrderDate <  '2014-01-01';

-- Stesso risultato, piano molto diverso.
-- Esegui e confronta: Seek vs Scan, costo I/O

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.8       Espressione sulla colonna — non sargable  ║
-- ╚══════════════════════════════════════════════════════════════╝
-- 💡 Principio generale: la trasformazione va sul lato del parametro, mai sulla colonna
--

-- ❌ NON SARGABLE: espressione su ListPrice
SELECT Name, ListPrice
FROM Production.Product 
WHERE ListPrice * 1.22 > 610;   

-- ✅ SARGABLE: sposta il calcolo sul parametro
SELECT Name, ListPrice
FROM Production.Product 
WHERE ListPrice > 610 / 1.22;   -- stesso risultato, colonna non trasformata

-- ✅ Ancora più chiaro con una variabile
DECLARE @prezzoNetto DECIMAL(10,2) = 610.0 / 1.22;
SELECT Name, ListPrice
FROM Production.Product
WHERE ListPrice > @prezzoNetto;

GO

-- ╔═════════════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.8       Riscrittura sargable — casi comuni da memorizzare║
-- ╚═════════════════════════════════════════════════════════════════════╝

-- Tutti i casi frequenti fianco a fianco

-- 1. Anno/mese/trimestre su datetime
-- ❌  WHERE YEAR(OrderDate) = 2013
-- ✅  WHERE OrderDate >= '2013-01-01' AND OrderDate < '2014-01-01'

-- 2. Funzione stringa
-- ❌  WHERE LEFT(LastName, 3) = 'Ros'
-- ✅  WHERE LastName LIKE 'Ros%'

-- 3. Calcolo sulla colonna
-- ❌  WHERE ListPrice * 1.22 > 500
-- ✅  WHERE ListPrice > 500 / 1.22

-- 4. CAST sulla colonna
-- ❌  WHERE CAST(OrderDate AS DATE) = '2013-12-25'
-- ✅  WHERE OrderDate >= '2013-12-25' AND OrderDate < '2013-12-26'

-- 5. Spostare DATEADD dal lato del parametro
-- ❌  WHERE DATEADD(DAY, 30, OrderDate) < GETDATE()
-- ✅  WHERE OrderDate < DATEADD(DAY, -30, GETDATE())


GO

-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.9      NULL non è uguale a nulla — neanche a se stesso║
-- ╚══════════════════════════════════════════════════════════════════╝
-- 💡 WHERE restituisce solo le righe TRUE. UNKNOWN è trattato come FALSE.
--

-- NULL produce UNKNOWN in qualsiasi confronto
SELECT
    CASE WHEN NULL = NULL  THEN 'TRUE' ELSE 'non TRUE' END AS NullUgNull,
    CASE WHEN NULL <> NULL THEN 'TRUE' ELSE 'non TRUE' END AS NullDivNull,
    CASE WHEN NULL = 0     THEN 'TRUE' ELSE 'non TRUE' END AS NullUgZero,
    CASE WHEN NULL IS NULL THEN 'TRUE' ELSE 'non TRUE' END AS NullIsNull;
-- Risultato: non TRUE, non TRUE, non TRUE, TRUE

-- Conseguenza pratica: questi WHERE non tornano mai righe
SELECT COUNT(*) AS VerificaEguaglianza
FROM Production.Product
WHERE Color = NULL;     -- sempre 0 righe

SELECT COUNT(*) AS VerificaDiseguaglianza
FROM Production.Product
WHERE Color <> NULL;    -- sempre 0 righe

GO

-- ╔════════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.9       IS NULL / IS NOT NULL — unico modo corretto ║
-- ╚════════════════════════════════════════════════════════════════╝
-- 💡 COUNT(colonna) conta i non-NULL. COUNT(*) conta tutte le righe. La differenza = righe con NULL
--

-- T-SQL corretto: usa CASE o query separate
SELECT
    COUNT(Color)                AS ProdottiConColore,    -- COUNT(col) ignora NULL
    COUNT(*) - COUNT(Color)     AS ProdottiSenzaColore,  -- differenza = i NULL
    COUNT(*)                    AS TotaleProdotti
FROM Production.Product;


GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.10      TOP senza ORDER BY — non deterministico   ║
-- ╚══════════════════════════════════════════════════════════════╝
-- 💡 TOP senza ORDER BY è accettabile solo per un preview rapido in sviluppo, mai in produzione
--

-- ❌ Quale TOP 10? Dipende dal piano, dalla cache, dal parallelismo.
-- Esegui più volte: potresti ottenere risultati diversi sotto carico.
SELECT TOP 10 Name, ListPrice
FROM Production.Product;

-- ✅ Con ORDER BY: deterministico e riproducibile
SELECT TOP 10 Name, ListPrice
FROM Production.Product
ORDER BY ListPrice DESC;

GO

-- ╔════════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.11      Funzioni aggregate — comportamento su NULL  ║
-- ╚════════════════════════════════════════════════════════════════╝
-- 💡 COUNT(DISTINCT col) ha un costo aggiuntivo. Usalo solo quando necessario.
--

-- COUNT(*) vs COUNT(col): la differenza sui NULL
SELECT
    COUNT(*)                AS TotaleProdotti,
    COUNT(Color)            AS ConColoreDefinito,    -- ignora NULL
    COUNT(DISTINCT Color)   AS ColoriDistinti,       -- ignora NULL + dedup
    SUM(ListPrice)          AS SommaListino,         -- ignora NULL
    AVG(ListPrice)          AS MediaListino,         -- SUM/COUNT(ListPrice)
    MIN(ListPrice)          AS PrezzoMinimo,
    MAX(ListPrice)          AS PrezzoMassimo
FROM Production.Product
WHERE ListPrice > 0;

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.12      GROUP BY — regola colonne non-aggregate   ║
-- ╚══════════════════════════════════════════════════════════════╝

-- ❌ Errore classico: pc.Name non nel GROUP BY
-- (decommentare per vedere il messaggio di errore)
-- SELECT p.ProductSubcategoryID, pc.Name, COUNT(*), AVG(p.ListPrice)
-- FROM   Production.Product p
--   JOIN Production.ProductSubcategory psc
--        ON p.ProductSubcategoryID = psc.ProductSubcategoryID
--   JOIN Production.ProductCategory pc
--        ON psc.ProductCategoryID = pc.ProductCategoryID
-- GROUP BY p.ProductSubcategoryID;  -- pc.Name manca: errore

-- ✅ Tutte le colonne non-aggregate presenti nel GROUP BY
SELECT
    pc.ProductCategoryID,
    pc.Name             AS Categoria,
    COUNT(p.ProductID)  AS NumProdotti,
    AVG(p.ListPrice)    AS PrezzoMedio,
    MAX(p.ListPrice)    AS PrezzoMax
FROM Production.Product p
    JOIN Production.ProductSubcategory psc
        ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    JOIN Production.ProductCategory pc
        ON psc.ProductCategoryID = pc.ProductCategoryID
WHERE p.ListPrice > 0
GROUP BY pc.ProductCategoryID, pc.Name
ORDER BY PrezzoMedio DESC;

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.23      WHERE vs HAVING — costo a confronto       ║
-- ╚══════════════════════════════════════════════════════════════╝
-- 💡 Attiva il piano di esecuzione e osserva il numero stimato di righe in ingresso all'operatore Aggregate
--

-- ✅ Filtro nel WHERE: GROUP BY elabora solo le righe che passano il filtro
SELECT
    pc.Name         AS Categoria,
    COUNT(*)        AS NumProdotti,
    AVG(ListPrice)  AS PrezzoMedio
FROM Production.Product p
    JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    JOIN Production.ProductCategory pc    ON psc.ProductCategoryID   = pc.ProductCategoryID
WHERE p.ListPrice > 0              -- filtra PRIMA di aggregare
  AND p.DiscontinuedDate IS NULL
GROUP BY pc.Name
HAVING COUNT(*) > 5               -- filtra i GRUPPI risultanti
ORDER BY PrezzoMedio DESC;

-- Ricorda: solo i predicati su aggregati (COUNT, SUM, AVG...) vanno nel HAVING.
-- Tutto il resto va nel WHERE.

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.14      DISTINCT — causa e soluzione              ║
-- ╚══════════════════════════════════════════════════════════════╝
-- 💡 Nel piano di esecuzione: DISTINCT genera un operatore 'Sort' o 'Hash Match (Aggregate)'. EXISTS genera un 'Left Semi Join'.
--

-- ❌ JOIN su SalesOrderHeader moltiplica le righe — DISTINCT le elimina ma con costo
SELECT DISTINCT
    c.CustomerID,
    p.FirstName + ' ' + p.LastName AS Cliente
FROM Sales.Customer c
    JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
    JOIN Person.Person p            ON c.PersonID   = p.BusinessEntityID;

-- ✅ EXISTS: non moltiplica le righe, si ferma al primo match (semi-join)
SELECT
    c.CustomerID,
    p.FirstName + ' ' + p.LastName AS Cliente
FROM Sales.Customer c
    JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
WHERE EXISTS (
    SELECT 1 FROM Sales.SalesOrderHeader soh
    WHERE soh.CustomerID = c.CustomerID
);

-- Verifica: entrambe restituiscono lo stesso numero di righe

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.16  CASE nella SELECT — classificazione per fascia║
-- ╚══════════════════════════════════════════════════════════════╝

SELECT
    p.Name,
    p.ListPrice,
    CASE
        WHEN p.ListPrice = 0                       THEN 'Non in vendita'
        WHEN p.ListPrice < 100                     THEN 'Accessori'
        WHEN p.ListPrice BETWEEN 100 AND 999       THEN 'Mid-range'
        ELSE                                            'Premium'
    END AS FasciaPrezzo
FROM Production.Product p
WHERE p.DiscontinuedDate IS NULL
ORDER BY p.ListPrice;

-- Forma semplice (quando confronti una sola espressione con valori fissi)
SELECT
    PersonType,
    CASE PersonType
        WHEN 'EM' THEN 'Dipendente'
        WHEN 'SP' THEN 'Venditore'
        WHEN 'IN' THEN 'Cliente individuale'
        WHEN 'SC' THEN 'Cliente azienda'
        ELSE           'Altro'
    END AS Ruolo,
    COUNT(*) AS NumPersone
FROM Person.Person
GROUP BY PersonType
ORDER BY NumPersone DESC;

GO

-- ╔═══════════════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.16    CASE come argomento di aggregato — COUNT condizionale║
-- ╚═══════════════════════════════════════════════════════════════════════╝
-- 💡 COUNT(CASE ... THEN 1 END) restituisce il numero di righe che soddisfano la condizione. ELSE è implicito NULL, e COUNT ignora i NULL.
--

-- Pivot manuale: conteggi per fascia in un'unica passata sulla tabella
-- Molto più efficiente di 4 query separate con WHERE diversi
SELECT
    COUNT(*)                                                       AS TotaleProdotti,
    COUNT(CASE WHEN ListPrice = 0              THEN 1 END)         AS NonInVendita,
    COUNT(CASE WHEN ListPrice BETWEEN 1 AND 99   THEN 1 END)       AS Accessori,
    COUNT(CASE WHEN ListPrice BETWEEN 100 AND 999 THEN 1 END)      AS MidRange,
    COUNT(CASE WHEN ListPrice >= 1000          THEN 1 END)         AS Premium,
    -- SUM condizionale: fatturato solo per la fascia premium
    SUM(CASE WHEN ListPrice >= 1000 THEN ListPrice ELSE 0 END)     AS ListinoPremium
FROM Production.Product
WHERE DiscontinuedDate IS NULL;

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.16      CASE nel GROUP BY e nell'ORDER BY         ║
-- ╚══════════════════════════════════════════════════════════════╝
-- 💡 L'alias di GROUP BY non è disponibile. L'alias di ORDER BY sì. Il motivo è l'ordine di esecuzione
--

-- GROUP BY per fasce calcolate
-- ATTENZIONE: ripeti il CASE identico nel GROUP BY — non puoi usare l'alias
SELECT
    CASE
        WHEN ListPrice < 100  THEN 'Bassa'
        WHEN ListPrice < 1000 THEN 'Media'
        ELSE                       'Alta'
    END AS Fascia,
    COUNT(*) AS Prodotti,
    AVG(ListPrice) AS PrezzoMedio
FROM Production.Product
WHERE ListPrice > 0
GROUP BY
    CASE
        WHEN ListPrice < 100  THEN 'Bassa'   -- stessa espressione
        WHEN ListPrice < 1000 THEN 'Media'
        ELSE                       'Alta'
    END
ORDER BY PrezzoMedio DESC;

-- ORDER BY personalizzato con CASE
SELECT Name, PersonType
FROM Person.Person
ORDER BY
    CASE PersonType
        WHEN 'EM' THEN 1
        WHEN 'SP' THEN 2
        WHEN 'IN' THEN 3
        ELSE 9
    END,
    Name ASC;

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.16      CASE nel WHERE — non sargable             ║
-- ╚══════════════════════════════════════════════════════════════╝
--

-- ❌ CASE nel WHERE: non sargable, valutato riga per riga
-- (decommenta per verificare il piano)
-- SELECT Name, ListPrice FROM Production.Product
-- WHERE CASE WHEN ListPrice > 500 THEN 'alto' ELSE 'basso' END = 'alto';

-- ✅ Equivalente sargable: predicato diretto
SELECT Name, ListPrice
FROM Production.Product
WHERE ListPrice > 500;

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.17     CAST e CONVERT — utilizzi tipici           ║
-- ╚══════════════════════════════════════════════════════════════╝
-- 💡 Style codes usati con CONVERT: 23=yyyy-mm-dd, 103=dd/mm/yyyy, 112=yyyymmdd, 120=yyyy-mm-dd hh:mi:ss
--

SELECT
    soh.SalesOrderID,
    soh.OrderDate,
    -- Rimuove la parte oraria (tipo DATE, non DATETIME)
    CAST(soh.OrderDate AS DATE)                     AS SoloData,
    -- Formattazione per display
    CONVERT(VARCHAR(10), soh.OrderDate, 103)        AS Data_IT,      -- gg/mm/aaaa
    CONVERT(VARCHAR(10), soh.OrderDate, 23)         AS Data_ISO,     -- aaaa-mm-gg
    -- Conversione numerica
    CAST(soh.TotalDue AS INT)                       AS TotaleIntero,
    CAST(soh.TotalDue AS DECIMAL(10,0))             AS TotaleArrotondato
FROM Sales.SalesOrderHeader soh
WHERE soh.Status = 5
ORDER BY soh.OrderDate DESC;

GO

-- ╔═════════════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.17     Conversione sulla colonna nel WHERE — non sargable║
-- ╚═════════════════════════════════════════════════════════════════════╝
-- 💡 Le conversioni implicite avvengono in silenzio ma rendono comunque non sargable la where
--

-- ❌ CAST sulla colonna: non sargable
SELECT SalesOrderID, OrderDate, TotalDue
FROM Sales.SalesOrderHeader
WHERE CAST(OrderDate AS DATE) = '2013-12-25';

-- ✅ Sposta la conversione sul parametro
SELECT SalesOrderID, OrderDate, TotalDue
FROM Sales.SalesOrderHeader
WHERE OrderDate >= '2013-12-25'
  AND OrderDate <  '2013-12-26';

-- ❌ Conversione implicita per tipo sbagliato nel parametro
-- CustomerID è INT — confrontarlo con VARCHAR causa conversione riga per riga
DECLARE @idSbagliato VARCHAR(10) = '29825';
SELECT CustomerID FROM Sales.Customer WHERE CustomerID = @idSbagliato;

-- ✅ Tipo corrispondente: nessuna conversione, sargable
DECLARE @idCorretto INT = 29825;
SELECT CustomerID FROM Sales.Customer WHERE CustomerID = @idCorretto;

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.18      Funzioni DATE — riferimento               ║
-- ╚══════════════════════════════════════════════════════════════╝
--

SELECT
    soh.SalesOrderID,
    soh.OrderDate,
    soh.ShipDate,
    -- Estrazione componenti
    YEAR(soh.OrderDate)                     AS Anno,
    MONTH(soh.OrderDate)                    AS Mese,
    DAY(soh.OrderDate)                      AS Giorno,
    DATEPART(QUARTER, soh.OrderDate)        AS Trimestre,
    DATEPART(WEEKDAY, soh.OrderDate)        AS GiornoSettimana,  -- 1=Dom (default)
    EOMONTH(soh.OrderDate)                  AS FineMese,
    -- Aritmetica
    DATEADD(DAY, 30, soh.OrderDate)         AS Scadenza30gg,
    DATEADD(MONTH, -3, soh.OrderDate)       AS TresMesiFa,
    DATEDIFF(DAY, soh.OrderDate, soh.ShipDate) AS GiorniConsegna,
    DATEDIFF(MONTH, '2011-01-01', soh.OrderDate) AS MesiDaInizio,
    -- Data corrente
    CAST(GETDATE() AS DATE)                 AS Oggi,
    GETUTCDATE()                            AS OraUTC
FROM Sales.SalesOrderHeader soh
WHERE soh.Status = 5
ORDER BY soh.OrderDate DESC;

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.18     Funzioni DATE — pattern sargable per filtri║
-- ╚══════════════════════════════════════════════════════════════╝
-- 💡 Calcola le date soglia UNA VOLTA in variabili, poi usale nel WHERE. Eviti chiamate ripetute a GETDATE() e ottieni piani di esecuzione stabili.
--

-- Tutti i filtri comuni riscritti in forma sargable

-- Tutto il 2013
SELECT COUNT(*) AS Ordini2013 FROM Sales.SalesOrderHeader
WHERE OrderDate >= '2013-01-01' AND OrderDate < '2014-01-01';

-- Dicembre 2013
SELECT COUNT(*) AS OrdiniDic2013 FROM Sales.SalesOrderHeader
WHERE OrderDate >= '2013-12-01' AND OrderDate < '2014-01-01';

-- Q4 2013 (ottobre-dicembre)
SELECT COUNT(*) AS OrdiniQ4 FROM Sales.SalesOrderHeader
WHERE OrderDate >= '2013-10-01' AND OrderDate < '2014-01-01';

-- Ultimi 30 giorni relativi al massimo OrderDate presente nella tabella
DECLARE @maxDate DATE = (SELECT CAST(MAX(OrderDate) AS DATE) FROM Sales.SalesOrderHeader);
SELECT COUNT(*) AS OrdiniUltimi30gg FROM Sales.SalesOrderHeader
WHERE OrderDate >= DATEADD(DAY, -30, @maxDate)
  AND OrderDate <= @maxDate;

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.18      Funzioni STRING — riferimento             ║
-- ╚══════════════════════════════════════════════════════════════╝
--

SELECT
    p.FirstName,
    p.MiddleName,
    p.LastName,
    -- Lunghezza e pulizia
    LEN(p.LastName)                             AS LunghezzaCognome,
    TRIM(p.FirstName)                           AS NomePulito,       
    LTRIM(RTRIM(p.FirstName))                   AS NomePulitoLeg,    
    -- Estrazione
    LEFT(p.LastName, 3)                         AS Sigla3,
    RIGHT(p.LastName, 3)                        AS Finale3,
    SUBSTRING(p.LastName, 2, 4)                 AS Dal2Per4Char,
    -- Ricerca
    CHARINDEX('a', p.LastName)                  AS PosizionePrimaA,  -- 0 se non trovato
    -- Sostituzione
    REPLACE(p.LastName, 'son', 'SEN')           AS CognomeModificato
FROM Person.Person p
ORDER BY p.LastName;

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.18     Funzioni STRING — sargability              ║
-- ╚══════════════════════════════════════════════════════════════╝

-- ❌ Non sargable: funzione sulla colonna
SELECT BusinessEntityID, LastName
FROM Person.Person
WHERE LEFT(LastName, 3) = 'Ada';

-- ✅ Sargable: LIKE con pattern iniziale fisso
SELECT BusinessEntityID, LastName
FROM Person.Person
WHERE LastName LIKE 'Ada%';

-- Verifica: stessi risultati, piani diversi

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.18     Funzioni NUMERICI — riferimento            ║
-- ╚══════════════════════════════════════════════════════════════╝
-- 💡 Le funzioni sui numerici nella SELECT non hanno impatto sugli indici. Diventano problematiche solo nel WHERE.
--

SELECT
    ListPrice,
    ROUND(ListPrice, 2)         AS Arrotondato2,
    ROUND(ListPrice, 0)         AS Arrotondato0,
    ROUND(ListPrice, -2)        AS ArrotondatoCentinaia,  -- es: 1234 -> 1200
    CEILING(ListPrice)          AS ArrotondaSu,
    FLOOR(ListPrice)            AS ArrotondaGiu,
    ABS(ListPrice - 500)        AS DistanzaDa500,
    ListPrice % 10              AS RestoDiv10            -- modulo
FROM Production.Product
WHERE ListPrice > 0
ORDER BY ListPrice DESC;

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.20     ROW_NUMBER, RANK, DENSE_RANK — differenze  ║
-- ╚══════════════════════════════════════════════════════════════╝
-- 💡 ROW_NUMBER è deterministico solo se ORDER BY identifica univocamente ogni riga. Con pari merito, l'ordine interno è arbitrario.
--

-- Tre funzioni di ranking — comportamento diverso sui pari merito
SELECT
    p.Name,
    p.ListPrice,
    pc.Name                                                          AS Categoria,
    -- Senza pari merito: 1, 2, 3, 4... (sempre sequenziale)
    ROW_NUMBER()  OVER (ORDER BY p.ListPrice DESC)                   AS RowNum,
    -- Con pari merito: stesso rank, poi salta (1, 2, 2, 4)
    RANK()        OVER (ORDER BY p.ListPrice DESC)                   AS Rank,
    -- Con pari merito: stesso rank, NON salta (1, 2, 2, 3)
    DENSE_RANK()  OVER (ORDER BY p.ListPrice DESC)                   AS DenseRank,
    -- PARTITION: ranking ripartito dentro ogni categoria
    ROW_NUMBER()  OVER (PARTITION BY pc.Name ORDER BY p.ListPrice DESC) AS RankInCategoria
FROM Production.Product p
    JOIN Production.ProductSubcategory psc
        ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    JOIN Production.ProductCategory pc
        ON psc.ProductCategoryID = pc.ProductCategoryID
WHERE p.ListPrice > 0
ORDER BY p.ListPrice DESC;

GO

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.20      NTILE — suddivisione in bucket            ║
-- ╚══════════════════════════════════════════════════════════════╝

-- NTILE(N): assegna ogni riga a uno di N bucket di dimensione uguale
SELECT
    p.Name,
    p.ListPrice,
    NTILE(4) OVER (ORDER BY p.ListPrice)    AS Quarto,
    NTILE(10) OVER (ORDER BY p.ListPrice)   AS Dec
FROM Production.Product p
WHERE p.ListPrice > 0
ORDER BY p.ListPrice;

-- Uso pratico: prezzo medio per trimestre
SELECT
    Trimestre,
    COUNT(*)            AS NumProdotti,
    MIN(ListPrice)      AS PrezzoMin,
    MAX(ListPrice)      AS PrezzoMax,
    AVG(ListPrice)      AS PrezzoMedio
FROM (
    SELECT
        ListPrice,
        NTILE(4) OVER (ORDER BY ListPrice) AS Trimestre
    FROM Production.Product
    WHERE ListPrice > 0
) q
GROUP BY Trimestre
ORDER BY Trimestre;

GO

-- ╔════════════════════════════════════════════════════════════════════════════════╗
-- ║  Slide 1.1.20      Aggregati con OVER — dettaglio e aggregato sulla stessa riga║
-- ╚════════════════════════════════════════════════════════════════════════════════╝
--

-- La differenza fondamentale da GROUP BY: le righe NON vengono collassate
SELECT
    soh.SalesOrderID,
    soh.CustomerID,
    soh.OrderDate,
    soh.TotalDue,
    -- Totale di tutti gli ordini del cliente (su tutte le sue righe)
    SUM(soh.TotalDue)  OVER (PARTITION BY soh.CustomerID)  AS TotaleCliente,
    -- Numero di ordini del cliente
    COUNT(*)           OVER (PARTITION BY soh.CustomerID)  AS NumOrdiniCliente,
    -- Classificazione per importo tra tutti gli ordini (globale)
    RANK() OVER (ORDER BY soh.TotalDue DESC)               AS RankImporto
FROM Sales.SalesOrderHeader soh
WHERE soh.Status = 5
ORDER BY soh.CustomerID, soh.OrderDate;

GO