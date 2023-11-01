-- [1] DELETING ENTRIES WITH MISSING CRITICAL DATA
-- assuming we can't work with data that do not have price information, we delete respective rows from the table
delete from apartments_poland
where price is null 
or trim(price) = '';

-- [2] CORRECTING LOGICAL ERRORS
-- the 'year' column has the value '2071' which is obviously incorrect, since 2071 year has not come yet
-- assuming we do not have an opportunity to check the correct date, we replace it with null
update apartments_poland
set build_year = null
where build_year = 2071;

-- [3] REMOVING TEXT FROM THE 'PRICE' COLUMN
-- 'price' column should have numeric values only, so we have to remove all text data (PLN, zloty etc.) and convert it to numeric format
-- (regexp_replace function with the second argument ''[^0-9.]'' removes all non-numeric characters)
update apartments_poland
set price = regexp_replace(price, '[^0-9.]', '');

-- [4] CHANGING THE 'PRICE' COLUMN FORMAT FROM TEXT TO NUMERIC
-- previously, the 'price' column had both text and numeric values and its type is 'text', so we have to change it to numeric (double)
alter table apartments_poland
modify price double;

-- [5] REPLACING TEXT 'NULL' VALUES AND EMPTY VALUES TO MYSQL NULL
-- the 'building_material' column has text 'null' values and missing records
-- so we have to replace them with MySQL null to simplify further analysis of the data
update apartments_poland
set building_material = null
where building_material = 'null'
or building_material = '';

-- [6] REMOVING UNNECESSARY SPACES
-- the 'has_balcony' column has spaces before 'yes/no' values that should be removed
update apartments_poland
set has_balcony = trim(has_balcony);

-- [7] RENAMING THE COLUMN TO THE STANDARDIZED FORMAT
-- query below renames the column 'PARKING(Y_N)' to common format: lowercase, no brackets, logic as for other columns
alter table apartments_poland
change `PARKING(Y_N)` has_parking text;

-- [8] CHANGING CONTENT TO READABLE FORMAT
-- the column that contains information about parking spaces inlcudes 'Y/N' values - it is preferable to replace them with "yes/no" for readability
update apartments_poland
set has_parking = case when has_parking = 'Y' then 'yes'
					   when has_parking ='N' then 'no'
                       else null end;

-- [9] CAPITALIZING CITY NAMES
-- since MySQL does not have built-in function like 'capitalize', the approach below is applied
update apartments_poland
set city = concat(upper(left(city, 1)), lower(substring(city, 2)));

-- [10] REMOVING DUPLICATES
-- MySQL does not allow to use 'delete' operator with window functions
-- besides, there is no unique id for each row (in duplicate entries id is also duplicated)
-- therefore, removing duplicates involves several steps:
-- -- first, we create new column that has a unique identifier for each row 
alter table apartments_poland add column unique_row_num int auto_increment primary key;
-- -- then we actually delete duplicate entries using the newly created unique identifier and self-join 
-- -- (so that the original row remains in the table and only duplicates are deleted)
delete t1
from apartments_poland t1
join apartments_poland t2
    on t1.id = t2.id
    and t1.city = t2.city
    and t1.ownership = t2.ownership
    and t1.building_material = t2.building_material
    and t1.has_balcony = t2.has_balcony
    and t1.has_parking = t2.has_parking
    and t1.square_meters = t2.square_meters
    and t1.rooms = t2.rooms
    and t1.floor = t2.floor
    and t1.build_year = t2.build_year
    and t1.price = t2.price
    and t1.unique_row_num > t2.unique_row_num;
-- -- finally, we drop the 'unique_row_num' column, since it is no longer relevant    
alter table apartments_poland
drop column unique_row_num;
