
-- THE CROWN
-- Etapa 1: Jogadores, observadores e carteiras

ALTER TABLE public.crown_profiles
ADD COLUMN IF NOT EXISTS account_type TEXT
NOT NULL DEFAULT 'player';

ALTER TABLE public.crown_profiles
ADD COLUMN IF NOT EXISTS coins BIGINT
NOT NULL DEFAULT 1000;

ALTER TABLE public.crown_profiles
DROP CONSTRAINT IF EXISTS crown_account_type_check;
ALTER TABLE public.crown_profiles ADD CONSTRAINT crown_account_type_check
CHECK (account_type IN ('player', 'observer'));

ALTER TABLE public.crown_profiles
DROP CONSTRAINT IF EXISTS crown_coins_nonnegative;
ALTER TABLE public.crown_profiles ADD CONSTRAINT crown_coins_nonnegative
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



-- ETAPA 6: SEGURANÇA DAS CARTEIRAS E ACESSO
CREATE OR REPLACE FUNCTION public.crown_guard_wallet()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
 IF current_setting('crown.wallet_operation', true) IS DISTINCT FROM 'allowed' THEN
  IF TG_OP = 'INSERT' THEN
   IF NEW.coins <> 1000 THEN RAISE EXCEPTION 'Saldo inicial inválido'; END IF;
  ELSIF NEW.coins IS DISTINCT FROM OLD.coins OR NEW.account_type IS DISTINCT FROM OLD.account_type THEN
   RAISE EXCEPTION 'Carteira e tipo de conta protegidos';
  END IF;
 END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS crown_guard_wallet_trigger ON public.crown_profiles;
CREATE TRIGGER crown_guard_wallet_trigger BEFORE INSERT OR UPDATE ON public.crown_profiles
FOR EACH ROW EXECUTE FUNCTION public.crown_guard_wallet();

