// Mise à jour en direct de la page d'une navigation en cours (TODO-6.2,
// 08-architecture.md §4) : toutes les 30 secondes, relit la partie « en
// direct » avec le curseur du journal ; le serveur répond 204 si rien n'a
// changé. Arrêt à la fin de la navigation.
(function () {
  "use strict";
  var zone = document.getElementById("direct");
  var annonce = document.getElementById("maj");
  if (!zone || !window.fetch || zone.getAttribute("data-etat") !== "en_cours") {
    return;
  }
  var delai = 30000;

  function plusTard() {
    if (zone.getAttribute("data-etat") === "en_cours") {
      window.setTimeout(relire, delai);
    }
  }

  function noter(reponse) {
    var curseur = reponse.headers.get("X-Curseur");
    var version = reponse.headers.get("X-Version");
    var etat = reponse.headers.get("X-Etat");
    if (curseur) { zone.setAttribute("data-curseur", curseur); }
    if (version) { zone.setAttribute("data-version", version); }
    if (etat) { zone.setAttribute("data-etat", etat); }
  }

  function heure() {
    var d = new Date();
    return ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2);
  }

  function relire() {
    var actif = document.activeElement;
    if (actif && zone.contains(actif) && /^(INPUT|TEXTAREA|SELECT)$/.test(actif.tagName)) {
      plusTard();
      return;
    }
    var adresse = zone.getAttribute("data-adresse") + "?depuis=" + encodeURIComponent(zone.getAttribute("data-curseur")) +
      "&version=" + encodeURIComponent(zone.getAttribute("data-version"));
    window.fetch(adresse, { credentials: "same-origin", cache: "no-store" }).then(function (reponse) {
      if (reponse.status === 204) {
        noter(reponse);
        return null;
      }
      if (reponse.status !== 200) {
        return null;
      }
      return reponse.text().then(function (html) {
        zone.innerHTML = html;
        noter(reponse);
        if (annonce) {
          annonce.textContent = zone.getAttribute("data-etat") === "en_cours"
            ? "Page mise à jour à " + heure() + "."
            : "La navigation est terminée.";
        }
      });
    }).catch(function () { return null; }).then(plusTard);
  }

  plusTard();
}());
