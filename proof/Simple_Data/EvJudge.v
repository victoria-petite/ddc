
Require Export SubstExpExp.
Require Import Preservation.
Require Import TyJudge.
Require Export EsJudge.
Require Export Exp.
Require Import BaseList.


(* Big Step Evaluation **********************************************
   This is also called 'Natural Semantics'.
   It provides a relation between the expression to be reduced 
   and its final value. 
 *)
Inductive EVAL : exp -> exp -> Prop :=
 | EvDone
   :  forall v2
   ,  whnfX  v2
   -> EVAL   v2 v2

 | EvLamApp
   :  forall x1 t11 x12 x2 v2 v3
   ,  EVAL x1 (XLam t11 x12)
   -> EVAL x2 v2
   -> EVAL (substX 0 v2 x12) v3
   -> EVAL (XApp x1 x2)      v3

 | EvCon
   :  forall x v v3 dc Cs
   ,  EVAL x v -> whnfX v
   -> exps_ctx Cs
   -> EVAL (XCon dc (Cs v)) v3
   -> EVAL (XCon dc (Cs x)) v3

 | EvCase 
   :  forall x1 x2 v3 dc vs alts tsArgs
   ,  EVAL x1 (XCon dc vs)
   -> Forall whnfX vs
   -> getAlt dc alts = Some (AAlt dc tsArgs x2)
   -> EVAL (substXs 0 vs x2) v3
   -> EVAL (XCase x1 alts)   v3.

Hint Constructors EVAL.


(* A terminating big-step evaluation always produces a whnf.
   The fact that the evaluation terminated is implied by the fact
   that we have a finite proof of EVAL to pass to this lemma. *)
Lemma eval_produces_whnfX
 :  forall x1 v1
 ,  EVAL   x1 v1
 -> whnfX  v1.
Proof.
 intros. induction H; intros; eauto.
Qed.
Hint Resolve eval_produces_whnfX.


(* Big to Small steps ***********************************************
   Convert a big-step evaluation into a list of individual
   machine steps.
 *)


(* Reduce one of the arguments to a data constructor. 
   The definition of evaluation contexts enforces a left-to-right 
   order of evaluation, so all the arguments to the left of the one
   to be reduced already need to be values. *)
