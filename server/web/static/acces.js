// Écrans d'accès de l'Application web : bouton « œil » qui affiche ou
// masque le mot de passe (RG-PRM-05 : bouton nommé, état annoncé). Sans
// JavaScript, le bouton reste caché et le champ fonctionne.
document.querySelectorAll("button.oeil").forEach(function (b) {
  var champ = document.getElementById(b.dataset.cible);
  if (!champ) return;
  b.hidden = false;
  b.addEventListener("click", function () {
    var visible = champ.type === "password";
    champ.type = visible ? "text" : "password";
    b.setAttribute("aria-pressed", visible ? "true" : "false");
    b.setAttribute("aria-label", visible ? "Masquer le mot de passe" : "Afficher le mot de passe");
  });
});
