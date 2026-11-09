-- Not an enchant fix: rides along because patch night applies this folder to the world database at every start.
-- Manastorm caches no longer stack (10 Nov). A stack of caches is one item to the core: opening one and taking its
-- loot left the rest of the stack stuck behind the looted copy. One cache per bag slot opens normally, and the core
-- removes each cache once it is emptied. Manastorm's own delivery handles single caches (it uses an empty slot).
-- Caches already in a stack stay stacked; only new ones are delivered one per slot. Safe to run again.
UPDATE item_template SET stackable = 1
WHERE stackable <> 1 AND (entry BETWEEN 97877 AND 97884 OR entry BETWEEN 1278050 AND 1278084
    OR entry BETWEEN 1288050 AND 1288074 OR entry BETWEEN 1289056 AND 1289074 OR entry IN (1478051, 1478052));
