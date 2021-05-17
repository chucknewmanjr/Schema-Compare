/*
	===== instructions =====
	This script is for comparing schemas.
	It can compare different databases or the same database to an earlier version.
	This is achived with schema snapshots.
	If this script returns one resultset when you run it, then that's a schema snapshot.
	You can copy those results into its own query window and save it for later.
	Or you can execute it to make a temp table that's ready for a comparison.
	If this script returns 2 resultsets then the first resultset is the results of a comparison.

	EXAMPLE
	1 - Run this script in QA. One resultset is returned. That's the schema snapshot.
	2 - Copy the results into a new query window in dev and run it. This creates a temp table.
	3 - Run this script in dev without closing the other query window. 
	    This time, 2 resultsets are returned. The first is the results of the comparison.
*/

if DB_NAME() = 'master' throw 50000, 'Dont run on master', 1;
go

declare @Schema_List table ([schema_id] int)

insert @Schema_List select [schema_id] from sys.schemas where [name] not in ('Tools', 'sys')

declare @Schema_Data table (
	Item nvarchar(200) not null, -- 200 -- Not including Parent. Typically has a prefix similar to Property_Type. Prefix depends on if parent is blank.
	Parent nvarchar(500) not null default '', -- Used to exclude results depending on parent results.
	Property_Type sysname not null, 
	Properties nvarchar(500) not null default ''
);

-- What are we comparing?
insert @Schema_Data values 
	('! Server', '', 'Snapshot', @@SERVERNAME), 
	('! Database', '', 'Snapshot', DB_NAME()), 
	('! Time', '', 'Snapshot', FORMAT(SYSDATETIMEOFFSET(), 'yyyy-M-d h-mm tt zzz'));

-- miscellaneous objects
insert @Schema_Data (Item, Property_Type)
select CONCAT(RTRIM([type] collate database_default), ' ', SCHEMA_NAME([schema_id]), '.', [name]), 'Object'
from sys.objects 
where is_ms_shipped = 0 
	and parent_object_id = 0 
	and [type_desc] not in ('SYNONYM', 'USER_TABLE')
	and [schema_id] in (select [schema_id] from @Schema_List)
	and ([name] not like '%diagram%' or [schema_id] <> SCHEMA_ID('dbo')); -- Exclude diagrams

insert @Schema_Data
select 
	' column ' + c.[name],
	CONCAT(RTRIM(o.[type]), ' ', SCHEMA_NAME(o.[schema_id]), '.', o.[name]),
	'Column',
	CONCAT('Data_Type=', TYPE_NAME(c.user_type_id), ', max_length=', c.max_length, ', is_nullable=', c.is_nullable, ', is_identity=', c.is_identity)
from sys.columns c
join sys.objects o on c.[object_id] = o.[object_id]
where OBJECT_SCHEMA_NAME(c.[object_id]) <> 'sys';

insert @Schema_Data
select 
	' column ' + c.[name],
	CONCAT(RTRIM(o.[type]), ' ', SCHEMA_NAME(o.[schema_id]), '.', o.[name]),
	'Default',
	IIF(d.is_system_named = 1, LEFT(d.[name], LEN(d.[name]) - 8) + '(is_system_named)', d.[name]) + '=' + d.[definition] as Default_Definition
from sys.columns c
join sys.objects o on c.[object_id] = o.[object_id]
join sys.default_constraints d on c.[object_id] = d.parent_object_id and c.column_id = d.parent_column_id
where OBJECT_SCHEMA_NAME(c.[object_id]) <> 'sys';

insert @Schema_Data
select 
	' foreign_key ' + t.[name],
	CONCAT(RTRIM(o.[type]), ' ', SCHEMA_NAME(o.[schema_id]), '.', o.[name]),
	'Foreign Key',
	OBJECT_SCHEMA_NAME(t.referenced_object_id) + '.' + OBJECT_NAME(t.referenced_object_id)
from sys.foreign_keys t
join sys.objects o on t.parent_object_id = o.[object_id];

