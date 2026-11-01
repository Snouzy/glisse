# Leçons

- **`self?.méthode() ?? valeur` aplatit l'optionnel.** Quand la méthode rend `nil` pour dire quelque chose
  (ici : « avale l'événement »), le chaînage optionnel confond ce nil avec « self absent » et le `??` rend la
  valeur par défaut. Écrire `guard let self else { return … }; return self.méthode()`. Ça a laissé passer
  clics et touches pendant toute la première soirée, masqué par trois correctifs à côté (bouclier,
  re-parquage, curseur caché).
- **Vérifier une rétention d'événements de l'extérieur, tout de suite.** Un tap en écoute seule en bout de
  chaîne (`cgAnnotatedSessionEventTap`, `tailAppendEventTap`) dit en une minute si les événements survivent.
  Le faire avant d'empiler des contournements.
- **Ne pas journaliser les touches.** Les traces de diagnostic du clavier s'enlèvent dès le bug trouvé.
