BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "ask_message" (
    "id" bigserial PRIMARY KEY,
    "sessionId" bigint NOT NULL,
    "seq" bigint NOT NULL,
    "question" text NOT NULL,
    "answer" text NOT NULL DEFAULT ''::text,
    "status" text NOT NULL,
    "errorCode" text,
    "citations" json,
    "modelId" text,
    "fallback" boolean NOT NULL DEFAULT false,
    "projectIds" json,
    "includePersonal" boolean NOT NULL DEFAULT true,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "ask_message_session_seq_idx" ON "ask_message" USING btree ("sessionId", "seq");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "ask_session" (
    "id" bigserial PRIMARY KEY,
    "ownerId" uuid NOT NULL,
    "visitorKeyHash" text,
    "isDemo" boolean NOT NULL DEFAULT false,
    "title" text NOT NULL,
    "locale" text,
    "questionCount" bigint NOT NULL DEFAULT 0,
    "createdAt" timestamp without time zone NOT NULL,
    "lastActiveAt" timestamp without time zone NOT NULL,
    "streamingSince" timestamp without time zone,
    "hiddenAt" timestamp without time zone
);

-- Indexes
CREATE INDEX "ask_session_owner_active_idx" ON "ask_session" USING btree ("ownerId", "visitorKeyHash", "lastActiveAt");
CREATE INDEX "ask_session_active_idx" ON "ask_session" USING btree ("lastActiveAt");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "ask_message"
    ADD CONSTRAINT "ask_message_fk_0"
    FOREIGN KEY("sessionId")
    REFERENCES "ask_session"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR pageblink
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('pageblink', '20261016042828611-ask-history', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261016042828611-ask-history', "timestamp" = now();

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