insert @Schema_Data
select 
	'.' + COL_NAME(t.parent_object_id, t.parent_column_id),
	CONCAT(RTRIM(o.[type]), ' ', SCHEMA_NAME(o.[schema_id]), '.', o.[name], ' foreign_key ', OBJECT_NAME(t.constraint_object_id)),
	'Foreign Key Column',
	OBJECT_SCHEMA_NAME(t.referenced_object_id) + '.' + OBJECT_NAME(t.referenced_object_id) + '.' + COL_NAME(t.referenced_object_id, t.referenced_column_id)
from sys.foreign_key_columns t
join sys.objects o on t.parent_object_id = o.[object_id];

insert @Schema_Data
select 
	' index ' + t.[name],
	CONCAT(RTRIM(o.[type]), ' ', SCHEMA_NAME(o.[schema_id]), '.', o.[name]),
	'Index',
	CONCAT('type_desc=', t.[type_desc], ', is_unique=', t.is_unique)
from sys.indexes t
join sys.objects o on t.[object_id] = o.[object_id]
where OBJECT_SCHEMA_NAME(t.[object_id]) <> 'sys' and t.[name] is not null and t.is_primary_key = 0;

insert @Schema_Data
select 
	' PK ' + IIF(c.is_system_named = 1, LEFT(c.[name], len(c.[name]) - 16) + '(is_system_named)', c.[name]), 
	CONCAT(RTRIM(o.[type] collate database_default), ' ', OBJECT_SCHEMA_NAME(c.parent_object_id), '.', o.[name]), 
	'PK', 
	CONCAT('unique_index_id=', c.unique_index_id)
from sys.key_constraints c
join sys.objects o on c.parent_object_id = o.[object_id]
where c.[type] = 'PK' 
	and c.is_ms_shipped = 0

	and (o.[name] not like '%diagram%' or o.[schema_id] <> SCHEMA_ID('dbo')) -- Exclude diagrams
order by 1





insert @Schema_Data
select 
	'.' + COL_NAME(ic.[object_id], ic.column_id),
	CONCAT(RTRIM(o.[type]), ' ', SCHEMA_NAME(o.[schema_id]), '.', o.[name], ' index ', i.[name]),
	'Index Column',
	IIF(ic.is_included_column=0, '', 'is_included_column')
from sys.index_columns ic
join sys.indexes i on ic.[object_id] = i.[object_id] and ic.index_id = i.index_id
join sys.objects o on i.[object_id] = o.[object_id]
where OBJECT_SCHEMA_NAME(ic.[object_id]) <> 'sys';

insert @Schema_Data
select 
	' parameter ' + ISNULL(NULLIF(t.[name], ''), '(return value)'),
	CONCAT(RTRIM(o.[type]), ' ', SCHEMA_NAME(o.[schema_id]), '.', o.[name]),
	'Parameter',
	CONCAT('Data_Type=', TYPE_NAME(t.user_type_id), ', max_length=', t.max_length, ', is_output=', t.is_output, ', is_readonly=', t.is_readonly)
from sys.parameters t
join sys.objects o on t.[object_id] = o.[object_id];

-- schemas
insert @Schema_Data (Item, Property_Type, Properties)
select 'Schema ' + s.[name], 'Schema', p.[name]
from sys.schemas s
join sys.database_principals p on s.principal_id = p.principal_id
where p.is_fixed_role = 0 and s.[name] <> p.[name];

-- synonyms
insert @Schema_Data (Item, Property_Type, Properties)
select CONCAT(RTRIM([type]), ' ', SCHEMA_NAME([schema_id]), '.', [name]), 'Synonym', base_object_name
from sys.synonyms;

-- tables
insert @Schema_Data (Item, Property_Type, Properties)
select CONCAT(RTRIM([type]), ' ', SCHEMA_NAME([schema_id]), '.', [name]), 'Table', temporal_type_desc
from sys.tables
where [schema_id] in (select [schema_id] from @Schema_List)
	and ( -- Exclude diagrams
		[name] not like '%diagram%'
		or [schema_id] <> SCHEMA_ID('dbo')
	);

