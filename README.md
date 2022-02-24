# Schema-Compare
SQL Server database DDL comparison without both connections at the same time. It's just a SQL script. Nothing gets created. 

# Overview
It's useful for:

1. Comparing 2 databases when you can't connect to both from SSMS. Typically, RDP is involved.
1. Seeing what changed in the past month, week and so forth.

It does this by generating a schema snapshot and then using that snapshot for the comparison.
A schema snapshot is a SQL script that generates a global temp table that's full of schema info that's like an inventory.
Note that if this script returns one resultset, then that's a schema snapshot.
You can copy those results into its own query window and save it for later.
Or you can execute it in another server to make a temp table that's ready for a comparison.
If this script returns 2 resultsets then:

1. The first resultset is the results of a comparison and 
1. The second resultset is the schema snapshot.

# INSTRUCTIONS - SEEING WHAT CHANGED
Let's say you want to see DDL changes are made in the development database after today.

1. Run the Schema-Compare.sql script on the development database. One resultset is returned. That's the schema snapshot.
1. Copy the results into a new query window. If you look carefully, you'll see a suggested file name.
1. Save the results for later. The file name extention should be "sql".
1. On some later date, run the schema snapshot script on the development database. This creates a global temp table. Don't close the window or the table will go away.
1. Run the Schema-Compare.sql script on the development database. The first resultset is the comparison results.

# INSTRUCTIONS - COMPARING DEV TO QA
Let's say QA is only available through RDP. In that case, you might have SSMS running locally for DEV and SSMS running in the remote desktop for QA.

1. Run the Schema-Compare.sql script on the development database. One resultset is returned. That's the schema snapshot.
1. Copy the results into a new query window in the remote desktop.
1. Run the schema snapshot script on the QA database. This creates a global temp table. Don't close the window or the table will go away.
1. Run the Schema-Compare.sql script on the QA database in the remote desktop. The first resultset is the comparison results.

# COMPARISON RESULTS COLUMNS
The results of the comparison contain 5 columns

1. Result - Which snapshot the item is in. The comparison results are from running this script in the target.
1. Item - The name of the object, column, index or someother thing. If the item is in another object, then that is included.
1. Property_Type - The type of item or a more specific detail.
1. Source_Properties - More details about the source item.
1. Target_Properties - More details about the target item.
