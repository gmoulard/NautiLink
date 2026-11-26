// Conduite d'une navigation depuis l'Application web (RG-WEB-05 à RG-WEB-07,
// D-163) : avant l'envoi d'un formulaire « avec-position » (démarrage,
// « Envoyer position », note, fin, SOS), demande la position à la
// géolocalisation du navigateur Internet et joint le décalage horaire ;
// refusée ou indisponible, le formulaire part sans position. Sur la page
// d'une navigation en cours, envoie les positions automatiques à la
// fréquence de la navigation tant que la page reste ouverte.
(function () {
  "use strict";
  var geo = navigator.geolocation;

  function champ(form, nom) {
    return form.querySelector('input[name="' + nom + '"]');
  }

  function decalage() {
    return String(-new Date().getTimezoneOffset());
  }

  function heure() {
    var d = new Date();
    return ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2);
  }

  // localiser : fini(position) ou fini(null, "refusee" | "indisponible").
  function localiser(fini) {
    if (!geo) {
      fini(null, "indisponible");
      return;
    }
    geo.getCurrentPosition(function (p) { fini(p); }, function (e) {
      fini(null, e && e.code === 1 ? "refusee" : "indisponible");
    }, { enableHighAccuracy: true, timeout: 15000, maximumAge: 60000 });
  }

  function remplir(valeurs, p) {
    valeurs.decalage = decalage();
    if (p) {
      valeurs.latitude = String(p.coords.latitude);
      valeurs.longitude = String(p.coords.longitude);
      valeurs.precision = p.coords.accuracy ? String(Math.round(p.coords.accuracy)) : "";
    }
    return valeurs;
  }

  var formulaires = document.querySelectorAll("form.avec-position");
  Array.prototype.forEach.call(formulaires, function (form) {
    var d = champ(form, "decalage");
    if (d) { d.value = decalage(); }
    form.addEventListener("submit", function (ev) {
      if (form.getAttribute("data-pret") === "oui") {
        return;
      }
      ev.preventDefault();
      var etat = form.querySelector("[data-etat-position]");
      if (etat) { etat.textContent = "Recherche de votre position…"; }
      Array.prototype.forEach.call(form.querySelectorAll("button[type=submit]"), function (b) { b.disabled = true; });
      localiser(function (p, erreur) {
        var v = remplir({}, p);
        Object.keys(v).forEach(function (nom) {
          var c = champ(form, nom);
          if (c) { c.value = v[nom]; }
        });
        if (etat && erreur) {
          etat.textContent = erreur === "refusee" ? "Localisation refusée : envoi sans position." : "Position indisponible : envoi sans position.";
        }
        form.setAttribute("data-pret", "oui");
        form.submit();
      });
    });
  });

  // RG-SOS-14 : avertissement quand plus aucun contact SOS n'est coché.
  var sansSos = document.getElementById("sans-sos");
  var casesSos = document.querySelectorAll("input[data-sos]");
  Array.prototype.forEach.call(casesSos, function (c) {
    c.addEventListener("change", function () {
      sansSos.hidden = Array.prototype.some.call(casesSos, function (x) { return x.checked; });
    });
  });

  var auto = document.getElementById("positions-auto");
  var minutes = auto ? parseInt(auto.getAttribute("data-frequence"), 10) : 0;
  if (!auto || !window.fetch || !window.URLSearchParams || !(minutes > 0)) {
    return;
  }
  var texte = auto.textContent;
  var minuterie;

  function annoncer(s) {
    auto.textContent = texte + " " + s;
  }

  function envoyer() {
    localiser(function (p, erreur) {
      if (!p) {
        annoncer(erreur === "refusee" ? "Localisation refusée : aucune position automatique n'est envoyée." : "Position indisponible pour l'instant.");
        return;
      }
      var v = remplir({ type: "position_automatique" }, p);
      var corps = new URLSearchParams();
      Object.keys(v).forEach(function (nom) { corps.set(nom, v[nom]); });
      window.fetch(auto.getAttribute("data-adresse"), { method: "POST", credentials: "same-origin", body: corps }).then(function (r) {
        if (r.status === 204) {
          annoncer("Dernière position automatique envoyée à " + heure() + ".");
        } else if (r.status === 409 || r.status === 403 || r.status === 404) {
          window.clearInterval(minuterie);
          annoncer("Positions automatiques arrêtées.");
        } else {
          annoncer("Position non envoyée à " + heure() + " : nouvel essai au prochain envoi.");
        }
      }).catch(function () {
        annoncer("Position non envoyée à " + heure() + " (pas de connexion) : nouvel essai au prochain envoi.");
      });
    });
  }

  minuterie = window.setInterval(envoyer, minutes * 60000);
}());
