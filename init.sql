CREATE TABLE memory (
	mo text NOT NULL UNIQUE,
	count integer NOT NULL
);

CREATE TABLE meta (
	mtime real NOT NULL,
	mtime_m real NOT NULL,
	forgotten integer NOT NULL DEFAULT 0
);