-- table types
insert @Schema_Data (Item, Property_Type)
select 'Table Type ' + SCHEMA_NAME([schema_id]) + '.' + [name], 'Table Type'
from sys.table_types;

-- dependencies
insert @Schema_Data (Item, Parent, Property_Type)
select
	ISNULL(' column ' + COL_NAME(d.referencing_id, d.referencing_minor_id), '') + ' depends on ' +
	ISNULL(RTRIM(red.[type] collate database_default) + ' ', '') + ISNULL(d.referenced_schema_name + '.', '') + d.referenced_entity_name + 
	ISNULL(' column ' + COL_NAME(d.referenced_id, d.referenced_minor_id), ''),
	CONCAT(RTRIM(ring.[type]), ' ', SCHEMA_NAME(ring.[schema_id]), '.', ring.[name]),
	'Dependency'
from sys.sql_expression_dependencies d
join sys.objects ring on d.referencing_id = ring.[object_id]
left join sys.objects red on d.referenced_id = red.[object_id]
where d.referenced_id is not null;

-- role memberships
insert @Schema_Data (Item, Parent, Property_Type)
select 
	' role ' + r.name, 
	CONCAT(m.[type_desc], ' ', m.[name]),
	'Membership'
from sys.database_role_members rm
join sys.database_principals m on rm.member_principal_id = m.principal_id
join sys.database_principals r on rm.role_principal_id = r.principal_id;

-- user defined table types
insert @Schema_Data
select 
	' column ' + c.[name],
	'Table Type ' + SCHEMA_NAME(tt.[schema_id]) + '.' + tt.[name],
	'Table Type Column',
	CONCAT('Data_Type=', TYPE_NAME(c.user_type_id), ', max_length=', c.max_length, ', is_nullable=', c.is_nullable)
from sys.columns c
join sys.table_types tt on c.[object_id] = tt.type_table_object_id;

-- partition schemes
insert @Schema_Data (Item, Property_Type)
select [name], 'Partition Scheme'
from sys.partition_schemes;

-- check constraints
insert @Schema_Data
select 
	' check ' + SCHEMA_NAME(schema_id) + '.' + [name],
	OBJECT_SCHEMA_NAME(parent_object_id) + '.' + OBJECT_NAME(parent_object_id) + '.' + COL_NAME(parent_object_id, parent_column_id),
	'Check Constraint',
	[definition]
from sys.check_constraints;

-- triggers
insert @Schema_Data
select 
	' trigger ' + [name],
	isnull(OBJECT_SCHEMA_NAME(parent_id) + '.' + OBJECT_NAME(parent_id), ''),
	'Trigger',
	CONCAT('parent_class_desc=', parent_class_desc, ', is_disabled=', is_disabled, ', is_instead_of_trigger=', is_instead_of_trigger)
from sys.triggers
where parent_class_desc in ('OBJECT_OR_COLUMN');

insert @Schema_Data
select 
	isnull('.' + cast(nullif(minor_id, 0) as varchar), '') + ' value ' + [name], 
	isnull(OBJECT_SCHEMA_NAME(major_id) + '.' + OBJECT_NAME(major_id), ''),
	'Extended Property',
	cast([value] as nvarchar(200)) -- was sql_variant
from sys.extended_properties
where name <> 'guid'
	and ( -- Exclude diagrams
		OBJECT_SCHEMA_NAME(major_id) <> 'dbo'
		or OBJECT_NAME(major_id) not like '%diagram%'
		or [value] <> 1
	);

insert @Schema_Data (Item, Property_Type, Properties)
select 'Filegroup ' + [name], 'Filegroup', [type_desc]
from sys.data_spaces

