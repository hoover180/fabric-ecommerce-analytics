-- Gold._measures: single-row placeholder table, home for all DAX measures
-- in the semantic model. Exists purely so measures have a clean, dedicated
-- location in the field list rather than being scattered across dim/fact
-- tables. Direct Lake doesn't support calculated tables reliably, so this
-- has to be a real physical table backed by Delta storage, not a
-- DAX-defined one -- the dummy_column is never surfaced (hidden in the
-- model), it exists only so the table has something to physically store.

CREATE TABLE [Gold]._measures (
    dummy_column BIT NOT NULL
);

INSERT INTO [Gold]._measures (dummy_column) VALUES (0);
