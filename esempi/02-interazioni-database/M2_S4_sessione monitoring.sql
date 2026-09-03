SELECT
    r.session_id,
    r.blocking_session_id,
    r.wait_type,
    r.wait_time,
    r.command,
    t.text AS query_bloccata
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.blocking_session_id <> 0;

SELECT
    tl.request_session_id                              AS session_id,
    DB_NAME(tl.resource_database_id)                   AS database_name,
    COALESCE(o_direct.name, o_via_hobt.name)            AS object_name,
    OBJECT_SCHEMA_NAME(
        COALESCE(o_direct.object_id, o_via_hobt.object_id),
        tl.resource_database_id
    )                                                    AS schema_name,
    tl.resource_type,
    tl.resource_subtype,
    tl.resource_description,
    tl.request_mode,
    tl.request_type,
    tl.request_status
FROM sys.dm_tran_locks AS tl
-- Path 1: OBJECT-level locks (resource_associated_entity_id = object_id)
LEFT JOIN sys.objects AS o_direct
    ON tl.resource_type = 'OBJECT'
    AND tl.resource_associated_entity_id = o_direct.object_id
-- Path 2: KEY/PAGE/RID locks (resource_associated_entity_id = hobt_id)
LEFT JOIN sys.partitions AS p
    ON tl.resource_type IN ('KEY', 'PAGE', 'RID')
    AND tl.resource_associated_entity_id = p.hobt_id
LEFT JOIN sys.objects AS o_via_hobt
    ON p.object_id = o_via_hobt.object_id
WHERE tl.resource_type IN ('OBJECT', 'KEY', 'PAGE', 'RID') 
ORDER BY tl.request_session_id, tl.resource_type