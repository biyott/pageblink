BEGIN;

--
-- CREATE VECTOR EXTENSION IF AVAILABLE
--
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'vector') THEN
    EXECUTE 'CREATE EXTENSION IF NOT EXISTS vector';
  ELSE
    RAISE EXCEPTION 'Required extension "vector" is not available on this instance. Please install pgvector. For instructions, see https://docs.serverpod.dev/upgrading/upgrade-to-pgvector.';
  END IF;
END
$$;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "doc_chunk" (
    "id" bigserial PRIMARY KEY,
    "documentId" bigint NOT NULL,
    "projectId" bigint,
    "ownerId" uuid NOT NULL,
    "page" bigint NOT NULL,
    "ordinal" bigint NOT NULL,
    "text" text NOT NULL,
    "contentHash" text NOT NULL,
    "embedding" vector(768) NOT NULL
);

-- Indexes
CREATE INDEX "doc_chunk_embedding_idx" ON "doc_chunk" USING hnsw ("embedding" vector_cosine_ops);
CREATE INDEX "doc_chunk_document_idx" ON "doc_chunk" USING btree ("documentId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "document" (
    "id" bigserial PRIMARY KEY,
    "ownerId" uuid NOT NULL,
    "projectId" bigint,
    "title" text NOT NULL,
    "contentHash" text NOT NULL,
    "version" bigint NOT NULL,
    "pageCount" bigint NOT NULL,
    "storagePath" text,
    "status" text NOT NULL,
    "embeddingModel" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "document_owner_idx" ON "document" USING btree ("ownerId");
CREATE INDEX "document_project_idx" ON "document" USING btree ("projectId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "project" (
    "id" bigserial PRIMARY KEY,
    "name" text NOT NULL,
    "ownerId" uuid NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "project_member" (
    "id" bigserial PRIMARY KEY,
    "projectId" bigint NOT NULL,
    "userId" uuid NOT NULL,
    "role" text NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "project_member_unique_idx" ON "project_member" USING btree ("projectId", "userId");
CREATE INDEX "project_member_user_idx" ON "project_member" USING btree ("userId");


--
-- MIGRATION VERSION FOR pageblink
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('pageblink', '20261014144327746', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261014144327746', "timestamp" = now();

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
