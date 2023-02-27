DROP TABLE lists, todos CASCADE;

CREATE TABLE lists (
    id serial PRIMARY KEY,
    name text NOT NULL UNIQUE
);

CREATE TABLE todos (
    id serial PRIMARY KEY,
    name text NOT NULL,
    completed boolean NOT NULL DEFAULT false,
    list_id int NOT NULL references lists (id) ON DELETE CASCADE
);