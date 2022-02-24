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

# EXAMPLE - 

	--- EXAMPLE ---
	Compare dev to QA
	1 - Run this script in QA. One resultset is returned. That's the schema snapshot.
	2 - Copy the results into a new query window in dev and run it. This creates a temp table.
	3 - Run this script in dev without closing the other query window. 
	    This time, 2 resultsets are returned. The first is the results of the comparison.
      
      
# COMPARISON RESULTS COLUMNS
The results of the comparison contain 5 columns
1. Result - Which snapshot the item is in. The comparison results 
are from running this script in the target.
1. Item - The name of the object, column, index or someother thing. 
If the item is in another object, then that is included.
1. Property_Type - The type of item or a more specific detail.
1. Source_Properties - More details about the source item.
1. Target_Properties - More details about the target item.
