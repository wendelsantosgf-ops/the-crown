
-- THE CROWN
-- Etapa 1: Jogadores, observadores e carteiras

ALTER TABLE public.crown_profiles
ADD COLUMN IF NOT EXISTS account_type TEXT
NOT NULL DEFAULT 'player';

ALTER TABLE public.crown_profiles
ADD COLUMN IF NOT EXISTS coins BIGINT
NOT NULL DEFAULT 1000;

ALTER TABLE public.crown_profiles
ADD CONSTRAINT crown_account_type_check
CHECK (account_type IN ('player', 'observer'));

ALTER TABLE public.crown_profiles
ADD CONSTRAINT crown_coins_nonnegative
CHECK (coins >= 0);

-- Ranking exclusivo para jogadores
CREATE OR REPLACE VIEW public.crown_public_leaderboard
WITH (security_invoker = true) AS
SELECT id, nickname, points, created_at, avatar_path
FROM public.crown_profiles
WHERE account_type = 'player';



-- ETAPA 2: PARTICIPANTES DOS DESAFIOS

CREATE TABLE IF NOT EXISTS public.crown_challenge_contestants (
    challenge_id UUID NOT NULL
        REFERENCES public.crown_challenges(id)
        ON DELETE CASCADE,
    user_id UUID NOT NULL
        REFERENCES public.crown_profiles(id),
    slot SMALLINT NOT NULL
        CHECK (slot BETWEEN 1 AND 2),

    PRIMARY KEY (challenge_id, user_id),
    UNIQUE (challenge_id, slot)
);

-- ETAPA 3: APOSTAS COM COINS

CREATE TABLE IF NOT EXISTS public.crown_wagers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    challenge_id UUID NOT NULL,
    bettor_id UUID NOT NULL
        REFERENCES public.crown_profiles(id),
    contestant_id UUID NOT NULL,

    amount BIGINT NOT NULL
        CHECK (amount > 0),

    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN (
            'pending',
            'won',
            'lost',
            'refunded'
        )),

    payout BIGINT NOT NULL DEFAULT 0
        CHECK (payout >= 0),

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    FOREIGN KEY (challenge_id, contestant_id)
        REFERENCES public.crown_challenge_contestants(
            challenge_id, user_id
        ),

    UNIQUE (challenge_id, bettor_id, contestant_id)
);



-- ETAPA 4: HISTÓRICO DE COINS

CREATE TABLE IF NOT EXISTS public.crown_coin_ledger (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    user_id UUID NOT NULL
        REFERENCES public.crown_profiles(id),

    challenge_id UUID
        REFERENCES public.crown_challenges(id),

    wager_id UUID
        REFERENCES public.crown_wagers(id),

    delta BIGINT NOT NULL,
    reason TEXT NOT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (wager_id, reason)
);

-- ETAPA 5: RESULTADOS DOS DESAFIOS

CREATE TABLE IF NOT EXISTS public.crown_challenge_results (
    challenge_id UUID PRIMARY KEY
        REFERENCES public.crown_challenges(id),

    winner_id UUID,

    settled_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    settled_by UUID NOT NULL,

    FOREIGN KEY (challenge_id, winner_id)
        REFERENCES public.crown_challenge_contestants(
            challenge_id, user_id
        )
);

-- Migração em desenvolvimento: não executar até concluir a revisão de segurança.
