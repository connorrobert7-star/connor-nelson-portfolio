-- 0013_restock_order_link.sql
-- Link restock rows to the cart they were added to.
--
-- Phase 3 marks pending restock rows as 'added_to_cart' when they are pulled
-- into an order. Phase 4 has to be able to put them back if that order is
-- abandoned -- "I don't want a dismissed cart to silently wipe my restock
-- list" -- and that needs to know WHICH rows went into WHICH cart. Without
-- this column, abandoning one order would resurrect restock rows belonging to
-- a different, still-open cart.

alter table restock_list
  add column order_id uuid references orders (id) on delete set null;

create index restock_order_id_idx on restock_list (order_id)
  where order_id is not null;
