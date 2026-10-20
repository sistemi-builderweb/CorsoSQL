-- ============================================================
-- MODULO 3 - SEZIONE 1 | CREATE, ALTER, DROP di tabelle
-- ============================================================

-- ============================================================
-- SETUP - Ambiente e schema demo
-- ============================================================
USE AdventureWorks;
GO

SET NOCOUNT ON;
GO

-- CREATE SCHEMA deve essere il primo comando del batch: da qui il GO sopra
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'demo')
    EXEC ('CREATE SCHEMA demo');
GO



-- ============================================================
-- 1. DALLA 1NF ALLA 3NF
-- ============================================================
-- I tre blocchi che seguono sono UN UNICO CASO CHE EVOLVE: la correzione
-- di ogni forma normale diventa la violazione della successiva.


-- ── 1.1 1NF: valori atomici ───────────────────────────────────
-- Regola: ogni cella contiene un solo valore e non esistono gruppi di
-- colonne ripetute.
--
-- Si parte dal caso peggiore: una riga per articolo, con le giacenze di
-- tutti i depositi dentro una stringa.

DROP TABLE IF EXISTS demo.ArticoloPiatto;
GO

CREATE TABLE demo.ArticoloPiatto
(
    ArticoloID  CHAR(5)      NOT NULL PRIMARY KEY,
    Descrizione NVARCHAR(60) NOT NULL,
    Giacenze    NVARCHAR(200)    NULL   -- lista di coppie magazzino:pezzi (1NF)
);

INSERT INTO demo.ArticoloPiatto VALUES
    ('A-100', N'Vite M6 zincata', N'MAG-MI:250, MAG-TO:80'),
    ('A-205', N'Dado M6',         N'MAG-MI:12'),
    ('A-300', N'Rondella M6',     N'MAG-MI:400, MAG-TO:150');

PRINT '--- 1.1 Violazione: le giacenze vivono dentro una stringa ---';
SELECT * FROM demo.ArticoloPiatto;
GO


-- ── 1.1.a Primo sintomo: la domanda banale non e' una query ────
-- "Quanti pezzi di A-100 ci sono a Torino?" richiede di spezzare la
-- stringa sulla virgola, poi sui due punti, poi convertire in numero.
-- Nessun indice puo' servire.

PRINT '--- 1.1.a Parsing al posto di una query ---';
SELECT  ArticoloID,
        LTRIM(SUBSTRING(Giacenze,
              CHARINDEX('MAG-TO:', Giacenze) + 7,
              CHARINDEX(',', Giacenze + ',', CHARINDEX('MAG-TO:', Giacenze))
                - CHARINDEX('MAG-TO:', Giacenze) - 7)) AS Giacenza
FROM    demo.ArticoloPiatto
WHERE   Giacenze LIKE '%MAG-TO:%';
GO


-- ── 1.1.b Secondo sintomo: il tipo di dato e' disattivato ──────
-- Il database non sa che dentro quella stringa ci sono un codice deposito
-- e un numero, quindi non puo' controllare niente.

-- Questo il database lo accetta senza battere ciglio
INSERT INTO demo.ArticoloPiatto VALUES ('A-999', N'Articolo rotto', N'MAG-XX:tanti, ???');

PRINT '--- 1.1.b Nessun vincolo impedisce un valore insensato ---';
SELECT * FROM demo.ArticoloPiatto WHERE ArticoloID = 'A-999';
GO


-- ── 1.1.c Terzo sintomo: due rettifiche si sovrascrivono ───────
-- Per correggere la giacenza di un solo deposito l'applicazione deve
-- leggere tutta la stringa, modificarne un pezzo e riscriverla intera.
-- Qui si simulano due operatori sullo stesso articolo nello stesso momento.

PRINT '--- 1.1.c Stato di partenza ---';
SELECT Giacenze AS Prima FROM demo.ArticoloPiatto WHERE ArticoloID = 'A-100';

-- Operatore 1 legge, rettifica Milano da 250 a 300 e riscrive tutta la stringa
DECLARE @op1 NVARCHAR(200) = N'MAG-MI:300, MAG-TO:80';

