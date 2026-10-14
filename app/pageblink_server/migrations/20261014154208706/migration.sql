BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "doc_page" (
    "id" bigserial PRIMARY KEY,
    "documentId" bigint NOT NULL,
    "page" bigint NOT NULL,
    "text" text NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "doc_page_document_idx" ON "doc_page" USING btree ("documentId", "page");

--
-- ACTION ALTER TABLE
--
ALTER TABLE "document" ADD COLUMN "lastError" text;

--
-- MIGRATION VERSION FOR pageblink
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('pageblink', '20261014154208706', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261014154208706', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_idp
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20260924105404509', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260924105404509', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260924105232991', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260924105232991', "timestamp" = now();


COMMIT;