if OBJECT_ID('tempdb.dbo.##Schema_Snapshot') is not null begin
	declare @source table (Item nvarchar(500), Parent nvarchar(500), Property_Type sysname, Properties nvarchar(500));

	declare @target table (Item nvarchar(500), Parent nvarchar(500), Property_Type sysname, Properties nvarchar(500));

	insert @source select * from ##Schema_Snapshot; -- This data is from earlier or somewhere else.

	insert @target select * from @Schema_Data; -- This data is from here and now.

	-- The Item value is stored without the parent value. Now let's put it back in.
	update @source set Item = Parent + Item;

	update @target set Item = Parent + Item;

	-- Delete children if the parent doesn't exist in the other dataset.
	delete s
	from @source s
	left join @target t on s.Parent = t.Item and t.Item <> t.Parent
	where s.Parent > '' and t.Item is null;

	delete t
	from @target t 
	left join @source s on t.Parent = s.Item and s.Item <> s.Parent
	where t.Parent > '' and s.Item is null;

	select
		case
			when s.Item is null then 'only in target'
			when t.Item is null then 'only in source'
			when s.Properties <> t.Properties then 'different Properties'
			else 'match'
		end as Result,
		ISNULL(s.Item, t.Item) as Item,
		ISNULL(s.Property_Type, t.Property_Type) as Property_Type,
		ISNULL(s.Properties, '') as Source_Properties, 
		ISNULL(t.Properties, '') as Target_Properties
	from @source s
	full outer join @target t on s.Item = t.Item and s.Property_Type = t.Property_Type
	where ISNULL(s.Item, '') <> ISNULL(t.Item, '')
		or ISNULL(s.Property_Type, '') <> ISNULL(t.Property_Type, '')
		or ISNULL(s.Properties, '') <> ISNULL(t.Properties, '')
	order by 2, 3, 4, 1;
end

declare @Output_Work table (Row_Num int identity, Section int, Line nvarchar(2000));

insert @Output_Work
select 20, ',(''' + Item + ''', ''' + Parent + ''', ''' + Property_Type + ''', ''' + REPLACE(Properties, '''', '''''') + ''')'
from @Schema_Data
order by Item, Parent, Property_Type, Properties;

update @Output_Work 
set Line = '/*' + CAST(Row_Num / 1000 as varchar) + '*/ insert ##Schema_Snapshot values ' + STUFF(Line, 1, 1, '') 
where Row_Num % 1000 = 1;

insert @Output_Work
values
	(10, 'drop table if exists ##Schema_Snapshot;'), 
	(15, 'create table ##Schema_Snapshot (Item nvarchar(200), Parent nvarchar(500), Property_Type sysname, Properties nvarchar(500));'), 
	(30, 'print ''The ##Schema_Snapshot temp table is ready for a comparison. Once you close this script, the table will go away.'';')
;

with t as(select 0y,CAST(value as int)q,0r from STRING_SPLIT(REPLACE(REPLACE('45,90-2430,5103,405,783,2610,7377,22160,44560,13395,5193,270,567,3645\90-2475,5193-2430\63,405,810,2475,7377,22160,44560,13395,4950,1485,567,45,90-2430,5103','-',',270,810,2430\90,270,810,'),'\',',4860,1620,540,180,'),',')union all select y+1,q/3,q%3 from t where y<10)
insert @Output_Work
select 40,'--  '+REPLACE(REPLACE((select char(r+46)from t where y=u.y for xml path('')),'.',' '),'0','\')from t u group by y;

select Line as [--Schema_Snapshot] from @Output_Work order by Section, Row_Num;

--                    /\                                          /\                  
--                   /  \                                        /  \                 
--      /\      /\  / /\ \  /\      /\      /\  /\      /\      / /\ \      /\      /\
--     /  \    / / / / / /  \ \    /  \    / / /  \    /  \    / / /  \    /  \    / /
--    / /\ \  / / / / / / /\ \ \  / /\ \  / / / /\ \  / /\ \  / / / /\ \  / /\ \  / / 
--   / /  \ \/ /  \ \/ / / /  \ \/ /  \ \/ / / /  \ \/ /  \ \ \/ / / / / / /  \ \/ /  
--  / /    \  /    \  / / /    \  /    \  / / /    \  /    \ \  / / / / / /    \  /   
--  \/      \/      \ \/ /      \/      \/  \/      \/      \/  \ \/ /  \/      \/    
--                   \  /                                        \  /                 
--                    \/                                          \/                  
