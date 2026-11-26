// Menu replié sur l'écran d'un téléphone (RG-WEB-04) : le bouton « Menu »
// ouvre et ferme la liste ; sans JavaScript, le menu reste affiché en entier.
(function () {
  var b = document.querySelector("header .menu-bouton");
  var entete = b && b.closest("header");
  if (!entete) return;
  b.hidden = false;
  entete.classList.add("menu-js");
  b.addEventListener("click", function () {
    var ouvert = entete.classList.toggle("ouvert");
    b.setAttribute("aria-expanded", ouvert ? "true" : "false");
  });
})();