-- Operatore 2 legge lo STESSO valore di partenza, rettifica Torino da 80 a 95
DECLARE @op2 NVARCHAR(200) = N'MAG-MI:250, MAG-TO:95';

-- Scrivono nell'ordine in cui premono Salva
UPDATE demo.ArticoloPiatto SET Giacenze = @op1 WHERE ArticoloID = 'A-100';
UPDATE demo.ArticoloPiatto SET Giacenze = @op2 WHERE ArticoloID = 'A-100';

PRINT '--- 1.1.c La rettifica di Milano e sparita: nessun errore, nessun avviso ---';
SELECT Giacenze AS Dopo FROM demo.ArticoloPiatto WHERE ArticoloID = 'A-100';
GO
-- Risultato atteso: MAG-MI:250, MAG-TO:95  (il 300 non c'e' piu')


-- ── 1.1.d La correzione ────────────────────────────────────────
-- Una riga per ogni fatto elementare: la coppia articolo-magazzino.
-- Le righe passano da 3 a 5 perche' si rendono visibili fatti che prima
-- erano nascosti dentro una stringa.

DELETE FROM demo.ArticoloPiatto WHERE ArticoloID = 'A-999';
GO

DROP TABLE IF EXISTS demo.GiacenzaPiatta;
GO

CREATE TABLE demo.GiacenzaPiatta
(
    ArticoloID     CHAR(5)      NOT NULL,
    MagazzinoID    CHAR(6)      NOT NULL,
    Quantita       INT          NOT NULL,
    Descrizione    NVARCHAR(60) NOT NULL,
    CittaMagazzino NVARCHAR(40) NOT NULL,
    CONSTRAINT PK_GiacenzaPiatta PRIMARY KEY (ArticoloID, MagazzinoID)
);

INSERT INTO demo.GiacenzaPiatta VALUES
    ('A-100', 'MAG-MI', 250, N'Vite M6 zincata', N'Milano'),
    ('A-100', 'MAG-TO',  80, N'Vite M6 zincata', N'Torino'),
    ('A-205', 'MAG-MI',  12, N'Dado M6',         N'Milano'),
    ('A-300', 'MAG-MI', 400, N'Rondella M6',     N'Milano'),
    ('A-300', 'MAG-TO', 150, N'Rondella M6',     N'Torino');
GO

PRINT '--- 1.1.d (1) La domanda è una query vera e indicizzabile ---';
SELECT  Quantita
FROM    demo.GiacenzaPiatta
WHERE   ArticoloID = 'A-100' AND MagazzinoID = 'MAG-TO';

PRINT '--- 1.1.d (2) Il tipo dato protegge coerenza dati ---';
BEGIN TRY
    INSERT INTO demo.GiacenzaPiatta VALUES ('A-999', 'MAG-XX', 'tanti', N'x', N'y');
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Errore, ERROR_MESSAGE() AS Messaggio;
END CATCH;

PRINT '--- 1.1.d (3) Le due rettifiche non si toccano: sono righe diverse ---';
UPDATE demo.GiacenzaPiatta SET Quantita = 300 WHERE ArticoloID = 'A-100' AND MagazzinoID = 'MAG-MI';
UPDATE demo.GiacenzaPiatta SET Quantita =  95 WHERE ArticoloID = 'A-100' AND MagazzinoID = 'MAG-TO';

SELECT * FROM demo.GiacenzaPiatta ORDER BY ArticoloID, MagazzinoID;
GO


-- ── 1.2 2NF: nessuna dipendenza parziale ───────────────────────
-- Regola: siamo in 1NF e nessun attributo dipende solo da una PARTE
-- della chiave composta.
--
-- 💡 Da risultato esempio precedente vedi le ultime due colonne della tabella
--    appena creata. 'Vite M6 zincata' compare due volte e 'Milano' tre.
--    Non e' un difetto della 1NF, e' il prossimo problema
--
-- Qui la chiave composta non e' una scelta di modellazione ma una
-- necessita' logica: "250 pezzi" non significa niente senza sapere di
-- quale articolo e in quale magazzino.

PRINT '--- 1.2 Quante volte e scritta la stessa descrizione? ---';
SELECT  ArticoloID,
        COUNT(*)         AS CopieDellaDescrizione,
        MIN(Descrizione) AS Descrizione
FROM    demo.GiacenzaPiatta
GROUP BY ArticoloID;

PRINT '--- 1.2 E la stessa citta? Una per ogni articolo in quel deposito ---';
SELECT  MagazzinoID,
        COUNT(*)            AS CopieDellaCitta,
        MIN(CittaMagazzino) AS Citta
FROM    demo.GiacenzaPiatta
GROUP BY MagazzinoID;
GO


-- ── 1.2.a Anomalia di aggiornamento ────────────────────────────
-- Rinomina dell'articolo: vanno toccate tutte le sue righe.
-- Se il WHERE ne dimentica una, lo stesso codice si ritrova con due
-- descrizioni e nessun vincolo lo impedisce.

UPDATE  demo.GiacenzaPiatta
SET     Descrizione = N'Vite M6 zincata DIN 933'
WHERE   ArticoloID = 'A-100' AND MagazzinoID = 'MAG-MI';   -- dimentica MAG-TO

PRINT '--- 1.2.a Lo stesso articolo ha due descrizioni diverse ---';
SELECT  ArticoloID, COUNT(DISTINCT Descrizione) AS DescrizioniDiverse
FROM    demo.GiacenzaPiatta
GROUP BY ArticoloID;

SELECT * FROM demo.GiacenzaPiatta WHERE ArticoloID = 'A-100';
GO


-- ── 1.2.b Anomalie di inserimento e di cancellazione ───────────
-- Un articolo appena codificato non e' registrabile. E azzerando le giacenze si perde anche la descrizione.

PRINT '--- 1.2.b A-410 esiste a catalogo ma non è presente a magazzino: non è possibile registrarlo o si può farlo solo senza dati magazzino ---';
BEGIN TRY
    INSERT INTO demo.GiacenzaPiatta (ArticoloID, MagazzinoID, Quantita, Descrizione, CittaMagazzino)
    VALUES ('A-410', NULL, 0, N'Chiave a brugola', NULL);
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Errore, ERROR_MESSAGE() AS Messaggio;
END CATCH;

PRINT '--- 1.2.b Le giacenze di A-205 vanno a zero: sparisce anche Dado M6 ---';
DELETE FROM demo.GiacenzaPiatta WHERE ArticoloID = 'A-205';

SELECT DISTINCT ArticoloID, Descrizione FROM demo.GiacenzaPiatta;
GO


-- ── 1.2.c La correzione ────────────────────────────────────────
-- Tre tabelle: le due entita' e la relazione fra loro. Quantita e
-- ScortaMinima restano sulla relazione perché appartengono a quel livello: sono attributi della coppia, non dell'articolo ne' del magazzino.
--
-- 💡 Magazzino nasce gia' con CAP, citta', provincia e regione: è il
--    problema della prossima forma normale.

DROP TABLE IF EXISTS demo.Giacenza;
DROP TABLE IF EXISTS demo.Articolo;
DROP TABLE IF EXISTS demo.Magazzino;
GO

CREATE TABLE demo.Articolo
(
    ArticoloID  CHAR(5)      NOT NULL PRIMARY KEY,
    Descrizione NVARCHAR(60) NOT NULL,
    UnitaMisura CHAR(3)      NOT NULL
);

CREATE TABLE demo.Magazzino
(
    MagazzinoID CHAR(6)      NOT NULL PRIMARY KEY,
    Descrizione NVARCHAR(40) NOT NULL,
    CAP         CHAR(5)      NOT NULL,
    Citta       NVARCHAR(40) NOT NULL,   -- dipende dal CAP        (3NF, blocco 1.3)
    Provincia   CHAR(2)      NOT NULL,   -- dipende dal CAP        (3NF)
    Regione     NVARCHAR(30) NOT NULL    -- dipende dalla provincia (3NF)
);

CREATE TABLE demo.Giacenza
(
    ArticoloID   CHAR(5) NOT NULL,
    MagazzinoID  CHAR(6) NOT NULL,
    Quantita     INT     NOT NULL,
    ScortaMinima INT         NULL,
    CONSTRAINT PK_Giacenza PRIMARY KEY (ArticoloID, MagazzinoID)
);
GO

INSERT INTO demo.Articolo VALUES
    ('A-100', N'Vite M6 zincata',  'PZ'),
    ('A-205', N'Dado M6',          'PZ'),
    ('A-300', N'Rondella M6',      'PZ'),
    ('A-410', N'Chiave a brugola', 'PZ');   -- ora si registra anche senza giacenze

INSERT INTO demo.Magazzino VALUES
    ('MAG-MI', N'Deposito Nord',  '20139', N'Milano', 'MI', N'Lombardia'),
    ('MAG-EC', N'Hub e-commerce', '20139', N'Milano', 'MI', N'Lombardia'),
    ('MAG-TO', N'Deposito Ovest', '10152', N'Torino', 'TO', N'Piemonte'),
    ('MAG-NA', N'Deposito Sud',   '80133', N'Napoli', 'NA', N'Campania');   -- ancora vuoto

INSERT INTO demo.Giacenza VALUES
    ('A-100', 'MAG-MI', 300,  50),
    ('A-100', 'MAG-TO',  95,  20),
    ('A-205', 'MAG-MI',  12,  30),
    ('A-300', 'MAG-MI', 400, 100),
    ('A-300', 'MAG-TO', 150,  50);
GO

-- La descrizione si corregge in un punto solo e vale per ogni magazzino
UPDATE demo.Articolo SET Descrizione = N'Vite M6 zincata DIN 933' WHERE ArticoloID = 'A-100';

PRINT '--- 1.2.c Il modello in 2NF ---';
SELECT  a.ArticoloID, a.Descrizione, m.MagazzinoID, m.Citta, g.Quantita, g.ScortaMinima
FROM    demo.Articolo        AS a
LEFT JOIN demo.Giacenza      AS g ON g.ArticoloID  = a.ArticoloID
LEFT JOIN demo.Magazzino     AS m ON m.MagazzinoID = g.MagazzinoID
ORDER BY a.ArticoloID, m.MagazzinoID;
GO

-- 💡 Il test: per ogni colonna chiediti se per determinarla serve TUTTA la
--    chiave o ne basta un pezzo. 


-- ── 1.3 3NF: nessuna dipendenza transitiva ─────────────────────
-- Regola: siamo in 2NF e nessun attributo non chiave dipende da un altro
-- attributo non chiave.
--
-- La tabella sotto esame e' demo.Magazzino: la chiave qui e' singola e
-- pulita, il problema sta fra gli attributi non chiave.

PRINT '--- 1.3 Stato di partenza ---';
SELECT * FROM demo.Magazzino ORDER BY MagazzinoID;

-- MAG-MI e MAG-EC hanno lo stesso CAP: ma nulla impedisce di avere due citta' diverse
UPDATE demo.Magazzino SET Citta = N'Milano Est' WHERE MagazzinoID = 'MAG-EC';

PRINT '--- 1.3 Lo stesso CAP dichiara due citta diverse ---';
SELECT  CAP,
        COUNT(DISTINCT Citta) AS CittaDichiarate,
        MIN(Citta)            AS Valore1,
        MAX(Citta)            AS Valore2
FROM    demo.Magazzino
GROUP BY CAP
HAVING  COUNT(*) > 1;
GO


-- ── 1.3.a La correzione ────────────────────────────────────────
-- La 3NF va applicata due volte: prima si estrae la località, poi ci si
-- accorge che la regione non dipende dal CAP ma dalla provincia.

DROP TABLE IF EXISTS demo.Localita;
DROP TABLE IF EXISTS demo.Provincia;
GO

CREATE TABLE demo.Provincia
(
    Sigla   CHAR(2)      NOT NULL PRIMARY KEY,
    Nome    NVARCHAR(40) NOT NULL,
    Regione NVARCHAR(30) NOT NULL
);

CREATE TABLE demo.Localita
(
    CAP   CHAR(5)      NOT NULL PRIMARY KEY,
    Citta NVARCHAR(40) NOT NULL,
    Sigla CHAR(2)      NOT NULL REFERENCES demo.Provincia(Sigla)
);
GO

INSERT INTO demo.Provincia VALUES
    ('MI', N'Milano', N'Lombardia'),
    ('TO', N'Torino', N'Piemonte'),
    ('NA', N'Napoli', N'Campania');

INSERT INTO demo.Localita VALUES
    ('20139', N'Milano', 'MI'),
    ('10152', N'Torino', 'TO'),
    ('80133', N'Napoli', 'NA');
GO


ALTER TABLE demo.Magazzino DROP COLUMN Citta;
ALTER TABLE demo.Magazzino DROP COLUMN Provincia;
ALTER TABLE demo.Magazzino DROP COLUMN Regione;
GO

-- La citta' di un CAP si corregge in un punto solo e vale per ogni deposito
UPDATE demo.Localita SET Citta = N'Milano' WHERE CAP = '20139';

PRINT '--- 1.3.a Modello finale in 3NF ---';
SELECT  m.MagazzinoID, m.Descrizione, m.CAP, l.Citta,
        p.Nome AS Provincia, p.Regione
FROM    demo.Magazzino AS m
JOIN    demo.Localita  AS l ON l.CAP   = m.CAP
JOIN    demo.Provincia AS p ON p.Sigla = l.Sigla
ORDER BY m.MagazzinoID;
GO

-- 💡 Modello finale: Articolo - Magazzino - Giacenza - Localita - Provincia.
--    Si e' partiti da una riga per articolo con le giacenze dentro una
--    stringa e si è arrivati a cinque tabelle, ognuna nata da un problema
--    concreto.
--


-- ============================================================
-- 2. DENORMALIZZARE CON CRITERIO
-- ============================================================


-- ── 2.1 Colonna calcolata PERSISTED ────────────────────────────

ALTER TABLE demo.Giacenza ADD SottoScorta AS
    CASE WHEN Quantita < ScortaMinima THEN 1 ELSE 0 END PERSISTED;
GO

PRINT '--- 2.1 La colonna è calcolata e materializzata ---';
SELECT  name AS Colonna, is_persisted AS Persisted, definition AS Espressione
FROM    sys.computed_columns
WHERE   object_id = OBJECT_ID('demo.Giacenza');

SELECT ArticoloID, MagazzinoID, Quantita, ScortaMinima, SottoScorta FROM demo.Giacenza;

UPDATE demo.Giacenza SET Quantita = 5 WHERE ArticoloID = 'A-100' AND MagazzinoID = 'MAG-MI';

PRINT '--- 2.1 SottoScorta si è aggiornato da solo ---';
SELECT ArticoloID, MagazzinoID, Quantita, ScortaMinima, SottoScorta FROM demo.Giacenza;
GO


-- ── 2.2 Il dato storico non e' ridondanza ──────────────────────
-- Duplicazione voluta: il prezzo pagato al momento resta  anche se il listino del fornitore cambia.

DROP TABLE IF EXISTS demo.StoricoPrezzoCarico;
DROP TABLE IF EXISTS demo.ListinoFornitore;
GO

CREATE TABLE demo.ListinoFornitore
(
    ArticoloID    CHAR(5)        NOT NULL,
    Fornitore     NVARCHAR(60)   NOT NULL,
    PrezzoListino DECIMAL(19,4)  NOT NULL,
    CONSTRAINT PK_ListinoFornitore PRIMARY KEY (ArticoloID, Fornitore)
);

CREATE TABLE demo.StoricoPrezzoCarico
(
    CaricoID     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ArticoloID   CHAR(5)           NOT NULL,
    Fornitore    NVARCHAR(60)      NOT NULL,
    DataCarico   DATE              NOT NULL,
    Quantita     INT               NOT NULL,
    PrezzoPagato DECIMAL(19,4)     NOT NULL   -- fatto storico: NON e' ridondanza
);
GO

INSERT INTO demo.ListinoFornitore VALUES ('A-100', N'Acme', 0.12);

INSERT INTO demo.StoricoPrezzoCarico (ArticoloID, Fornitore, DataCarico, Quantita, PrezzoPagato) VALUES
    ('A-100', N'Acme', '2025-01-15', 500, 0.12),
    ('A-100', N'Acme', '2025-03-02', 300, 0.12);

-- Il listino aumenta: i carichi gia' registrati NON devono seguirlo
UPDATE demo.ListinoFornitore SET PrezzoListino = 0.15 WHERE ArticoloID = 'A-100';

PRINT '--- 2.2 Il carico conserva il prezzo di allora ---';
SELECT  c.CaricoID, c.DataCarico, c.Quantita,
        c.PrezzoPagato  AS PagatoAllora,
        l.PrezzoListino AS ListinoOggi
FROM    demo.StoricoPrezzoCarico            AS c
JOIN    demo.ListinoFornitore  AS l
    ON  l.ArticoloID = c.ArticoloID AND l.Fornitore = c.Fornitore;
GO


-- ============================================================
-- 3. CREATE TABLE: ANATOMIA
-- ============================================================
-- La tabella dei movimenti e' quella che in un sistema reale diventa
-- enorme: e' il caso in cui le scelte di definizione pesano di piu'.
-- Verra' usata per tutti gli esempi di ALTER.

DROP TABLE IF EXISTS demo.Movimento;
GO

CREATE TABLE demo.Movimento
(
    MovimentoID   INT IDENTITY(1,1) NOT NULL,
    ArticoloID    CHAR(5)           NOT NULL,
    MagazzinoID   CHAR(6)           NOT NULL,
    DataMovimento DATETIME2(0)      NOT NULL,
    Quantita      INT               NOT NULL,
    PrezzoPagato  DECIMAL(19,4)         NULL,
    Causale       VARCHAR(20)       NOT NULL,
    Note          NVARCHAR(400)         NULL
);
GO

PRINT '--- 3. Come è registrata la definizione ---';
SELECT  c.column_id    AS Ordine,
        c.name         AS Colonna,
        t.name         AS Tipo,
        c.max_length   AS ByteMax,
        c.precision,
        c.scale,
        c.is_nullable  AS Nullable,
        c.is_identity  AS IsIdentity,
        c.is_computed  AS Calcolata
FROM    sys.columns AS c
JOIN    sys.types   AS t ON t.user_type_id = c.user_type_id
WHERE   c.object_id = OBJECT_ID('demo.Movimento')
ORDER BY c.column_id;
GO



-- ============================================================
-- 4. IL COSTO DELLA DEFINIZIONE
-- ============================================================
-- Due tabelle con GLI STESSI DATI ma definizioni diverse.
-- Quante righe entrano in una pagina da 8 KB lo decide la definizione.


-- Sorgente di volume per le misure (copia: l'originale non viene toccato)
DROP TABLE IF EXISTS demo.Sorgente;

SELECT  TransactionID, ProductID, Quantity, ActualCost, TransactionDate
INTO    demo.Sorgente
FROM    Production.TransactionHistory;
GO

PRINT '--- SETUP: righe disponibili per le misure ---';
SELECT COUNT(*) AS RigheDisponibili FROM demo.Sorgente;
GO
-- Risultato atteso: circa 113.443 righe



DROP TABLE IF EXISTS demo.RigheStrette;
DROP TABLE IF EXISTS demo.RigheLarghe;
GO

CREATE TABLE demo.RigheStrette
(
    RigaID     INT          NOT NULL,
    ProdottoID SMALLINT     NOT NULL,
    Quantita   INT          NOT NULL,
    Importo    DECIMAL(9,2) NOT NULL,
    Codice     VARCHAR(15)  NOT NULL,
    DataMov    DATE         NOT NULL
);

CREATE TABLE demo.RigheLarghe
(
    RigaID     BIGINT        NOT NULL,
    ProdottoID BIGINT        NOT NULL,
    Quantita   BIGINT        NOT NULL,
    Importo    FLOAT         NOT NULL,
    Codice     NVARCHAR(400) NOT NULL,
    DataMov    DATETIME      NOT NULL
);
GO

INSERT INTO demo.RigheStrette
SELECT  TransactionID, ProductID, Quantity, ActualCost,
        CAST(TransactionID AS VARCHAR(15)), CAST(TransactionDate AS DATE)
FROM    demo.Sorgente;

INSERT INTO demo.RigheLarghe
SELECT  TransactionID, ProductID, Quantity, ActualCost,
        CAST(TransactionID AS NVARCHAR(400)), TransactionDate
FROM    demo.Sorgente;
GO

PRINT '--- 4. Stesso contenuto, occupazione diversa ---';
SELECT  OBJECT_NAME(object_id) AS Tabella,
        SUM(row_count)         AS Righe,
        SUM(used_page_count)   AS Pagine,
        CAST(SUM(used_page_count) * 8 / 1024.0 AS DECIMAL(9,2))                     AS MB,
        CAST(SUM(row_count) * 1.0 / NULLIF(SUM(used_page_count),0) AS DECIMAL(9,1)) AS RighePerPagina
FROM    sys.dm_db_partition_stats
WHERE   object_id IN (OBJECT_ID('demo.RigheStrette'), OBJECT_ID('demo.RigheLarghe'))
        AND index_id IN (0, 1)
GROUP BY object_id
ORDER BY MB;
GO

PRINT '--- 4. Meno pagine significa meno I/O: stessa query, costo diverso ---';
SET STATISTICS IO ON;

SELECT COUNT(*) FROM demo.RigheStrette;
SELECT COUNT(*) FROM demo.RigheLarghe;

SET STATISTICS IO OFF;
GO

-- 💡 Come leggere il messaggio di STATISTICS IO: il numero di "logical
--    reads" è il numero di pagine toccate. E' la misura che conta, perchè
--    è anche lo spazio che la tabella occuperà nel buffer pool.


-- ============================================================
-- 5. ALTER METADATA-ONLY: CAMBIA SOLO IL CATALOGO
-- ============================================================
-- Nessuna riga viene letta. L'operazione dura lo stesso su una tabella da
-- mille righe e su una da un miliardo. Si misura su demo.RigheLarghe, che
-- ha volume reale.

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- 1. Colonna nuova nullable: nessuna riga viene toccata
ALTER TABLE demo.RigheLarghe ADD Operatore VARCHAR(30) NULL;

-- 2. Colonna NOT NULL con DEFAULT costante di runtime: il valore vive
--    nei metadati (solo su versioni standard e enterprise)
ALTER TABLE demo.RigheLarghe ADD Canale VARCHAR(20) NOT NULL DEFAULT 'ERP';

-- 3. Allargare un tipo a lunghezza variabile: la lunghezza dichiarata è
--    un massimo, non spazio occupato, quindi non c'è nulla da riscrivere
ALTER TABLE demo.RigheLarghe ALTER COLUMN Codice NVARCHAR(600) NOT NULL;

-- 4. Eliminare una colonna: sparisce dal catalogo
ALTER TABLE demo.RigheLarghe DROP COLUMN Operatore;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- ── 5.1 Il DEFAULT non costante cade nella riscrittura ─────────
-- Sembra identico al caso 2, ma poiche' ogni riga deve ricevere un valore
-- diverso, ogni riga viene scritta.

SET STATISTICS IO ON;
SET STATISTICS TIME ON;

ALTER TABLE demo.RigheLarghe ADD Tracciatura UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID();

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO
-- Risultato atteso: letture logiche proporzionali alle pagine della tabella


-- ── 6.2 DROP COLUMN non restituisce spazio ─────────────────────
-- La colonna sparisce subito dalle query, ma i byte restano nelle pagine
-- finche' non si esegue un REBUILD.

PRINT '--- 6.2 Pagine prima del DROP ---';
SELECT  SUM(used_page_count) AS PaginePrima
FROM    sys.dm_db_partition_stats
WHERE   object_id = OBJECT_ID('demo.RigheLarghe') AND index_id IN (0,1);

ALTER TABLE demo.RigheLarghe DROP COLUMN Codice;

PRINT '--- 6.2 Pagine dopo il DROP: identiche ---';
SELECT  SUM(used_page_count) AS PagineDopoDrop
FROM    sys.dm_db_partition_stats
WHERE   object_id = OBJECT_ID('demo.RigheLarghe') AND index_id IN (0,1);
GO

ALTER TABLE demo.RigheLarghe REBUILD;

PRINT '--- 6.2 Pagine dopo il REBUILD: ora lo spazio e tornato ---';
SELECT  SUM(used_page_count) AS PagineDopoRebuild
FROM    sys.dm_db_partition_stats
WHERE   object_id = OBJECT_ID('demo.RigheLarghe') AND index_id IN (0,1);
GO


-- ============================================================
-- 7. ALTER CON RISCRITTURA: OGNI RIGA VIENE RISCRITTA
-- ============================================================
-- Il costo è proporzionale alle pagine della tabella, non alle righe che
-- si stanno effettivamente cambiando.


-- 1. Cambio di tipo: cambia la dimensione fisica di ogni riga
-- da  SMALLINT a INT
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

BEGIN TRAN;
    ALTER TABLE demo.RigheStrette ALTER COLUMN ProdottoID INT NOT NULL;
ROLLBACK;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- 2. Cambio di precisione o scala: sembra una semplificazione, riscrive tutto
-- da  DECIMAL(9,2) a DECIMAL(19,4)
SET STATISTICS IO ON;

BEGIN TRAN;
    ALTER TABLE demo.RigheStrette ALTER COLUMN Importo DECIMAL(19,4) NOT NULL;
ROLLBACK;

SET STATISTICS IO OFF;
GO



-- ── 7.2 Allargare e' gratis, passare a (MAX) no ────────────────
ALTER TABLE demo.RigheStrette ADD Note VARCHAR(50) NULL;

SET STATISTICS IO ON;

-- Gratis: resta una colonna a lunghezza variabile in riga
BEGIN TRAN;
    ALTER TABLE demo.RigheStrette ALTER COLUMN Note VARCHAR(200) NULL;
ROLLBACK;

-- Non gratis: cambia il modo in cui il valore e' memorizzato
BEGIN TRAN;
    ALTER TABLE demo.RigheStrette ALTER COLUMN Note VARCHAR(MAX) NULL;
ROLLBACK;

SET STATISTICS IO OFF;
GO



-- ============================================================
-- 9. PULIZIA
-- ============================================================
DROP TABLE IF EXISTS demo.ListinoFornitore;
DROP TABLE IF EXISTS demo.Giacenza;
DROP TABLE IF EXISTS demo.Movimento;
DROP TABLE IF EXISTS demo.StoricoPrezzoCarico;
DROP TABLE IF EXISTS demo.ListinoFornitore;
DROP TABLE IF EXISTS demo.Articolo;
DROP TABLE IF EXISTS demo.Magazzino;
DROP TABLE IF EXISTS demo.Localita;
DROP TABLE IF EXISTS demo.Provincia;

DROP TABLE IF EXISTS demo.ArticoloPiatto;
DROP TABLE IF EXISTS demo.GiacenzaPiatta;

DROP TABLE IF EXISTS demo.RigheStrette;
DROP TABLE IF EXISTS demo.RigheLarghe;
DROP TABLE IF EXISTS demo.Sorgente;
GO

IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'demo')
    DROP SCHEMA demo;
GO



-- ============================================================
-- FINE - Modulo 3 - Sezione 1 - CREATE, ALTER, DROP di tabelle
-- ============================================================