Lemma steps_context_XCon
 :  forall ix x v vs xs xs' dc
 ,  splitAt ix xs = (vs, x :: xs')
 -> Forall value vs
 -> STEPS  x v
 -> STEPS (XCon dc xs) (XCon dc (vs ++ (v :: xs'))).
Proof.
 intros.
 lets D: steps_context XcCon. eapply (XscIx ix). eauto. auto.
 lets D1: D H1. clear D.
  assert (xs = app vs (x :: xs')). eapply splitAt_app. eauto.
   rewrite H2.
 apply D1.
Qed.


Lemma steps_context_XCon_2 
 :   forall v x dc Cs
 ,   STEPS x v
 ->  exps_ctx Cs
 ->  STEPS (XCon dc (Cs x)) (XCon dc (Cs v)).
Proof.
 intros.
 lets D: steps_context XcCon. eauto.
 eauto.
Qed.


Lemma Forall2_exists_left_In
 : forall (A B: Type) (R: A -> B -> Prop) x xs ys
 ,             In x xs  -> Forall2 R xs ys 
 -> (exists y, In y ys  /\         R x  y).
Proof.
 intros.
 induction H0.
  false.
  simpl in H. destruct H.
   subst.
   exists y. split. simpl. auto. auto.
   lets D: IHForall2 H.
   destruct D.
   exists x1.
    inverts H2.
    split. simpl. auto. auto.
Qed.


Lemma exps_ctx_Forall2 
 :   forall {B: Type} (R: exp -> B -> Prop) 
            (x: exp)  Cs
            (y: B)    (ys: list B)
 ,   exps_ctx Cs
 ->  Forall2 R (Cs x) ys
 ->  (exists y, In y ys /\ R x y).
Proof.
 intros.
 inverts H.
 assert (In x (vs ++ x :: xs')).
  admit.
 lets D: Forall2_exists_left_In H H0.
 destruct D. 
 exists x1. eauto.
Qed.  


Lemma exps_ctx_Forall2_swap
 :   forall {B: Type} (R: exp -> B -> Prop)
            (x1 x2 : exp) Cs
            (y: B)        (ys: list B)
 ,   exps_ctx Cs
 ->  R x1 y
 ->  R x2 y
 ->  Forall2 R (Cs x1) ys
 ->  Forall2 R (Cs x2) ys.
Proof.
 admit.
Qed.


Lemma steps_of_eval
 :  forall ds x1 t1 x2
 ,  TYPE ds Empty x1 t1
 -> EVAL  x1 x2
 -> STEPS x1 x2.
Proof.
 intros ds x1 t1 v2 HT HE. gen t1.

 (* Induction over the form of (EVAL x1 x2) *)
 induction HE.
 Case "EvDone".
  intros. apply EsNone.

 Case "EvLamApp".
  intros. inverts HT.

  lets E1: IHHE1 H3. 
  lets E2: IHHE2 H5.

  lets T1: preservation_steps H3 E1. inverts keep T1.
  lets T2: preservation_steps H5 E2.
  lets T3: subst_value_value H2 T2.
  lets E3: IHHE3 T3.

  eapply EsAppend.
    lets D: steps_context XcApp1. eapply D. eauto. 
   eapply EsAppend.
    lets D: steps_context (XcApp2 (XLam t0 x12)). eauto.
    eapply D. eauto.
   eapply EsAppend.
    eapply EsStep.
     eapply EsLamApp. eauto. eauto.

 Case "EvCon".
  intros. inverts keep HT.

  lets HTx: (@exps_ctx_Forall2 ty) H0 H7. auto.
  destruct HTx as [t]. inverts H1.

  lets HSx: IHHE1 H3. clear IHHE1.
  lets HTv: preservation_steps H3 HSx.

  eapply EsAppend.
   lets D: steps_context XcCon. eauto.
    eapply D. eapply HSx.

   eapply IHHE2.
   eapply TYCon. eauto.
   eapply exps_ctx_Forall2_swap.
    eauto. eapply H3. eauto. eauto.
  
 Case "EvCase".
  intros. inverts keep HT.

  lets Ex1: IHHE1 H3. clear IHHE1.

  eapply EsAppend.
   (* evaluate the discriminant *)
   lets HSx1: steps_context XcCase. eapply HSx1.
    eapply Ex1.

  (* choose the alternative *)
  lets HTCon: preservation_steps H3 Ex1. clear Ex1.
  inverts HTCon.
  assert (tsArgs0 = tsArgs).
   eapply getAlt_matches_dataDef; eauto. subst.

  lets HA: getAltExp_hasAlt H0.
  rewrite Forall_forall in H4.
  apply H4 in HA. clear H4.
  inverts HA.

   (* substitute ctor values into alternative *)
  eapply EsAppend.
   eapply EsStep.
    eapply EsCaseAlt.
     assert (Forall closedX vs).
     admit.
     rewrite Forall_forall.
     intros.
     apply Value.
     rewrite Forall_forall in H. eauto.
     rewrite Forall_forall in H1. eauto.
     eauto.
     eapply IHHE2.
     eapply subst_value_value_list; eauto.
Qed.


(* Small to Big steps ***********************************************
   Convert a list of individual machine steps to a big-step
   evaluation. The main part of this is the expansion lemma, which 
   we use to build up the overall big-step evaluation one small-step
   at a time. The other lemmas are used to feed it small-steps.
 *)

(* Given an existing big-step evalution, we can produce a new one
   that does an extra step before returning the original value.
 *)
Lemma eval_expansion
 :  forall ds te x1 t1 x2 v3
 ,  TYPE ds te x1 t1
 -> STEP x1 x2 -> EVAL x2 v3 
 -> EVAL x1 v3.
Proof.
 intros ds te x1 t1 x2 v3 HT HS. gen ds te t1 v3.
 induction HS; intros; 
  try (solve [inverts H; eauto]);
  try eauto.

 Case "Context".
  destruct H.
   eauto.

   SCase "XcApp1".
    inverts HT. inverts H0. inverts H. eauto.

   SCase "XcApp2".
    inverts HT. inverts H0. inverts H1. eauto.

   SCase "XcCon".
    inverts HT. 
    admit. (********* TODO: need big step rule *)

   SCase "XcCase".
    inverts HT. inverts H0. inverts H. eauto.
    eapply EvCase with (dc := dc) (vs := vs).
     admit. (*** ok, vs are values. need big step rule for XCon *)
    rewrite Forall_forall. intros.
    rewrite Forall_forall in H.
    apply H in H2. inverts H2. eauto. eauto.
    auto.
Qed.


(* Convert a list of small steps to a big-step evaluation. *)
Lemma eval_of_stepsl
 :  forall ds x1 t1 v2
 ,  TYPE ds Empty x1 t1
 -> STEPSL x1 v2 -> value v2
 -> EVAL   x1 v2.
Proof.
 intros.
 induction H0.
 
 Case "EslNone".
   apply EvDone. inverts H1. auto.

 Case "EslCons".
  eapply eval_expansion. 
   eauto. eauto. 
   apply IHSTEPSL.
   eapply preservation. eauto. auto. auto.
Qed.


(* Convert a multi-step evaluation to a big-step evaluation.
   We use stepsl_of_steps to flatten out the append constructors
   in the multi-step evaluation, leaving a list of individual
   small-steps.
 *)
Lemma eval_of_steps
 :  forall ds x1 t1 v2
 ,  TYPE ds Empty x1 t1
 -> STEPS x1 v2 -> value v2
 -> EVAL  x1 v2.
Proof.
 intros.
 eapply eval_of_stepsl; eauto.
 apply  stepsl_of_steps; auto.
Qed.


