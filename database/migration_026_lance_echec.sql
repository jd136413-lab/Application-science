-- Migration 026 (26/11/2026) : cartes « À venir » de lancements déjà partis.
-- Deux nouveaux statuts, donnés par le calendrier officiel des lancements (Launch Library) :
--   'lance' = lancement réussi (ou en vol) ; 'echec' = échec total ou partiel.
-- Sans risque : ne modifie aucune carte, élargit seulement la liste des valeurs permises.
alter table public.upcoming_events drop constraint if exists upcoming_events_statut_check;
alter table public.upcoming_events add constraint upcoming_events_statut_check
  check (statut in ('prevu', 'reporte', 'annule', 'lance', 'echec'));
