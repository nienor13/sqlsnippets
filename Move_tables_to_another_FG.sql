DECLARE @tbl sysname,
        @schema sysname,
        @index sysname,
        @object_id INT,
        @sql NVARCHAR(MAX);

DECLARE cur CURSOR FORWARD_ONLY FOR
SELECT o.object_id,
       o.[name],
       i.[name],
       s.name
FROM sys.indexes i
    INNER JOIN sys.filegroups f
        ON i.data_space_id = f.data_space_id
    INNER JOIN sys.all_objects o
        ON i.[object_id] = o.[object_id]
    INNER JOIN sys.schemas s
        ON o.schema_id = s.schema_id
WHERE i.data_space_id = f.data_space_id
      --AND i.type = 1
      AND o.type = 'U' -- User Created Tables
      AND i.name IS NOT NULL
      AND f.name = 'PRIMARY';
OPEN cur;
FETCH NEXT FROM cur
INTO @object_id,
     @tbl,
     @index,
     @schema;
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @sql = 'CREATE ' + CASE
                                  WHEN i.type = 1 THEN
                                      'CLUSTERED INDEX '
                                  ELSE
                                      'NONCLUSTERED INDEX '
                              END + '[' + @index + '] ON [' + @schema + '].[' + @tbl + '] ('
    FROM sys.indexes i
    WHERE i.name = @index
          AND i.object_id = @object_id;



    SELECT @sql
        = @sql + CAST(STRING_AGG('[' + c.name + ']', ',')WITHIN GROUP(ORDER BY ic.index_column_id) AS NVARCHAR(MAX))
    FROM sys.indexes i
        INNER JOIN sys.index_columns ic
            ON i.object_id = ic.object_id
               AND i.index_id = ic.index_id
        INNER JOIN sys.columns c
            ON i.object_id = c.object_id
               AND c.column_id = ic.column_id
    WHERE i.object_id = @object_id
          AND i.name = @index;

    SET @sql = @sql + N') WITH (DROP_EXISTING = ON, ONLINE = ON) ON [Data];';
    PRINT @sql;
    FETCH NEXT FROM cur
    INTO @object_id,
         @tbl,
         @index,
         @schema;
END;
CLOSE cur;
DEALLOCATE cur;
