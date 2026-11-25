package main

import (
	"context"
	"net/http"

	"github.com/jackc/pgx/v5"
)

// Corbeille des navigations (TODO-4.8, RG-NAV-20, RG-NAV-21) : le navigateur
// met depuis le Web une navigation terminée dans la corbeille ; elle y reste
// restaurable 30 jours (dureeCorbeille), puis la tâche de fond la supprime
// définitivement. Pendant ce temps, ses suiveurs n'y ont plus accès
// (conditionSuiveur) et son temps reste décompté du quota (intervallesDe).
//
// Dans la corbeille, le navigateur voit encore la page de la navigation, mais
// ne la modifie plus avant de l'avoir restaurée ; les envois du téléphone
// (événements, fichiers, fin rejouée) restent acceptés (RG-NAV-30).

func errNavigationEnCours() error {
	return &erreurAPI{http.StatusConflict, "navigation_en_cours",
		"Une navigation en cours ne peut pas être supprimée : terminez-la d'abord.", 0}
}

func errDansLaCorbeille() error {
	return &erreurAPI{http.StatusConflict, "navigation_corbeille",
		"Cette navigation est dans la corbeille : restaurez-la pour la modifier.", 0}
}

// navigationModifiable : navigation du navigateur, hors corbeille (RG-NAV-30).
func (a *app) navigationModifiable(ctx context.Context, utilisateur, id string) (navLigne, error) {
	n, err := a.navigationDuNavigateur(ctx, utilisateur, id)
	if err == nil && n.supprimee != nil {
		err = errDansLaCorbeille()
	}
	return n, err
}

// mettreALaCorbeille : DELETE /v1/navigations/{id} et bouton « Supprimer »
// de la page de la navigation sur le Web. Rejouable : une navigation déjà
// dans la corbeille y reste, sans repousser sa suppression définitive.
func (a *app) mettreALaCorbeille(ctx context.Context, s *session, id string) error {
	if s.support != "web" {
		return errInterdit("web_seulement", "Une navigation se supprime depuis la plateforme Web.") // RG-NAV-20
	}
	n, err := a.navigationDuNavigateur(ctx, s.utilisateur, id)
	if err != nil {
		return err
	}
	if n.enCours() {
		return errNavigationEnCours()
	}
	_, err = a.b.pool.Exec(ctx, `UPDATE navigations SET supprimee_le = $2, version = version + 1, modifiee_le = now()
		WHERE id = $1 AND supprimee_le IS NULL`, id, a.maintenant())
	return err
}

// restaurer : POST /v1/navigations/{id}/restauration, dans les 30 jours ;
// introuvable hors de la corbeille ou passé ce délai.
func (a *app) restaurer(ctx context.Context, utilisateur, id string) (navigationJSON, error) {
	n, err := a.navigationDuNavigateur(ctx, utilisateur, id)
	if err != nil {
		return navigationJSON{}, err
	}
	if n.supprimee == nil || !a.maintenant().Before(n.supprimee.Add(dureeCorbeille)) {
		return navigationJSON{}, errIntrouvable()
	}
	if _, err := a.b.pool.Exec(ctx, `UPDATE navigations SET supprimee_le = NULL, version = version + 1, modifiee_le = now()
		WHERE id = $1`, id); err != nil {
		return navigationJSON{}, err
	}
	if n, err = a.navigation(ctx, a.b.pool, id); err != nil {
		return navigationJSON{}, err
	}
	return a.detailler(ctx, n, "navigateur")
}

// corbeille : GET /v1/corbeille : navigations du compte dans la corbeille,
// la plus récemment supprimée d'abord, avec leur date de suppression
// définitive (supprimeeDefinitivementLe).
func (a *app) corbeille(ctx context.Context, utilisateur string) ([]navigationJSON, error) {
	lignes, err := a.b.pool.Query(ctx, "SELECT "+colonnesNav+` FROM navigations
		WHERE navigateur_id = $1 AND supprimee_le IS NOT NULL AND supprimee_le > $2
		ORDER BY supprimee_le DESC, id`, utilisateur, a.maintenant().Add(-dureeCorbeille))
	if err != nil {
		return nil, err
	}
	navs, err := pgx.CollectRows(lignes, func(l pgx.CollectableRow) (navLigne, error) { return lireNav(l) })
	if err != nil {
		return nil, err
	}
	liste := []navigationJSON{}
	for _, n := range navs {
		r, err := a.resumer(ctx, n, "navigateur")
		if err != nil {
			return nil, err
		}
		liste = append(liste, r)
	}
	return liste, nil
}

// purgerLaCorbeille : tâche de chaque minute : suppression définitive des
// navigations entrées dans la corbeille depuis 30 jours (RG-NAV-20,
// RG-DON-01), avec leur journal de bord, leurs positions et leurs fichiers
// (suppression en cascade). Les alertes SOS restent dans l'historique du
// bateau (RG-SOS-12, RG-SOS-13), sans lien vers la navigation. Les accès de
// périmètre navigation sur elle sont retirés (RG-PAR-10).
// Le quota n'en est pas changé : ses minutes, consommées avant la mise à la
// corbeille, sont redevenues disponibles au bout de 7 jours (RG-ECO-02).
func (a *app) purgerLaCorbeille(ctx context.Context) error {
	_, err := a.b.pool.Exec(ctx, `WITH purgees AS (
			DELETE FROM navigations WHERE supprimee_le IS NOT NULL AND supprimee_le <= $1 RETURNING id
		)
		DELETE FROM acces WHERE perimetre = 'navigation' AND navigation_id IN (SELECT id FROM purgees)`,
		a.maintenant().Add(-dureeCorbeille))
	return err
}

func (a *app) routesCorbeille(mux *http.ServeMux, v string) {
	mux.HandleFunc("DELETE "+v+"/navigations/{navigationId}", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		if err := a.mettreALaCorbeille(r.Context(), s, r.PathValue("navigationId")); err != nil {
			return err
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))
	mux.HandleFunc("POST "+v+"/navigations/{navigationId}/restauration", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		n, err := a.restaurer(r.Context(), s.utilisateur, r.PathValue("navigationId"))
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, n)
		return nil
	}))
	mux.HandleFunc("GET "+v+"/corbeille", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		l, err := a.corbeille(r.Context(), s.utilisateur)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, l)
		return nil
	}))
}