CREATE TABLE IF NOT EXISTS public.crown_challenge_comments (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 challenge_id uuid NOT NULL REFERENCES public.crown_challenges(id) ON DELETE CASCADE,
 author_id uuid NOT NULL REFERENCES public.crown_profiles(id),
 parent_id uuid REFERENCES public.crown_challenge_comments(id),
 content text NOT NULL CHECK (char_length(btrim(content)) BETWEEN 1 AND 1000),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE OR REPLACE FUNCTION public.crown_check_comment_parent()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF NEW.parent_id IS NOT NULL AND NOT EXISTS (
  SELECT 1 FROM public.crown_challenge_comments
  WHERE id=NEW.parent_id AND challenge_id=NEW.challenge_id
 ) THEN RAISE EXCEPTION 'Resposta pertence a outro desafio'; END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS crown_check_comment_parent_trigger ON public.crown_challenge_comments;
CREATE TRIGGER crown_check_comment_parent_trigger BEFORE INSERT ON public.crown_challenge_comments
FOR EACH ROW EXECUTE FUNCTION public.crown_check_comment_parent();

ALTER TABLE public.crown_challenge_contestants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crown_wagers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crown_coin_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crown_challenge_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crown_challenge_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS crown_contestants_select ON public.crown_challenge_contestants;
CREATE POLICY crown_contestants_select ON public.crown_challenge_contestants FOR SELECT TO authenticated USING(true);
DROP POLICY IF EXISTS crown_wagers_select ON public.crown_wagers;
CREATE POLICY crown_wagers_select ON public.crown_wagers FOR SELECT TO authenticated USING(bettor_id=auth.uid() OR public.crown_is_admin());
DROP POLICY IF EXISTS crown_coin_ledger_select ON public.crown_coin_ledger;
CREATE POLICY crown_coin_ledger_select ON public.crown_coin_ledger FOR SELECT TO authenticated USING(user_id=auth.uid() OR public.crown_is_admin());
DROP POLICY IF EXISTS crown_results_select ON public.crown_challenge_results;
CREATE POLICY crown_results_select ON public.crown_challenge_results FOR SELECT TO authenticated USING(true);
DROP POLICY IF EXISTS crown_comments_select ON public.crown_challenge_comments;
CREATE POLICY crown_comments_select ON public.crown_challenge_comments FOR SELECT TO authenticated USING(true);
DROP POLICY IF EXISTS crown_comments_insert ON public.crown_challenge_comments;
CREATE POLICY crown_comments_insert ON public.crown_challenge_comments FOR INSERT TO authenticated WITH CHECK(author_id=auth.uid());
DROP POLICY IF EXISTS crown_comments_delete ON public.crown_challenge_comments;
CREATE POLICY crown_comments_delete ON public.crown_challenge_comments FOR DELETE TO authenticated USING(author_id=auth.uid() OR public.crown_is_admin());
GRANT SELECT ON public.crown_challenge_contestants,public.crown_wagers,public.crown_coin_ledger,public.crown_challenge_results,public.crown_challenge_comments TO authenticated;
GRANT INSERT,DELETE ON public.crown_challenge_comments TO authenticated;
REVOKE INSERT,UPDATE,DELETE ON public.crown_wagers,public.crown_coin_ledger,public.crown_challenge_results,public.crown_challenge_contestants FROM authenticated,anon;

-- ETAPA 7: PARTICIPAÇÃO, APOSTAS E LIQUIDAÇÃO ATÔMICA
CREATE OR REPLACE FUNCTION public.crown_join_challenge(p_challenge uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_slot smallint;
BEGIN
 IF auth.uid() IS NULL OR NOT EXISTS(SELECT 1 FROM public.crown_profiles WHERE id=auth.uid() AND account_type='player') THEN
  RAISE EXCEPTION 'Somente jogadores podem participar';
 END IF;
 PERFORM 1 FROM public.crown_challenges WHERE id=p_challenge AND status='published' AND (deadline IS NULL OR deadline>now()) FOR UPDATE;
 IF NOT FOUND OR EXISTS(SELECT 1 FROM public.crown_challenge_results WHERE challenge_id=p_challenge) THEN
  RAISE EXCEPTION 'Desafio encerrado';
 END IF;
 IF EXISTS(SELECT 1 FROM public.crown_challenge_contestants WHERE challenge_id=p_challenge AND user_id=auth.uid()) THEN RETURN; END IF;
 SELECT s::smallint INTO v_slot FROM generate_series(1,2) s
 WHERE NOT EXISTS(SELECT 1 FROM public.crown_challenge_contestants WHERE challenge_id=p_challenge AND slot=s)
 ORDER BY s LIMIT 1;
 IF v_slot IS NULL THEN RAISE EXCEPTION 'Limite de dois participantes'; END IF;
 INSERT INTO public.crown_challenge_contestants(challenge_id,user_id,slot) VALUES(p_challenge,auth.uid(),v_slot);
 INSERT INTO public.crown_entries(challenge_id,user_id) VALUES(p_challenge,auth.uid()) ON CONFLICT(challenge_id,user_id) DO NOTHING;
END; $$;

CREATE OR REPLACE FUNCTION public.crown_place_wager(p_challenge uuid,p_contestant uuid,p_amount bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_wager uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Autenticação necessária'; END IF;
 IF p_amount IS NULL OR p_amount<1 OR p_amount>1000000000 THEN RAISE EXCEPTION 'Valor inválido'; END IF;
 PERFORM 1 FROM public.crown_challenges WHERE id=p_challenge AND status='published' AND (deadline IS NULL OR deadline>now()) FOR UPDATE;
 IF NOT FOUND OR EXISTS(SELECT 1 FROM public.crown_challenge_results WHERE challenge_id=p_challenge) THEN RAISE EXCEPTION 'Apostas encerradas'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.crown_challenge_contestants WHERE challenge_id=p_challenge AND user_id=p_contestant) THEN RAISE EXCEPTION 'Participante inválido'; END IF;
 IF EXISTS(SELECT 1 FROM public.crown_wagers WHERE challenge_id=p_challenge AND bettor_id=auth.uid() AND contestant_id=p_contestant) THEN RAISE EXCEPTION 'Aposta já registrada neste participante'; END IF;
 PERFORM set_config('crown.wallet_operation','allowed',true);
 UPDATE public.crown_profiles SET coins=coins-p_amount WHERE id=auth.uid() AND coins>=p_amount;
 IF NOT FOUND THEN RAISE EXCEPTION 'Coins insuficientes'; END IF;
 INSERT INTO public.crown_wagers(challenge_id,bettor_id,contestant_id,amount)
 VALUES(p_challenge,auth.uid(),p_contestant,p_amount) RETURNING id INTO v_wager;
 INSERT INTO public.crown_coin_ledger(user_id,challenge_id,wager_id,delta,reason)
 VALUES(auth.uid(),p_challenge,v_wager,-p_amount,'stake');
 PERFORM set_config('crown.wallet_operation','',true);
END; $$;

CREATE OR REPLACE FUNCTION public.crown_settle_challenge(p_challenge uuid,p_winner uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE w record;
BEGIN
 IF NOT public.crown_is_admin() THEN RAISE EXCEPTION 'Somente administradores'; END IF;
 PERFORM 1 FROM public.crown_challenges WHERE id=p_challenge FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Desafio não encontrado'; END IF;
 IF EXISTS(SELECT 1 FROM public.crown_challenge_results WHERE challenge_id=p_challenge) THEN RAISE EXCEPTION 'Resultado já registrado'; END IF;
 IF p_winner IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.crown_challenge_contestants WHERE challenge_id=p_challenge AND user_id=p_winner) THEN
  RAISE EXCEPTION 'Vencedor não participa deste desafio';
 END IF;
 INSERT INTO public.crown_challenge_results(challenge_id,winner_id,settled_by) VALUES(p_challenge,p_winner,auth.uid());
 UPDATE public.crown_challenges SET status='closed' WHERE id=p_challenge;
 PERFORM set_config('crown.wallet_operation','allowed',true);
 FOR w IN SELECT * FROM public.crown_wagers WHERE challenge_id=p_challenge AND status='pending' FOR UPDATE LOOP
  IF w.contestant_id=p_winner THEN
   UPDATE public.crown_wagers SET status='won',payout=w.amount*2 WHERE id=w.id;
   UPDATE public.crown_profiles SET coins=coins+w.amount*2 WHERE id=w.bettor_id;
   INSERT INTO public.crown_coin_ledger(user_id,challenge_id,wager_id,delta,reason)
   VALUES(w.bettor_id,p_challenge,w.id,w.amount*2,'payout');
  ELSE
   UPDATE public.crown_wagers SET status='lost' WHERE id=w.id;
  END IF;
 END LOOP;
 PERFORM set_config('crown.wallet_operation','',true);
END; $$;
REVOKE ALL ON FUNCTION public.crown_join_challenge(uuid),public.crown_place_wager(uuid,uuid,bigint),public.crown_settle_challenge(uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.crown_join_challenge(uuid),public.crown_place_wager(uuid,uuid,bigint),public.crown_settle_challenge(uuid,uuid) TO authenticated;

-- IMPORTANT: Existing crown_entries insert policies must also exclude observers.
DROP POLICY IF EXISTS crown_entries_create ON public.crown_entries;
CREATE POLICY crown_entries_create ON public.crown_entries FOR INSERT TO authenticated
WITH CHECK(user_id=auth.uid() AND status='accepted' AND submission IS NULL
 AND EXISTS(SELECT 1 FROM public.crown_profiles WHERE id=auth.uid() AND account_type='player')
 AND EXISTS(SELECT 1 FROM public.crown_challenges WHERE id=challenge_id AND status='published' AND (deadline IS NULL OR deadline>now())));
